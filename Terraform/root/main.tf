module "static_site" {
  source       = "../modules/s3_cloudfront"
  environment  = var.environment
  aws_region   = var.aws_region
  bucket_name  = local.bucket_name
  commit_sha   = var.commit_sha
  project_name = var.project_name
  # Pass the absolute or relative path to the template file
  index_template = "${path.module}/../modules/s3_cloudfront/templates/index.html.tftpl"
}
