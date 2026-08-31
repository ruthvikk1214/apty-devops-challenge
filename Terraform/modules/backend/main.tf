terraform {
  # Use a *local* backend so this config can run before the real remote backend exists.
  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

/* --------------------- Remote‑state bucket --------------------- */
resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-${var.aws_region}-tf-state"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    ManagedBy = "terraform-bootstrap"
  }
}

/* ------------------ Optional DynamoDB lock table ------------------ */
resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.project_name}-${var.aws_region}-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    ManagedBy = "terraform-bootstrap"
  }
}

/* -------------------------- Outputs -------------------------- */
output "bucket_name" {
  description = "Name of the S3 bucket to store remote state"
  value       = aws_s3_bucket.tf_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for state locking (if you keep it)"
  value       = aws_dynamodb_table.tf_lock.id
}
