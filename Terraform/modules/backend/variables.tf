variable "aws_region" {
  description = "AWS region for the backend bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for bucket / table names"
  type        = string
  default     = "apty"
}
