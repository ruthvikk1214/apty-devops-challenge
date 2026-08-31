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

## Part 2 – Docker + Helm Deployment (Local Kubernetes)

This part packages the static page in an **nginx** container and deploys it to a local Kubernetes cluster (Kind, K3d, or Minikube) using a Helm chart.

### Files added
- `Dockerfile` – builds an nginx image serving `index.html`.
- `index.html` – static HTML page with a placeholder for the environment name (`{{ .Values.env }}`).
- `helm/apty-static/` – Helm chart containing:
  - `Chart.yaml`
  - `values.yaml` (default `env: Dev`)
  - `templates/deployment.yaml`
  - `templates/service.yaml`
  - `_helpers.tpl`

### Build and Deploy
```bash
# Build the Docker image
docker build -t apty-static:latest .

# Load the image into your local cluster (choose one)
# Kind:
kind load docker-image apty-static:latest
# K3d:
k3d image import apty-static:latest --cluster <cluster-name>
# Minikube:
minikube image load apty-static:latest

# Install the Helm chart (override env as needed)
helm install apty-static ./helm/apty-static --set env=Dev
# For Prod:
helm install apty-static-prod ./helm/apty-static --set env=Prod

# Port‑forward to view the site
kubectl port-forward svc/apty-static 8080:80
# Open in browser:
open http://localhost:8080
```

The banner on the page displays the environment name passed via the Helm `env` value.

### Cleanup
```bash
helm uninstall apty-static   # or the release name you used
kubectl delete svc apty-static
```

For more details, see the Helm chart files under `helm/apty-static/`.