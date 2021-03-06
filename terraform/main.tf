# Zone created by AWS Registar
data "aws_route53_zone" "blog" {
  name = var.domain
}

resource "aws_s3_bucket" "blog" {
  bucket = var.domain
  acl    = "public-read"
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
      {
          "Sid": "PublicReadForGetBucketObjects",
          "Effect": "Allow",
          "Principal": {
              "AWS": "*"
           },
           "Action": "s3:GetObject",
           "Resource": "arn:aws:s3:::${var.domain}/*"
      }
    ]
}
EOF

  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "blog" {
  origin {
    domain_name = aws_s3_bucket.blog.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.blog.bucket}"

    custom_origin_config {
      // These are all the defaults.
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = [var.domain]

  # By default, show index.html file
  default_root_object = "index.html"
  enabled             = true

  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.blog.bucket}"

    forwarded_values {
      query_string = false

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
  # Distributes content to US and Europe
  price_class = "PriceClass_100"
  # Restricts who is able to access this content
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.blog.certificate_arn
    minimum_protocol_version = "TLSv1"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_route53_record" "blog" {
  zone_id = data.aws_route53_zone.blog.zone_id
  name = var.domain
  type = "A"

  alias {
    name = aws_cloudfront_distribution.blog.domain_name
    zone_id = aws_cloudfront_distribution.blog.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "blog" {
  domain_name       = var.domain
  validation_method = "DNS"
  subject_alternative_names = [var.www_domain]
}

resource "aws_route53_record" "acm_domain_validation_cn" {
  name   = aws_acm_certificate.blog.domain_validation_options.0.resource_record_name
  records = [aws_acm_certificate.blog.domain_validation_options.0.resource_record_value]
  type   = aws_acm_certificate.blog.domain_validation_options.0.resource_record_type
  allow_overwrite = true
  ttl             = 60
  zone_id         = data.aws_route53_zone.blog.zone_id
}

resource "aws_route53_record" "acm_domain_validation_san" {
  name   = aws_acm_certificate.blog.domain_validation_options.1.resource_record_name
  records = [aws_acm_certificate.blog.domain_validation_options.1.resource_record_value]
  type   = aws_acm_certificate.blog.domain_validation_options.1.resource_record_type
  allow_overwrite = true
  ttl             = 60
  zone_id         = data.aws_route53_zone.blog.zone_id
}

resource "aws_acm_certificate_validation" "blog" {
  certificate_arn         = aws_acm_certificate.blog.arn
  validation_record_fqdns = [aws_route53_record.acm_domain_validation_cn.fqdn, aws_route53_record.acm_domain_validation_san.fqdn]
}

resource "aws_s3_bucket" "www_redirect" {
  bucket = var.www_domain
  acl    = "public-read"
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
      {
          "Sid": "PublicReadForGetBucketObjects",
          "Effect": "Allow",
          "Principal": {
              "AWS": "*"
           },
           "Action": "s3:GetObject",
           "Resource": "arn:aws:s3:::${var.www_domain}/*"
      }
    ]
}
EOF

  website {
    redirect_all_requests_to = "https://${var.domain}"
  }
}

resource "aws_cloudfront_distribution" "www_redirect" {
  origin {
    domain_name = aws_s3_bucket.www_redirect.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.www_redirect.bucket}"

    custom_origin_config {
      // These are all the defaults.
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases = [var.www_domain]

  enabled             = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "S3-${aws_s3_bucket.www_redirect.bucket}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "allow-all"
  }
  # Distributes content to US and Europe
  price_class = "PriceClass_100"
  # Restricts who is able to access this content
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate_validation.blog.certificate_arn
    minimum_protocol_version = "TLSv1"
    ssl_support_method  = "sni-only"
  }
}

resource "aws_route53_record" "www_redirect" {
  zone_id = data.aws_route53_zone.blog.zone_id
  name = var.www_domain
  type = "A"

  alias {
    name = aws_cloudfront_distribution.www_redirect.domain_name
    zone_id = aws_cloudfront_distribution.www_redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "google_search_console_verification" {
  zone_id = data.aws_route53_zone.blog.zone_id
  name = var.domain
  type = "TXT"
  ttl = 300

  records = ["google-site-verification=I55mkygDlJPbZMSS1rpbR6oNLy_BRL_MUeR4AKa6Ul0"]
}