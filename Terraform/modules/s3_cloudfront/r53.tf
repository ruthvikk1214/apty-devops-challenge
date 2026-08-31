resource "aws_route53_record" "cloudfront_alias" {
  zone_id = var.zone_id       # Hosted‑zone ID you supplied
  name    = var.custom_domain # e.g. apty-devops.rk1214.in
  type    = "A"
  alias {
    name = aws_cloudfront_distribution.website.domain_name

    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
