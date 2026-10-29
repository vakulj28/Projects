provider "aws" {
  region = var.aws_region

  # Credentials come from the environment: the AWS_PROFILE env var locally
  # (e.g. AWS_PROFILE=chatbot), or the OIDC-assumed role in GitHub Actions.
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      CreatedBy = "Vakul.Jain"
    }
  }
}

# Cloud Control provider — used only for the Lambda Web Function OAC, which
# needs the `always-amz-auth` signing behavior the aws provider doesn't allow.
provider "awscc" {
  region = var.aws_region
}