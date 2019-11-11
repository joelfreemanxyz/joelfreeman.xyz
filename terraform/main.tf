provider "aws" {
  region = "ap-southeast-2"
}

resource "aws_s3_bucket" "bucket { // setup s3 bucket for website
  bucket = "joelfreeman.xyz"
  acl    = "public-read" // allow people to read it by default

  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

resource "aws_acm_certificate" "ssl_cert" { //create a cert
    domain_name       = "joelfreeman.xyz"
    validation_method = "DNS"
}

data "aws_route53_zone" "hosted_zone" { // pull in information from Route53 so we can create DNS records to verify cert
    name         = "joelfreeman.xyz."
    private_zone = false
}
resource "aws_route53_record" "ssl_cert_dns_validation_records" { // create cert validation records in route53
    name        = "${aws_acm_certificate.ssl_cert.domain_validation_options.0.resource_record_name}"
    type        = "${aws_acm_certificate.ssl_cert.domain_validation_options.0.resource_record_type}"
    zone_id     = "${data.aws_route53_zone.hosted_zone.id}"
	  records     = ["${aws_acm_certificate.ssl_cert.domain_validation_options.0.resource_record_value}"]
	    ttl       = 60
}

resource "aws_acm_certificate_validation" "ssl_cert_validation" { // verify the newly created ssl certificate
    certificate_arn           = "${aws_acm_certificate.ssl_cert.arn}"
    validation_record_fqdns   = ["${aws_route53_record.cert_validation.fqdn}"]
}

resource "aws_cloudfront_distribution" "bucket_distribution" { // create cloudfront distribution, needs to be finished.
  origin {
    domain_name = "${aws_s3_bucket.bucket_regional_domain_name}"
    origin {
      custom_origin_config {
        http_port = "80"
        https_port = "443"
        origin_protocol_policy = "http-only"
        origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      }
      domain_name = "${aws_s3_bucket.bucket.website_endpoint}"
      origin_id = "joelfreeman.xyz"
    }

    enabled = true
    default_root_object = "index.html"

    default_cache_behavior {
      viewer_protocol_policy = "redirect-to-https"
      compress = true
      allowed_methosd = ["GET", "HEAD"]
      cached_methods = ["GET", "HEAD"]
      target_origin_id = "joelfreeman.xyz"
      min_ttl = 0
      default_ttl = 86400
      max_ttl = 31536000

      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }
    }
    aliases = "joelfreeman.xyz"

    restrictions {
      geo_restriction {
        restriction_type = none
      }
    }

    viewer_certificate {
      acm_certificate_arn = "${aws_acm_certificate.ssl_cert.arn}"
      ssl_support_method = "sni-only"
    }
  }
  
  resource "aws_route53_record" "cloudfront_A_record_joelfreeman.xyz" { // create A record pointing root domain to cloudfront distribution
    zone_id = "${aws_route53_zone.hosted_zone.zone_id}"
    name = "joelfreeman.xyz"
    type = A

    alias {
      name = "${aws_cloudfront_distribution.bucket_distribution.domain_name}"
      zone_id = "${aws_cloudfront_distribution.bucket_distribution.zone_id}"
      evaluate_zone_id = false
    }
  }






