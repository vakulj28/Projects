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
  # Identity lookup used by the config.
  statement {
    sid       = "STS"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  # The two project buckets (state + code) and their config.
  statement {
    sid    = "S3Buckets"
    effect = "Allow"
    actions = [
      "s3:CreateBucket", "s3:DeleteBucket", "s3:ListBucket", "s3:GetBucketLocation",
      "s3:GetBucketTagging", "s3:PutBucketTagging",
      "s3:GetBucketVersioning", "s3:PutBucketVersioning",
      "s3:GetEncryptionConfiguration", "s3:PutEncryptionConfiguration",
      "s3:GetBucketPublicAccessBlock", "s3:PutBucketPublicAccessBlock",
      "s3:GetBucketPolicy", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:GetBucketPolicyStatus",
      "s3:GetBucketAcl", "s3:GetBucketCORS", "s3:GetBucketWebsite", "s3:GetBucketLogging",
      "s3:GetLifecycleConfiguration", "s3:GetReplicationConfiguration",
      "s3:GetBucketObjectLockConfiguration", "s3:GetAccelerateConfiguration",
      "s3:GetBucketRequestPayment", "s3:GetBucketNotification", "s3:GetBucketOwnershipControls",
    ]
    resources = ["arn:aws:s3:::bedrock-chatbot-*"]
  }

  # State and code objects (for the backend and refresh).
  statement {
    sid       = "S3Objects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectVersion"]
    resources = ["arn:aws:s3:::bedrock-chatbot-tfstate/*", "arn:aws:s3:::bedrock-chatbot-code-*/*"]
  }

  # Only this project's IAM roles.
  statement {
    sid    = "IAMRoles"
    effect = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy", "iam:ListRolePolicies",
      "iam:AttachRolePolicy", "iam:DetachRolePolicy", "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/bedrock-chatbot-*"]
  }

  # The GitHub OIDC provider.
  statement {
    sid    = "IAMOIDCProvider"
    effect = "Allow"
    actions = [
      "iam:GetOpenIDConnectProvider", "iam:CreateOpenIDConnectProvider", "iam:DeleteOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider", "iam:UntagOpenIDConnectProvider",
      "iam:AddClientIDToOpenIDConnectProvider", "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
  }

  # The monthly budget.
  statement {
    sid       = "Budgets"
    effect    = "Allow"
    actions   = ["budgets:ViewBudget", "budgets:ModifyBudget", "budgets:ListTagsForResource"]
    resources = ["arn:aws:budgets::${data.aws_caller_identity.current.account_id}:budget/bedrock-chatbot-*"]
  }

  # The access-code secret.
  statement {
    sid    = "SecretsManager"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret", "secretsmanager:DeleteSecret", "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue", "secretsmanager:UpdateSecret",
      "secretsmanager:TagResource", "secretsmanager:UntagResource", "secretsmanager:GetResourcePolicy",
      "secretsmanager:ListSecretVersionIds",
    ]
    resources = ["arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:bedrock-chatbot/*"]
  }

  # The Web Function log groups.
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
      "logs:TagResource", "logs:UntagResource", "logs:ListTagsForResource",
    ]
    resources = ["arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/web/bedrock-chatbot*"]
  }

  # DescribeLogGroups is a list operation and can't be scoped to one ARN.
  statement {
    sid       = "LogsDescribe"
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["*"]
  }

  # CloudFront distribution + OAC + managed-policy lookups. CloudFront actions
  # don't support resource-level scoping, so they're constrained by action.
  statement {
    sid    = "CloudFront"
    effect = "Allow"
    actions = [
      "cloudfront:CreateDistribution", "cloudfront:CreateDistributionWithTags",
      "cloudfront:GetDistribution", "cloudfront:GetDistributionConfig",
      "cloudfront:UpdateDistribution", "cloudfront:DeleteDistribution",
      "cloudfront:TagResource", "cloudfront:UntagResource", "cloudfront:ListTagsForResource",
      "cloudfront:CreateOriginAccessControl", "cloudfront:GetOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl", "cloudfront:DeleteOriginAccessControl",
      "cloudfront:ListCachePolicies", "cloudfront:GetCachePolicy",
      "cloudfront:ListOriginRequestPolicies", "cloudfront:GetOriginRequestPolicy",
    ]
    resources = ["*"]
  }

  # Cloud Control API (awscc OAC). Its operations are authorized under the
  # cloudformation namespace, not cloudcontrol.
  statement {
    sid    = "CloudControl"
    effect = "Allow"
    actions = [
      "cloudformation:CreateResource", "cloudformation:GetResource", "cloudformation:GetResourceRequestStatus",
      "cloudformation:UpdateResource", "cloudformation:DeleteResource", "cloudformation:ListResources",
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