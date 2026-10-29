# CI role that uploads the built code package to S3 (app CD, ungated).
resource "aws_iam_role" "ci_deploy" {
  name               = "${var.project}-ci-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_trust.json
}

resource "aws_iam_role_policy" "ci_deploy" {
  name   = "${var.project}-ci-deploy"
  role   = aws_iam_role.ci_deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}
