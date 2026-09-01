module "static_site" {
  source         = "../modules/s3_cloudfront"
  environment    = var.environment
  aws_region     = var.aws_region
  bucket_name    = local.bucket_name
  project_name   = var.project_name
  index_template = "${path.module}/../modules/s3_cloudfront/templates/index.html.tftpl"
}

