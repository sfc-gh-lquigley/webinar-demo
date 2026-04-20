# webinar-demo

Observe demo environment for the `146268791759` sandbox tenant. Simulates realistic workloads across multiple AWS services to demonstrate Observe's observability capabilities.

## Repository Structure

```
├── app/                    # Node.js/Express demo app (EKS + WAF)
├── k8s/                    # Kubernetes manifests
├── cloudformation.yaml     # VPC, EKS cluster, ECR, WAF WebACL
├── deploy.sh               # Full EKS deployment script
├── teardown.sh             # Full teardown script
│
├── terraform/              # Observe dashboards (AWS + RabbitMQ)
├── terraform-rabbitmq/     # RabbitMQ EC2 instance + OTEL Collector + load generator
└── terraform-batch/        # AWS Batch ETL simulation (Fargate + Step Functions)
```

---

## Modules

### `app/` — EKS Web App

Node.js/Express app running on EKS behind AWS WAF. Emits structured JSON logs with UUID request IDs.

**Architecture**: Internet → AWS WAF → ALB → EKS Pods (Node.js/Express)

```bash
./deploy.sh             # Deploy everything (default: us-west-2)
./teardown.sh           # Tear down everything
```

**Endpoints**: `/`, `/health`, `/api/items`, `/api/slow`, `/api/error`

---

### `terraform/` — Observe Dashboards

Terraform-managed Observe dashboards using the `observeinc/observe` provider.

- AWS integration dashboard
- RabbitMQ metrics dashboard

```bash
cd terraform/
terraform init
terraform apply -var="observe_api_token=<token>"
```

---

### `terraform-rabbitmq/` — RabbitMQ + OTEL

EC2 instance running RabbitMQ (Docker) with an OpenTelemetry Collector scraping RabbitMQ metrics and forwarding to Observe.

**Components**:
- RabbitMQ 3.13 (Docker, bind-mounted `rabbitmq.conf` for memory watermark)
- OTEL Collector with `rabbitmq` receiver → Observe OTLP endpoint
- Load generator simulating queue producers/consumers
- 20GB EBS + 4GB swap (prevents OOM kills)

```bash
cd terraform-rabbitmq/
terraform init
terraform apply
```

---

### `terraform-batch/` — AWS Batch ETL Simulation

Simulates a production ETL pipeline using AWS Batch on Fargate, orchestrated by Step Functions and triggered every 3 minutes via EventBridge Scheduler. Logs stream to CloudWatch (`/aws/batch/job`) and are forwarded to Observe via Firehose.

**Architecture**:
```
EventBridge Scheduler (every 3 min)
  → Step Functions Standard Workflow
    → AWS Batch (Fargate SPOT + ON_DEMAND fallback)
      → 3 parallel ETL jobs: customers / orders / inventory
        → CloudWatch Logs (/aws/batch/job)
          → Kinesis Firehose → Observe
```

**ETL job behavior** (`scripts/etl_job.py`):
- Stages: `init → extract → transform → load → complete`
- Realistic record counts (5K–100K), ~15% failure rate
- Failure types: `source_connection_timeout`, `schema_validation_failure`, `destination_unavailable`, `quota_exceeded`
- Structured JSON logs with `job_id`, `pipeline`, `dataset`, `stage`, `throughput_rps`

**Log format**:
```json
{
  "timestamp": "2026-04-20T18:23:31Z",
  "level": "INFO",
  "job_id": "b91b52d2-...",
  "pipeline": "batch-etl-pipeline",
  "dataset": "orders",
  "stage": "complete",
  "total_records_in": 73533,
  "total_records_out": 72746,
  "records_rejected": 787,
  "throughput_rps": 1984.5
}
```

```bash
cd terraform-batch/
terraform init
terraform apply
```

---

## Observe Integration

All modules forward telemetry to Observe tenant `146268791759` via the `aws-integration-n89zfn1a` stack:

| Source | Type | Observe Dataset |
|--------|------|-----------------|
| EKS pods | CloudWatch Logs | AWS Logs |
| RabbitMQ | OTLP metrics | Metrics |
| AWS Batch | CloudWatch Logs → Firehose | AWS Logs |

---

## Prerequisites

- AWS CLI v2 with SSO credentials (`us-west-2`)
- Terraform >= 1.3
- Docker
- kubectl + Helm 3 (for EKS module)
