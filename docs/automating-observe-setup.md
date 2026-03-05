# Automating Observe Setup with Terraform and CI/CD

This guide shows how to automate the deployment of Observe's observability components — the **Observe Agent** (Kubernetes-level telemetry) and the **Observe AWS Integration** (AWS-level telemetry) — using Terraform and CI/CD pipelines.

**Assumption:** Your application infrastructure (EKS cluster, VPC, WAF, etc.) is already deployed and running. This guide covers only the Observe layer on top of it.

---

## Table of Contents

1. [What Gets Deployed](#what-gets-deployed)
2. [Prerequisites](#prerequisites)
3. [Terraform Project Structure](#terraform-project-structure)
4. [Terraform Configuration](#terraform-configuration)
5. [CI/CD Pipelines](#cicd-pipelines)
6. [Secrets Management](#secrets-management)
7. [Multi-Environment Strategy](#multi-environment-strategy)
8. [Validation and Troubleshooting](#validation-and-troubleshooting)

---

## What Gets Deployed

```
Existing EKS Cluster
  │
  ├── Observe Agent (Helm)
  │     Collects logs, metrics, and traces from pods and nodes.
  │     Sends to: https://<CUSTOMER_ID>.collect.observeinc.com
  │
  └── Observe AWS Integration (CloudFormation via Terraform)
        Collects CloudWatch Logs, Metrics, AWS Config changes.
        Pipeline: CloudWatch → Firehose → S3 → Observe Filedrop

Optional add-on:
  └── WAF Log Forwarding
        Pipeline: WAF WebACL → CloudWatch Log Group → Firehose → S3 → Observe
```

---

## Prerequisites

| Requirement | Details |
|-------------|---------|
| Running EKS cluster | With kubeconfig access configured |
| AWS CLI v2 | Authenticated with permissions for IAM, CloudFormation, CloudWatch, Firehose, S3 |
| Terraform >= 1.5 | With AWS, Kubernetes, and Helm providers |
| Helm 3 | For the Observe Agent chart |
| Observe account | Collection endpoint URL and ingest token |
| Observe Filedrop URI | S3 destination URI for the AWS integration (from Observe UI) |

---

## Terraform Project Structure

```
observe-terraform/
├── versions.tf
├── variables.tf
├── data.tf            # look up existing EKS cluster
├── observe-agent.tf   # Helm release for the Observe Agent
├── aws-integration.tf # Observe AWS integration stack
├── waf-logging.tf     # WAF log forwarding (optional)
├── outputs.tf
└── environments/
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

---

## Terraform Configuration

### versions.tf

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "observe-setup/terraform.tfstate"
    region         = "us-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### variables.tf

```hcl
variable "region" {
  type    = string
  default = "us-west-2"
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "observe_collection_endpoint" {
  description = "Observe collection endpoint (e.g. https://CUSTOMER_ID.collect.observeinc.com)"
  type        = string
  sensitive   = true
}

variable "observe_token" {
  description = "Observe ingest token"
  type        = string
  sensitive   = true
}

variable "observe_filedrop_s3_uri" {
  description = "Observe Filedrop S3 destination URI for the AWS integration"
  type        = string
}

variable "observe_agent_chart_version" {
  description = "Observe Agent Helm chart version"
  type        = string
  default     = "0.3.0"
}

variable "observe_aws_integration_version" {
  description = "Observe AWS integration SAM template version"
  type        = string
  default     = "2.10.3"
}

variable "waf_acl_arn" {
  description = "ARN of the existing WAF WebACL (optional, for WAF log forwarding)"
  type        = string
  default     = ""
}
```

### data.tf — Connect to Existing Cluster

```hcl
provider "aws" {
  region = var.region
}

data "aws_eks_cluster" "existing" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "existing" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.existing.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.existing.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.existing.token
  }
}
```

### observe-agent.tf — Observe Agent via Helm

```hcl
resource "kubernetes_namespace" "observe" {
  metadata {
    name = "observe"
  }
}

resource "kubernetes_secret" "observe_credentials" {
  metadata {
    name      = "agent-credentials"
    namespace = kubernetes_namespace.observe.metadata[0].name
  }

  data = {
    OBSERVE_TOKEN = var.observe_token
  }
}

resource "helm_release" "observe_agent" {
  name       = "observe-agent"
  namespace  = kubernetes_namespace.observe.metadata[0].name
  repository = "https://observeinc.github.io/helm-charts"
  chart      = "agent"
  version    = var.observe_agent_chart_version

  set {
    name  = "observe.collectionEndpoint"
    value = var.observe_collection_endpoint
  }

  set {
    name  = "observe.token.secretName"
    value = kubernetes_secret.observe_credentials.metadata[0].name
  }

  set {
    name  = "observe.token.secretKey"
    value = "OBSERVE_TOKEN"
  }

  set {
    name  = "cluster.name"
    value = var.cluster_name
  }

  set {
    name  = "cluster.environment"
    value = var.environment
  }

  depends_on = [kubernetes_namespace.observe, kubernetes_secret.observe_credentials]
}
```

### aws-integration.tf — Observe AWS Integration

```hcl
resource "aws_cloudformation_stack" "observe_aws_integration" {
  name         = "observe-aws-integration-${var.environment}"
  template_url = "https://observeinc-${var.region}.s3.${var.region}.amazonaws.com/aws-sam-apps/${var.observe_aws_integration_version}/stack.yaml"

  capabilities = ["CAPABILITY_NAMED_IAM", "CAPABILITY_AUTO_EXPAND"]

  parameters = {
    DestinationUri = var.observe_filedrop_s3_uri
    NameOverride   = "observe-integration-${var.environment}"
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  lifecycle {
    ignore_changes = [template_url]
  }
}
```

### waf-logging.tf — WAF Log Forwarding (Optional)

```hcl
resource "aws_cloudwatch_log_group" "waf_logs" {
  count             = var.waf_acl_arn != "" ? 1 : 0
  name              = "aws-waf-logs-observe-${var.environment}"
  retention_in_days = 7

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "observe" {
  count                   = var.waf_acl_arn != "" ? 1 : 0
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs[0].arn]
  resource_arn            = var.waf_acl_arn
}
```

### outputs.tf

```hcl
output "observe_agent_namespace" {
  value = kubernetes_namespace.observe.metadata[0].name
}

output "observe_agent_release_name" {
  value = helm_release.observe_agent.name
}

output "observe_agent_chart_version" {
  value = helm_release.observe_agent.version
}

output "aws_integration_stack_name" {
  value = aws_cloudformation_stack.observe_aws_integration.name
}

output "aws_integration_stack_id" {
  value = aws_cloudformation_stack.observe_aws_integration.id
}
```

---

## CI/CD Pipelines

### GitHub Actions

```yaml
# .github/workflows/observe-setup.yml
name: Deploy Observe Observability

on:
  push:
    branches: [main]
    paths:
      - "observe-terraform/**"
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        default: "dev"
        type: choice
        options: [dev, staging, prod]

permissions:
  id-token: write
  contents: read

env:
  AWS_REGION: us-west-2
  TF_DIR: observe-terraform

jobs:
  plan:
    name: Terraform Plan
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7"

      - name: Terraform Init
        working-directory: ${{ env.TF_DIR }}
        run: terraform init

      - name: Terraform Plan
        working-directory: ${{ env.TF_DIR }}
        run: |
          terraform plan \
            -var-file="environments/${{ github.event.inputs.environment || 'dev' }}.tfvars" \
            -var="observe_collection_endpoint=${{ secrets.OBSERVE_COLLECTION_ENDPOINT }}" \
            -var="observe_token=${{ secrets.OBSERVE_TOKEN }}" \
            -out=tfplan

      - uses: actions/upload-artifact@v4
        with:
          name: tfplan
          path: ${{ env.TF_DIR }}/tfplan

  apply:
    name: Terraform Apply
    needs: plan
    runs-on: ubuntu-latest
    environment: ${{ github.event.inputs.environment || 'dev' }}
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.7"

      - uses: actions/download-artifact@v4
        with:
          name: tfplan
          path: ${{ env.TF_DIR }}

      - name: Terraform Init
        working-directory: ${{ env.TF_DIR }}
        run: terraform init

      - name: Terraform Apply
        working-directory: ${{ env.TF_DIR }}
        run: terraform apply -auto-approve tfplan

  verify:
    name: Verify Observe Agent
    needs: apply
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Configure kubectl
        run: aws eks update-kubeconfig --name observe-demo-cluster --region ${{ env.AWS_REGION }}

      - name: Check Agent pods
        run: |
          kubectl get pods -n observe -l app.kubernetes.io/name=agent
          kubectl wait --for=condition=ready pod -n observe -l app.kubernetes.io/name=agent --timeout=120s

      - name: Check Agent logs for errors
        run: |
          kubectl logs -n observe -l app.kubernetes.io/name=agent --tail=50 | grep -i error || echo "No errors found"
```

### GitLab CI/CD

```yaml
# .gitlab-ci.yml
stages:
  - plan
  - apply
  - verify

variables:
  AWS_REGION: us-west-2
  TF_DIR: observe-terraform

plan:
  stage: plan
  image: hashicorp/terraform:1.7
  before_script:
    - apk add --no-cache aws-cli
  script:
    - cd $TF_DIR
    - terraform init
    - terraform plan
        -var-file="environments/${CI_ENVIRONMENT_NAME:-dev}.tfvars"
        -var="observe_collection_endpoint=${OBSERVE_COLLECTION_ENDPOINT}"
        -var="observe_token=${OBSERVE_TOKEN}"
        -out=tfplan
  artifacts:
    paths: [$TF_DIR/tfplan]

apply:
  stage: apply
  image: hashicorp/terraform:1.7
  before_script:
    - apk add --no-cache aws-cli
  script:
    - cd $TF_DIR
    - terraform init
    - terraform apply -auto-approve tfplan
  when: manual

verify:
  stage: verify
  image: bitnami/kubectl:1.29
  before_script:
    - aws eks update-kubeconfig --name observe-demo-cluster --region $AWS_REGION
  script:
    - kubectl get pods -n observe -l app.kubernetes.io/name=agent
    - kubectl wait --for=condition=ready pod -n observe -l app.kubernetes.io/name=agent --timeout=120s
```

---

## Secrets Management

### Required Secrets

| Secret | Description | Example |
|--------|-------------|---------|
| `OBSERVE_COLLECTION_ENDPOINT` | Observe tenant collection URL | `https://123456789012.collect.observeinc.com` |
| `OBSERVE_TOKEN` | Observe ingest/data stream token | `ds1AbCdEf:some-token-value` |
| `OBSERVE_FILEDROP_S3_URI` | S3 destination for the AWS integration | `s3://123456789012-xxxxx/ds1AbCdEf/` |
| `AWS_DEPLOY_ROLE_ARN` | IAM role for CI/CD OIDC auth | `arn:aws:iam::123456789012:role/deploy-role` |

### Option A: CI/CD Platform Secrets (Simplest)

Store secrets directly in GitHub Actions (Settings > Secrets) or GitLab CI/CD (Settings > CI/CD > Variables). Use environment-scoped secrets for different values per environment.

### Option B: AWS Secrets Manager

```hcl
data "aws_secretsmanager_secret_version" "observe_token" {
  secret_id = "observe/${var.environment}/ingest-token"
}

data "aws_secretsmanager_secret_version" "observe_endpoint" {
  secret_id = "observe/${var.environment}/collection-endpoint"
}

locals {
  observe_token               = data.aws_secretsmanager_secret_version.observe_token.secret_string
  observe_collection_endpoint = data.aws_secretsmanager_secret_version.observe_endpoint.secret_string
}
```

Then reference `local.observe_token` instead of `var.observe_token` in your resources.

### Option C: HashiCorp Vault

```hcl
data "vault_generic_secret" "observe" {
  path = "secret/observe/${var.environment}"
}

locals {
  observe_token               = data.vault_generic_secret.observe.data["token"]
  observe_collection_endpoint = data.vault_generic_secret.observe.data["endpoint"]
}
```

---

## Multi-Environment Strategy

### Environment Variable Files

```hcl
# environments/dev.tfvars
cluster_name            = "my-dev-cluster"
environment             = "dev"
observe_filedrop_s3_uri = "s3://DEV_FILEDROP_BUCKET/DEV_DATASTREAM/"
waf_acl_arn             = ""

# environments/staging.tfvars
cluster_name            = "my-staging-cluster"
environment             = "staging"
observe_filedrop_s3_uri = "s3://STAGING_FILEDROP_BUCKET/STAGING_DATASTREAM/"
waf_acl_arn             = "arn:aws:wafv2:us-west-2:123456789012:regional/webacl/staging-waf/abc123"

# environments/prod.tfvars
cluster_name            = "my-prod-cluster"
environment             = "prod"
observe_filedrop_s3_uri = "s3://PROD_FILEDROP_BUCKET/PROD_DATASTREAM/"
waf_acl_arn             = "arn:aws:wafv2:us-west-2:123456789012:regional/webacl/prod-waf/def456"
```

### Isolated State Per Environment

```hcl
backend "s3" {
  bucket         = "my-terraform-state"
  key            = "observe-setup/${terraform.workspace}/terraform.tfstate"
  region         = "us-west-2"
  dynamodb_table = "terraform-locks"
  encrypt        = true
}
```

Or use separate `-backend-config` in CI/CD:

```bash
terraform init -backend-config="key=observe-setup/${ENVIRONMENT}/terraform.tfstate"
```

---

## Validation and Troubleshooting

### Post-Deploy Checks

```bash
# 1. Verify Observe Agent pods are running
kubectl get pods -n observe

# 2. Check agent logs for successful connection
kubectl logs -n observe -l app.kubernetes.io/name=agent --tail=20

# 3. Verify the Helm release
helm list -n observe

# 4. Check the AWS integration CloudFormation stack status
aws cloudformation describe-stacks \
  --stack-name observe-aws-integration-dev \
  --query "Stacks[0].StackStatus"

# 5. Verify WAF logging is active (if configured)
aws wafv2 get-logging-configuration --resource-arn <WAF_ACL_ARN>
```

### Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Agent pods in `CrashLoopBackOff` | Bad token or unreachable endpoint | Verify `OBSERVE_TOKEN` secret and `collectionEndpoint` value |
| CloudFormation stack `ROLLBACK_COMPLETE` | AWS Config already enabled in account | Set `ConfigDeliveryBucketName` to the existing bucket, clear `IncludeResourceTypes` |
| WAF logs not appearing in Observe | Missing Firehose subscription | Ensure the AWS integration stack's LogWriter Firehose is subscribed to the WAF log group |
| `terraform plan` shows unexpected diffs | Chart version drift | Pin `observe_agent_chart_version` and `observe_aws_integration_version` |
