output "cloudfront_domain" {
  description = "The CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.website.domain_name
}
