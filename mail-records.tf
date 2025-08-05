resource "aws_route53_record" "mail" {
  zone_id = aws_route53_zone.main.zone_id
  name    = ""
  type    = "MX"
  ttl     = 3600

  records = [
    "1 smtp.google.com"
  ]
}

resource "aws_route53_record" "mail-secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "mail"
  type    = "MX"
  ttl     = 3600

  records = [
    "1 smtp.google.com"
  ]
}
