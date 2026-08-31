variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
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
  type = string
}
