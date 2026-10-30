locals {
  cf_policy_caching_optimized             = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cf_policy_caching_disabled              = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  cf_origin_req_all_viewer_except_host    = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
}

resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.prefix}-s3-oac"
  description                       = "Origin Access Control for StayHub S3 Frontend and Media buckets"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_function" "spa_rewrite" {
  name    = "${var.prefix}-spa-rewrite"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrites client-side React Router paths to /index.html without affecting /api/* or static assets"
  publish = true

  code = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.includes('.')) {
        return request;
      }
      request.uri = '/index.html';
      return request;
    }
  EOT
}

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.prefix}-${var.project_name} unified CDN (Frontend + API + Media)"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  wait_for_deployment = false

  # Origin 1: Frontend S3 Bucket
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # Origin 2: Media S3 Bucket
  origin {
    domain_name              = aws_s3_bucket.media.bucket_regional_domain_name
    origin_id                = "s3-media"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # Origin 3: Backend Application Load Balancer
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "alb-backend"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default Behavior (/* -> Frontend S3 SPA)
  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = local.cf_policy_caching_optimized

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_rewrite.arn
    }
  }

  # Ordered Behavior 1: Backend API (/api/* -> ALB)
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "alb-backend"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = local.cf_policy_caching_disabled
    origin_request_policy_id = local.cf_origin_req_all_viewer_except_host
  }

  # Ordered Behavior 2: Backend Healthcheck (/healthz -> ALB)
  ordered_cache_behavior {
    path_pattern             = "/healthz"
    target_origin_id         = "alb-backend"
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD", "OPTIONS"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = local.cf_policy_caching_disabled
    origin_request_policy_id = local.cf_origin_req_all_viewer_except_host
  }

  # Ordered Behavior 3: Uploaded Media (/uploads/* -> Media S3 Bucket)
  ordered_cache_behavior {
    path_pattern           = "/uploads/*"
    target_origin_id       = "s3-media"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = local.cf_policy_caching_optimized
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.prefix}-cf-distribution"
  }
}
