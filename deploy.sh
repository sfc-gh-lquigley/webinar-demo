#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="${1:-observe-demo-stack}"
CLUSTER_NAME="${2:-observe-demo-cluster}"
REGION="${AWS_REGION:-us-west-2}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Step 1/6: Deploy CloudFormation stack ==="
aws cloudformation deploy \
  --template-file "${SCRIPT_DIR}/cloudformation.yaml" \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides ClusterName="${CLUSTER_NAME}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --region "${REGION}"

echo "=== Step 2/6: Retrieve stack outputs ==="
get_output() {
  aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --region "${REGION}" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" \
    --output text
}

ECR_URI=$(get_output ECRRepositoryUri)
WAF_ARN=$(get_output WAFWebACLArn)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "  ECR:  ${ECR_URI}"
echo "  WAF:  ${WAF_ARN}"

echo "=== Step 3/6: Build and push Docker image ==="
aws ecr get-login-password --region "${REGION}" \
  | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

docker build -t observe-demo-app "${SCRIPT_DIR}/app"
docker tag observe-demo-app:latest "${ECR_URI}:latest"
docker push "${ECR_URI}:latest"

echo "=== Step 4/6: Configure kubectl ==="
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --region "${REGION}"

echo "=== Step 5/6: Install AWS Load Balancer Controller ==="
OIDC_URL=$(aws eks describe-cluster --name "${CLUSTER_NAME}" --region "${REGION}" \
  --query "cluster.identity.oidc.issuer" --output text)
OIDC_HOST=$(echo "${OIDC_URL}" | sed 's|https://||')

PROVIDER_EXISTS=$(aws iam list-open-id-connect-providers --query \
  "OpenIDConnectProviderList[?ends_with(Arn, '${OIDC_HOST}')].Arn" --output text)

if [ -z "${PROVIDER_EXISTS}" ]; then
  THUMBPRINT=$(echo | openssl s_client -servername "${OIDC_HOST}" -connect "${OIDC_HOST}:443" 2>/dev/null \
    | openssl x509 -fingerprint -noout 2>/dev/null | sed 's/://g' | cut -d= -f2 | tr '[:upper:]' '[:lower:]')

  aws iam create-open-id-connect-provider \
    --url "${OIDC_URL}" \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list "${THUMBPRINT}"
  echo "  OIDC provider created"
else
  echo "  OIDC provider already exists"
fi

OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_HOST}"

ALB_ROLE_NAME="${CLUSTER_NAME}-alb-controller-role"
cat > /tmp/alb-trust-policy.json <<TRUSTEOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "${OIDC_HOST}:aud": "sts.amazonaws.com",
        "${OIDC_HOST}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
      }
    }
  }]
}
TRUSTEOF

if aws iam get-role --role-name "${ALB_ROLE_NAME}" >/dev/null 2>&1; then
  aws iam update-assume-role-policy --role-name "${ALB_ROLE_NAME}" \
    --policy-document file:///tmp/alb-trust-policy.json
  echo "  ALB controller role updated"
else
  aws iam create-role --role-name "${ALB_ROLE_NAME}" \
    --assume-role-policy-document file:///tmp/alb-trust-policy.json
  echo "  ALB controller role created"
fi

ALB_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${CLUSTER_NAME}-alb-controller-policy"
if ! aws iam get-policy --policy-arn "${ALB_POLICY_ARN}" >/dev/null 2>&1; then
  curl -sL https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json \
    -o /tmp/alb-iam-policy.json
  aws iam create-policy --policy-name "${CLUSTER_NAME}-alb-controller-policy" \
    --policy-document file:///tmp/alb-iam-policy.json
fi
aws iam attach-role-policy --role-name "${ALB_ROLE_NAME}" --policy-arn "${ALB_POLICY_ARN}" 2>/dev/null || true

ALB_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ALB_ROLE_NAME}"

kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master" 2>/dev/null || true

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="${CLUSTER_NAME}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${ALB_ROLE_ARN}" \
  --set region="${REGION}" \
  --set vpcId="$(get_output VPCId)"

echo "=== Step 6/6: Deploy application ==="
sed -e "s|\${AWS_ACCOUNT_ID}|${ACCOUNT_ID}|g" \
    -e "s|\${AWS_REGION}|${REGION}|g" \
    -e "s|\${WAF_WEB_ACL_ARN}|${WAF_ARN}|g" \
    "${SCRIPT_DIR}/k8s/app.yaml" | kubectl apply -f -

echo ""
echo "=== Deployment complete ==="
echo "Waiting for ALB to provision (this may take 2-3 minutes)..."
sleep 10
ALB_HOST=$(kubectl get ingress -n observe-demo observe-demo-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "pending")
echo "ALB endpoint: http://${ALB_HOST}"
echo ""
echo "Useful commands:"
echo "  kubectl logs -n observe-demo -l app=observe-demo-app -f"
echo "  kubectl get ingress -n observe-demo"
echo "  curl http://${ALB_HOST}/health"
