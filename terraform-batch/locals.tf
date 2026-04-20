data "aws_caller_identity" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  etl_job_script = file("${path.module}/scripts/etl_job.py")

  datasets = ["customers", "orders", "inventory"]

  sfn_definition = jsonencode({
    Comment = "ETL Batch Pipeline - submits parallel data ingestion jobs"
    StartAt = "RunETLPipeline"
    States = {
      RunETLPipeline = {
        Type = "Parallel"
        Branches = [
          for ds in local.datasets : {
            StartAt = "Submit-${ds}"
            States = {
              "Submit-${ds}" = {
                Type     = "Task"
                Resource = "arn:aws:states:::batch:submitJob.sync"
                Parameters = {
                  "JobName.$"     = "States.Format('etl-${ds}-{}', $$.Execution.Name)"
                  JobDefinition   = aws_batch_job_definition.etl.arn
                  JobQueue        = aws_batch_job_queue.main.arn
                  ContainerOverrides = {
                    Environment = [
                      { Name = "ETL_DATASET",  Value = ds },
                      { Name = "ETL_PIPELINE", Value = "batch-etl-pipeline" }
                    ]
                  }
                }
                Retry = [
                  {
                    ErrorEquals = ["Batch.BatchException", "States.TaskFailed"]
                    MaxAttempts = 1
                    IntervalSeconds = 10
                    BackoffRate = 2
                  }
                ]
                Catch = [
                  {
                    ErrorEquals = ["States.ALL"]
                    Next        = "JobFailed-${ds}"
                    ResultPath  = "$.error"
                  }
                ]
                End = true
              }
              "JobFailed-${ds}" = {
                Type = "Pass"
                Parameters = {
                  dataset = ds
                  status  = "FAILED"
                }
                End = true
              }
            }
          }
        ]
        Next = "PipelineComplete"
      }
      PipelineComplete = {
        Type = "Pass"
        Parameters = {
          pipeline = "batch-etl-pipeline"
          status   = "COMPLETE"
        }
        End = true
      }
    }
  })
}
