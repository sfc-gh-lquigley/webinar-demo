resource "aws_batch_compute_environment" "fargate" {
  compute_environment_name = "${var.prefix}-fargate"
  type                     = "MANAGED"
  service_role             = aws_iam_role.batch_service.arn

  compute_resources {
    type               = "FARGATE_SPOT"
    max_vcpus          = 16
    subnets            = var.private_subnet_ids
    security_group_ids = [aws_security_group.batch.id]
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service]
}

resource "aws_batch_compute_environment" "fargate_ondemand" {
  compute_environment_name = "${var.prefix}-fargate-ondemand"
  type                     = "MANAGED"
  service_role             = aws_iam_role.batch_service.arn

  compute_resources {
    type               = "FARGATE"
    max_vcpus          = 8
    subnets            = var.private_subnet_ids
    security_group_ids = [aws_security_group.batch.id]
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service]
}

resource "aws_batch_job_queue" "main" {
  name     = "${var.prefix}-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.fargate.arn
  }

  compute_environment_order {
    order               = 2
    compute_environment = aws_batch_compute_environment.fargate_ondemand.arn
  }
}

resource "aws_batch_job_definition" "etl" {
  name = "${var.prefix}-etl-ingestion"
  type = "container"

  platform_capabilities = ["FARGATE"]

  container_properties = jsonencode({
    image   = "python:3.11-slim"
    command = ["python3", "-c", local.etl_job_script]

    resourceRequirements = [
      { type = "VCPU",   value = "0.25" },
      { type = "MEMORY", value = "512" }
    ]

    executionRoleArn = aws_iam_role.batch_execution.arn
    jobRoleArn       = aws_iam_role.batch_job.arn

    environment = [
      { name = "ETL_DATASET",  value = "default" },
      { name = "ETL_PIPELINE", value = "batch-etl-pipeline" },
      { name = "ETL_SOURCE",   value = "s3://observe-demo-datalake/raw" },
      { name = "ETL_DEST",     value = "s3://observe-demo-datalake/processed" }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "etl-ingestion"
      }
    }

    networkConfiguration = {
      assignPublicIp = "DISABLED"
    }

    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }
  })

  retry_strategy {
    attempts = 2
  }

  timeout {
    attempt_duration_seconds = 300
  }
}
