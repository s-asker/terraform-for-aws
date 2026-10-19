resource "aws_acm_certificate" "cert" {
  domain_name       = var.hosting_domain
  validation_method = "DNS"

  tags = {
    Environment = "main"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_zone" "dns_zone" {
  name = "sherifasker.online"
}

resource "aws_route53_record" "dns_record" {
  zone_id = aws_route53_zone.dns_zone.zone_id
  name    = var.hosting_domain
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cert_dns_record" {
  for_each = { for cert_data in aws_acm_certificate.cert.domain_validation_options : cert_data.domain_name =>
    {
      name   = cert_data.resource_record_name
      type   = cert_data.resource_record_type
      record = cert_data.resource_record_value
    }
  }

  zone_id = aws_route53_zone.dns_zone.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

# resource "aws_acm_certificate_validation" "cert_validation" {
#   certificate_arn         = aws_acm_certificate.cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_dns_record : record.fqdn]
# }


import {
  to = aws_route53_zone.dns_zone
  identity = {
    zone_id = "Z0785552X78YYIF5XZL3"
  }
}
