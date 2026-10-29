locals {
  # The inference profile "eu.amazon.nova-lite-v1:0" routes to the foundation
  # model "amazon.nova-lite-v1:0" across EU regions. Strip the geo prefix.
  foundation_model_id = replace(var.model_id, "/^(eu|us|apac|global)\\./", "")
}

resource "aws_iam_role" "execution" {
  name               = "${var.project}-web-exec"
  assume_role_policy = data.aws_iam_policy_document.execution_trust.json
}

resource "aws_iam_role_policy" "execution" {
  name   = "${var.project}-web-exec"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution.json
}
