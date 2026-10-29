# CloudFront in front of the IamAuth Web Function endpoint. CloudFront signs
# each origin request (OAC), so browsers don't sign requests themselves.

# No caching for a dynamic/streaming API; forward all viewer headers except
# Host (so x-access-code reaches the app, and Host stays the origin's).
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
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

resource "aws_cloudfront_distribution" "main" {
  enabled         = true
  comment         = "${var.project} API"
  price_class     = "PriceClass_100" # North America + Europe (cheapest)
  http_version    = "http2and3"
  is_ipv6_enabled = true

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

  default_cache_behavior {
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
