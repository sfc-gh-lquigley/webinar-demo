output "batch_compute_environment_fargate" {
  value = aws_batch_compute_environment.fargate.arn
}

output "batch_job_queue" {
  value = aws_batch_job_queue.main.arn
}

output "batch_job_definition" {
  value = aws_batch_job_definition.trade_pricing.arn
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.batch.name
}

output "step_functions_state_machine" {
  value = aws_sfn_state_machine.etl_pipeline.arn
}

output "scheduler" {
  value = aws_scheduler_schedule.etl_pipeline.arn
}
