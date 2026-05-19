output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = aws_acm_certificate.main.arn
}

output "name_servers" {
  description = "Domain registrar par ye name servers lagao"
  value       = aws_route53_zone.main.name_servers
}

output "nlb_hostname" {
  description = "NLB hostname"
  value       = helm_release.nginx_ingress.status[0].load_balancer[0].ingress[0].hostname
}
