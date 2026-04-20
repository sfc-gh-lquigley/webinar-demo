resource "aws_sfn_state_machine" "etl_pipeline" {
  name     = "${var.prefix}-etl-pipeline"
  role_arn = aws_iam_role.sfn.arn

  definition = local.sfn_definition

  logging_configuration {
    level                  = "ERROR"
    include_execution_data = false
    log_destination        = "${aws_cloudwatch_log_group.sfn.arn}:*"
  }
}

resource "aws_cloudwatch_log_group" "sfn" {
  name              = "/aws/states/${var.prefix}-etl-pipeline"
  retention_in_days = 14
}
