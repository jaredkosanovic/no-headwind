data "aws_route53_zone" "blog" {
  name = "noheadwind.com"
}

resource "aws_s3_bucket" "blog" {
  bucket = "noheadwind.com"
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
           "Resource": "arn:aws:s3:::noheadwind.com/*"
      }
    ]
}
EOF
}

# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "blog" {
  origin {
    domain_name = aws_s3_bucket.blog.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.blog.bucket}"
  }

  aliases = ["noheadwind.com"]

  # By default, show index.html file
  default_root_object = "index.html"
  enabled             = true
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
      # type of restriction, blacklist, whitelist or none
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
  name = "noheadwind.com"
  type = "A"

  alias {
    name = aws_cloudfront_distribution.blog.domain_name
    zone_id = aws_cloudfront_distribution.blog.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate" "blog" {
  domain_name       = "noheadwind.com"
  validation_method = "DNS"
  subject_alternative_names = ["www.noheadwind.com"]
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
