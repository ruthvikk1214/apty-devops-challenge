terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }

  backend "s3" {
    bucket         = "apty-remote-state-2026"
    key            = "environments/dev/terraform.tfstate" # Separate path per environment
    region         = "us-east-1"
    dynamodb_table = "apty-remote-state-2026"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
