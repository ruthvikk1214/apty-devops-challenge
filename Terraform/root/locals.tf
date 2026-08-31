locals {
  bucket_name = "${lower(var.project_name)}-${lower(var.environment)}-static-site"
}
