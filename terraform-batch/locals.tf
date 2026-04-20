data "aws_caller_identity" "current" {}

locals {
  account_id     = data.aws_caller_identity.current.account_id
  job_script = file("${path.module}/scripts/etl_job.py")

  datasets = ["equity_derivatives", "fx_options", "interest_rate_swaps"]

  sfn_definition = jsonencode({
    Comment = "Finance Trade Pricing Pipeline - parallel portfolio pricing jobs"
    StartAt = "RunPricingPipeline"
    States = {
      RunPricingPipeline = {
        Type = "Parallel"
        Branches = [
          for ds in local.datasets : {
            StartAt = "Submit-${ds}"
            States = {
              "Submit-${ds}" = {
                Type     = "Task"
                Resource = "arn:aws:states:::batch:submitJob.sync"
                Parameters = {
                  "JobName.$"     = "States.Format('pricing-${ds}-{}', $$.Execution.Name)"
                  JobDefinition   = aws_batch_job_definition.trade_pricing.arn
                  JobQueue        = aws_batch_job_queue.main.arn
                  ContainerOverrides = {
                    Environment = [
                      { Name = "PORTFOLIO",     Value = ds },
                      { Name = "BATCH_PIPELINE", Value = "trade-pricing" }
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
        Next = "PricingComplete"
      }
      PricingComplete = {
        Type = "Pass"
        Parameters = {
          pipeline = "trade-pricing"
          status   = "COMPLETE"
        }
        End = true
      }
    }
  })
}
