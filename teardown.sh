#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="${1:-observe-demo-stack}"
CLUSTER_NAME="${2:-observe-demo-cluster}"
REGION="${AWS_REGION:-us-west-2}"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "=== Tearing down observe-demo-app ==="

echo "--- Deleting Kubernetes resources ---"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}" 2>/dev/null || true
kubectl delete -f k8s/app.yaml 2>/dev/null || true

echo "--- Removing ALB controller ---"
helm uninstall aws-load-balancer-controller -n kube-system 2>/dev/null || true

echo "--- Removing ALB IAM role and policy ---"
ALB_ROLE_NAME="${CLUSTER_NAME}-alb-controller-role"
ALB_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${CLUSTER_NAME}-alb-controller-policy"
aws iam detach-role-policy --role-name "${ALB_ROLE_NAME}" --policy-arn "${ALB_POLICY_ARN}" 2>/dev/null || true
aws iam delete-role --role-name "${ALB_ROLE_NAME}" 2>/dev/null || true
aws iam delete-policy --policy-arn "${ALB_POLICY_ARN}" 2>/dev/null || true

echo "--- Removing OIDC provider ---"
OIDC_URL=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
  --query "cluster.identity.oidc.issuer" --output text 2>/dev/null || echo "")
if [ -n "${OIDC_URL}" ]; then
  OIDC_HOST=$(echo "${OIDC_URL}" | sed 's|https://||')
  OIDC_ARN=$(aws iam list-open-id-connect-providers --query \
    "OpenIDConnectProviderList[?ends_with(Arn, '${OIDC_HOST}')].Arn" --output text 2>/dev/null || echo "")
  if [ -n "${OIDC_ARN}" ]; then
    aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}"
  fi
fi

echo "--- Cleaning ECR images ---"
aws ecr batch-delete-image --repository-name observe-demo-app \
  --image-ids "$(aws ecr list-images --repository-name observe-demo-app --query 'imageIds' --output json 2>/dev/null)" \
  --region "${REGION}" 2>/dev/null || true

echo "--- Deleting CloudFormation stack ---"
aws cloudformation delete-stack --stack-name "${STACK_NAME}" --region "${REGION}"
aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}" --region "${REGION}"

echo "=== Teardown complete ==="
