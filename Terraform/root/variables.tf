variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment (Dev or Prod)"
  type        = string

  validation {
    condition     = contains(["Dev", "Prod"], var.environment)
    error_message = "environment must be \"Dev\" or \"Prod\""
  }
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "apty-v2"
}