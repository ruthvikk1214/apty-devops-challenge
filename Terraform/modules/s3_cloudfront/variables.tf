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

variable "custom_domain" {
  description = "Fully‑qualified domain name you want to point at CloudFront"
  type        = string
  default     = "apty-devops.rk1214.in"
}

variable "zone_id" {
  description = "Hosted‑zone ID for the domain in Route 53"
  type        = string
  default     = "Z031906510N5GWM6MW07L"
}

