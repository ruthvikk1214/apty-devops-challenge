output "cloudfront_domain" {
  description = "The CloudFront distribution domain name that serves the static site"
  value       = module.static_site.cloudfront_domain
}

output "cloudfront_url" {
  description = "Full HTTPS URL of the deployed static site"
  value       = module.static_site.cloudfront_url
}

output "bucket_name" {
  description = "The S3 bucket name that stores the static site"
  value       = local.bucket_name
}
