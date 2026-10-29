# CI role that runs `terraform apply`, gated behind the GitHub Environment.
resource "aws_iam_role" "ci_apply" {
  name               = "${var.project}-ci-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

resource "aws_iam_role_policy" "ci_apply" {
  name   = "${var.project}-ci-apply"
  role   = aws_iam_role.ci_apply.id
  policy = data.aws_iam_policy_document.apply.json
}
