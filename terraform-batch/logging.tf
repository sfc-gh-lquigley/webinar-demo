resource "aws_cloudwatch_log_group" "batch" {
  name              = "/aws/batch/job"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_subscription_filter" "batch_to_observe" {
  name            = "observe-batch-logs"
  log_group_name  = aws_cloudwatch_log_group.batch.name
  filter_pattern  = ""
  destination_arn = var.logwriter_firehose_arn
  role_arn        = var.logwriter_destination_role_arn

  depends_on = [aws_cloudwatch_log_group.batch]
}
