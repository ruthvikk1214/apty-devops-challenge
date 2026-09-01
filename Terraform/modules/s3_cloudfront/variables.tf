variable "environment" {
  description = "Deployment environment label displayed on the banner (Dev or Prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
}

variable "bucket_name" {
  description = "Name of the private S3 bucket that will host the static site"
  type        = string
}

variable "index_template" {
  description = "Path to the HTML template file"
  type        = string
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}