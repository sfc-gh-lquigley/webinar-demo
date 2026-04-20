resource "aws_scheduler_schedule" "etl_pipeline" {
  name       = "${var.prefix}-etl-trigger"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "rate(3 minutes)"

  target {
    arn      = aws_sfn_state_machine.etl_pipeline.arn
    role_arn = aws_iam_role.scheduler.arn

    input = jsonencode({
      source     = "eventbridge-scheduler"
      trigger_id = "etl-pipeline-schedule"
    })

    retry_policy {
      maximum_retry_attempts = 0
    }
  }
}
