# apty-devops-challenge

## Overview
This repository demonstrates a Terraform‑driven deployment of a static website hosted on S3 behind a CloudFront distribution using **Origin Access Control (OAC)**.

## Architecture
- **S3 bucket** (private) stores `index.html`.
- **CloudFront distribution** serves the site and uses OAC for secure access.
- Bucket policy grants CloudFront read access via the OAC ARN.
- Versioning and server‑side encryption are enabled on the bucket.
- Terraform backend is stored in S3 with native state locking (`use_lockfile = true`).

## Key Features Implemented
- Added `provider.tf` backend configuration with `use_lockfile` (replaces deprecated `dynamodb_table`).
- Created `locals.tf` to generate a unique bucket name: `${lower(var.project_name)}-${lower(var.environment)}-static-site`.
- Defined variables with defaults for `environment` (Dev) and `project_name` (apty) and removed the unused `bucket_name` variable.
- Updated `variables.tf` to **remove the default** for `environment` so Terraform prompts for the environment on apply.
- Fixed CloudFront configuration: removed legacy `s3_origin_config` block and added `default_root_object = "index.html"`.
- Updated HTML template to use Terraform interpolation `${ environment }` instead of Jinja style `{{ environment }}`.
- Added ACM certificate provisioning and DNS validation for a custom domain.
- Added an A‑alias Route 53 record that maps `apty-devops.rk1214.in` to the CloudFront distribution.
- Added outputs for `bucket_name` and `cloudfront_domain`.
- Added documentation and a comprehensive README.

## Usage
```bash
# Initialise backend (required after backend change)
terraform init -reconfigure

# Deploy (you will be prompted for the environment – Dev or Prod)
terraform apply -auto-approve

# Or use a var‑file for non‑interactive runs
terraform apply -auto-approve -var-file=env-dev.tfvars   # Deploy to Dev
terraform apply -auto-approve -var-file=env-prod.tfvars  # Deploy to Prod
```

## Accessing the Site
After a successful apply, retrieve the CloudFront domain:
```bash
terraform output -raw cloudfront_domain
```
Visit `https://<cloudfront_domain>` to see the banner with the selected environment name.

### Custom Domain
The deployment also provisions an ACM certificate for the domain **apty-devops.rk1214.in** and creates a Route 53 A‑alias record. Once the apply finishes, you can access the site directly via:
```bash
https://apty-devops.rk1214.in
```
The DNS record points to the CloudFront distribution and the certificate ensures HTTPS works without warnings.

## Cleanup
```bash
terraform destroy -auto-approve
```

## Repository Structure
- `Terraform/root/` – Root module with variables, locals, provider, outputs.
- `Terraform/modules/s3_cloudfront/` – Module that creates the S3 bucket, CloudFront distribution, OAC, policies, etc.
- `Terraform/modules/s3_cloudfront/templates/index.html.tftpl` – HTML template used for the static site.