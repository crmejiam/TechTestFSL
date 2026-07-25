resource "aws_s3_bucket" "app_bucket" {
  bucket = "${var.resource_name_prefix}-${var.environment}-app"

  tags = {
    Name        = "${var.resource_name_prefix}-${var.environment}-app"
    Environment = "${var.environment}"
  }
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "app_bucket_block" {
  bucket = aws_s3_bucket.app_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.resource_name_prefix}-${var.environment}-logs"

  tags = {
    Name        = "${var.resource_name_prefix}-${var.environment}-logs"
    Environment = "${var.environment}"
  }
  force_destroy = true
}

data "aws_iam_policy_document" "origin_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalReadWrite"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]

    resources = [
      "${aws_s3_bucket.app_bucket.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "app_bucket" {
  bucket = aws_s3_bucket.app_bucket.bucket
  policy = data.aws_iam_policy_document.origin_bucket_policy.json
}

locals {
  s3_origin_id = "S3-${aws_s3_bucket.app_bucket.id}"
#   my_domain    = "mydomain.com"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "${var.resource_name_prefix}-${var.environment}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.b.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

#   aliases = ["mysite.${local.my_domain}", "yoursite.${local.my_domain}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "${var.environment}"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  logging_config {
    bucket = aws_s3_bucket.log_bucket.domain_name
    include_cookies = false
    prefix = "cloudfront/"
  }
}

# # Create Route53 records for the CloudFront distribution aliases
# data "aws_route53_zone" "my_domain" {
#   name = local.my_domain
# }

# resource "aws_route53_record" "cloudfront" {
#   for_each = aws_cloudfront_distribution.s3_distribution.aliases
#   zone_id  = data.aws_route53_zone.my_domain.zone_id
#   name     = each.value
#   type     = "A"

#   alias {
#     name                   = aws_cloudfront_distribution.s3_distribution.domain_name
#     zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
#     evaluate_target_health = false
#   }
# }
