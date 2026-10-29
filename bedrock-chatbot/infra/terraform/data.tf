data "aws_caller_identity" "current" {}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # This org customizes the OIDC subject claim to embed numeric owner/repo IDs
    # (repo:owner@<id>/repo@<id>:...), so pin the repo via the clean `repository`
    # claim and wildcard the sub's id portion.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository"
      values   = [var.github_repo]
    }

    # Pull requests (CI) and pushes/manual runs on main may plan.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:*:pull_request",
        "repo:*:ref:refs/heads/main",
      ]
    }
  }
}

# Let the Lambda service read code objects, scoped to this function's revisions.
data "aws_iam_policy_document" "code_bucket" {
  statement {
    sid    = "AllowLambdaWebFunctionCodeAccess"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.code.arn}/*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:web-function/${var.function_name}/revision/*",
      ]
    }
  }
}


# Role the Web Function assumes at runtime.
data "aws_iam_policy_document" "execution_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "execution" {
  # Write logs. Web Functions use both the centralized and per-region (.local)
  # log groups; the .local ARN uses a region wildcard by design.
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/web/${var.function_name}:*",
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/web/${var.function_name}.local:*",
    ]
  }

  # Invoke only Nova Lite — the inference profile and the models it routes to.
  statement {
    sid    = "InvokeNovaLite"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.model_id}",
      "arn:aws:bedrock:*::foundation-model/${local.foundation_model_id}",
    ]
  }

  # Read the one access-code secret.
  statement {
    sid       = "ReadAccessCode"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.access_code.arn]
  }
}

# Write-capable "apply" role for CI. Trusted ONLY by the protected GitHub
# Environment, so a run must be approved before it can assume this role.
data "aws_iam_policy_document" "apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository"
      values   = [var.github_repo]
    }

    # Gated by the protected environment; match the clean `environment` claim
    # (the sub embeds numeric IDs under this org's custom claim template).
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:environment"
      values   = [var.github_environment]
    }

    # AWS requires a sub (or job_workflow_ref) condition that isn't scoped to
    # all. Constrain it to this environment's deployments.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:*:environment:${var.github_environment}"]
    }
  }
}

# Permissions Terraform needs to manage this stack. Broad at the service level
# because IaC creates resources whose ARNs aren't known ahead of time; the real
# guardrails are the environment approval gate and the environment-scoped trust
# above. Tightening iam:* with a permissions boundary is a production hardening.
data "aws_iam_policy_document" "apply" {
  statement {
    sid    = "ManageStack"
    effect = "Allow"
    actions = [
      "s3:*",
      "iam:*",
      "budgets:*",
      "secretsmanager:*",
      "logs:*",
      "bedrock:GetInferenceProfile",
      "bedrock:ListInferenceProfiles",
    ]
    resources = ["*"]
  }
}

# Trust for the app-deploy role: automatic on pushes to main (CD, ungated).
data "aws_iam_policy_document" "deploy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:repository"
      values   = [var.github_repo]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:*:ref:refs/heads/main"]
    }
  }
}

# Least-privilege app deploy: write the code package to the code bucket only.
data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "UploadCode"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.code.arn,
      "${aws_s3_bucket.code.arn}/*",
    ]
  }
}