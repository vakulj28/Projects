output "state_bucket_name" {
  value = aws_s3_bucket.tf_state.id
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "ci_plan_role_arn" {
  value = aws_iam_role.ci_plan.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}