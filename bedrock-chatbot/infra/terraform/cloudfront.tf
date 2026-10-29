# CloudFront fronts both the static chat page (S3) and the API (Web Function).
#   /*     -> private S3 frontend bucket (OAC)
#   /api/* -> Web Function prod endpoint (OAC, always-amz-auth)

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# ---- Frontend bucket (private; served only through CloudFront) ----
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-frontend-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The chat page. Uploaded by Terraform; etag triggers re-upload on change.
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "index.html"
  source       = "${path.module}/../../frontend/index.html"
  content_type = "text/html"
  etag         = filemd5("${path.module}/../../frontend/index.html")
}

# Let CloudFront (this distribution only) read objects from the bucket.
data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid       = "AllowCloudFrontOAC"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json
}

# ---- Origin access controls ----
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.project}-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Lambda Web Function OAC. Uses awscc because the aws provider doesn't allow
# the required `always-amz-auth` signing behavior.
resource "awscc_cloudfront_origin_access_control" "lambda" {
  origin_access_control_config = {
    name                              = "${var.project}-lambda-oac"
    origin_access_control_origin_type = "lambda"
    signing_behavior                  = "always-amz-auth"
    signing_protocol                  = "sigv4"
  }
}

# ---- Distribution ----
resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  comment             = var.project
  price_class         = "PriceClass_100" # North America + Europe (cheapest)
  http_version        = "http2and3"
  is_ipv6_enabled     = false
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  origin {
    domain_name              = var.web_function_domain
    origin_id                = "web-function"
    origin_access_control_id = awscc_cloudfront_origin_access_control.lambda.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Static chat page from S3.
  default_cache_behavior {
    target_origin_id       = "frontend-s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_disabled.id
  }

  # API to the Web Function; no caching, forward all viewer headers but Host.
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "web-function"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
