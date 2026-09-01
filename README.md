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

# Helm Install For Dev Environment
helm install apty-dev ./helm/apty-static \
  --set env=Dev \
  --set commitSha=$GIT_SHA \
  --set image.pullPolicy=IfNotPresent

# Helm Install For Prod Environment
helm install apty-prod ./helm/apty-static \
  --set env=Prod \
  --set commitSha=$GIT_SHA \
  --set image.pullPolicy=IfNotPresent

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

### Prerequisites & Host Setup (Fresh Instance)

Run the following commands on a freshly launched EC2 instance to install and configure all required tooling:

```bash
# 1. Install native docker and git
sudo dnf install -y docker git

# 2. Start and enable Docker service
sudo systemctl enable --now docker

# 3. Add ec2-user to the docker group
sudo usermod -aG docker $USER

# 4. Refresh your group session (or run: newgrp docker)
newgrp docker

# 1. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# 2. Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 3. Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
# 6. Verify installations
docker --version
kubectl version --client
kind --version
helm version
Architecture & Key Features Implemented
Decoupled Configuration via ConfigMap: Dynamic HTML markup and environment-specific banner styling (#0288d1 for Dev, #d32f2f for Prod) are managed entirely through Helm values and mounted into /usr/share/nginx/html/index.html.

Automatic Rolling Restarts: Configured checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }} under spec.template.metadata.annotations in deployment.yaml. Any upgrade to the ConfigMap triggers a zero-downtime rolling restart of the pods automatically.

Standardized Helpers: Added templates/_helpers.tpl to provide resource naming and label helpers across all Kubernetes resources.

Side-by-Side Multi-Environment Deployments: Supports deploying completely isolated releases (apty-dev and apty-prod) concurrently on the same cluster.

Repository Structure (Helm)
Plaintext
helm/apty-static/
├── Chart.yaml
├── values.yaml
└── templates/
    ├── _helpers.tpl
    ├── configmap.yaml
    ├── deployment.yaml
    ├── hpa.yaml
    └── service.yaml
Step-by-Step Deployment Guide
1. Clone the Repository & Build Image
Bash
git clone https://github.com/ruthvikk1214/apty-devops-challenge.git
cd apty-devops-challenge/Docker

# Build the Nginx base image
docker build -t apty-static:latest .
2. Create the Kind Cluster & Load the Image
Bash
# Create local Kubernetes cluster
kind create cluster --name apty-cluster

# Pre-load local Docker image directly into the Kind control plane node
kind load docker-image apty-static:latest --name apty-cluster
3. Deploy Dev and Prod Environments via Helm
Bash
# Deploy Dev environment release
helm install apty-dev ./helm/apty-static --set env=Dev

# Deploy Prod environment release side-by-side
helm install apty-prod ./helm/apty-static --set env=Prod

# Verification and Testing
Check that all pods and services across both environments are healthy (1/1 Running):

Bash
kubectl get pods,svc -l "app.kubernetes.io/name=apty-static"
Test Both Endpoints Side-by-Side
Forward ports in the background to access each environment independently:

Bash
# Clean up any lingering port-forward processes
pkill -f "kubectl port-forward"


# Forward Dev service to port 8080 and Prod service to port 8081
kubectl port-forward --address 0.0.0.0 svc/apty-dev-apty-static 8080:80 &
kubectl port-forward --address 0.0.0.0 svc/apty-prod-apty-static 8081:80 &

# 1. Verify Dev Endpoint (Returns Blue Banner: "Environment: Dev")
http://<public-ip-address>:8080

# 2. Verify Prod Endpoint (Returns Red Banner: "Environment: Prod")
http://<public-ip-address>:8081

# Stop port-forwards when validation is complete
pkill -f "kubectl port-forward"
In-Place Upgrade & Checksum Verification
To test Helm's dynamic values injection and automatic rolling pod restarts without rebuilding the Docker image:

Bash
# Upgrade the Dev release to Prod dynamically
helm upgrade apty-dev ./helm/apty-static --set env=Prod

# Verify automatic rollout status
kubectl rollout status deployment/apty-dev-apty-static
Teardown & Cleanup
Bash
# Uninstall Helm releases
helm uninstall apty-dev
helm uninstall apty-prod

# Delete the local Kind cluster
kind delete cluster --name apty-cluster

