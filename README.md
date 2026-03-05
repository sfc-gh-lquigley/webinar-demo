# observe-demo-app

A Node.js/Express demo app for EKS with AWS WAF, ALB Ingress, and structured JSON logging with UUID request IDs.

## Architecture

```
Internet → AWS WAF → ALB (via Ingress) → EKS Pods (Node.js/Express)
```

- **CloudFormation** provisions: VPC, EKS cluster, managed node group, ECR, WAF WebACL
- **deploy.sh** handles: OIDC provider, ALB Controller IAM + Helm install, Docker build/push, K8s deploy
- **WAF rules**: AWS Common Rule Set, Known Bad Inputs, IP rate limiting (2000 req/5min)

## Prerequisites

- AWS CLI v2 configured with credentials
- Docker
- kubectl
- Helm 3

## Quick Start

```bash
# Deploy everything (default region: us-west-2)
./deploy.sh

# Or specify stack/cluster names and region
AWS_REGION=us-east-1 ./deploy.sh my-stack my-cluster
```

## Endpoints

| Path | Method | Description |
|------|--------|-------------|
| `/` | GET | Service info |
| `/health` | GET | Health check |
| `/api/items` | GET | List items |
| `/api/items` | POST | Create item (body: `{"name": "..."}`) |
| `/api/slow?delay=2000` | GET | Simulate slow response |
| `/api/error?rate=50` | GET | Simulate errors at given rate % |

## Log Format

Every log line is JSON with a UUID `requestId`:

```json
{
  "timestamp": "2026-03-04T12:00:00.000Z",
  "level": "info",
  "message": "request completed",
  "requestId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "method": "GET",
  "path": "/api/items",
  "statusCode": 200,
  "durationMs": 12
}
```

## Cleanup

```bash
./teardown.sh
```
