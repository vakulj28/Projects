# Pre-create the Web Function log groups with retention, so logs don't
# accumulate forever (and cost) under an auto-created never-expiring group.

resource "aws_cloudwatch_log_group" "web" {
  name              = "/aws/lambda/web/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "web_local" {
  name              = "/aws/lambda/web/${var.function_name}.local"
  retention_in_days = var.log_retention_days
}
