# APTY DevOps Challenge — Environment Banner

A static web application that displays its deployment environment (**Dev** or **Prod**), shipped two ways:
1. **AWS Infrastructure**: S3 + CloudFront via Terraform
2. **Kubernetes Application**: Containerized Nginx via Docker + Helm on Kind

---

## 🌐 Live CloudFront URL

> **Live Site URL:** `https://<CLOUDFRONT_DOMAIN>` *(generated after `terraform apply`)*  
> Retrieve dynamically via CLI: `terraform output -raw cloudfront_url`

---

## 🚀 Quick Run Instructions

### Prerequisites
Required tools: `git`, `docker`, `terraform` (≥ 1.5), `aws-cli` (v2), `kubectl`, `helm`, `kind`.

#### Quick Setup on EC2 (Amazon Linux 2023)
```bash
# 1. Install Docker, Git, Kubectl, Helm, and Kind
sudo dnf update -y && sudo dnf install -y git docker
sudo systemctl enable --now docker && sudo usermod -aG docker ec2-user

curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.28.3/2023-11-14/bin/linux/amd64/kubectl && chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/

# 2. Apply Docker group & Clone Repository
newgrp docker
git clone https://github.com/ruthvikk1214/apty-devops-challenge.git
cd apty-devops-challenge
```

---

### Option A — Deploying AWS Infrastructure (Terraform)

```bash
cd Terraform/root

# 1. Initialize & validate
terraform init
terraform validate

# 2. Deploy Dev environment
terraform apply -var-file=env-dev.tfvars -auto-approve

# 3. Get the live CloudFront URL
terraform output -raw cloudfront_url
```

---

### Option B — Deploying Local Kubernetes App (Docker + Helm + Kind)

```bash
# 1. Build Docker image
cd Docker
docker build -t apty-static:latest .
cd ..

# 2. Create Kind cluster and load image
kind create cluster --name apty-cluster
kind load docker-image apty-static:latest --name apty-cluster

# 3. Deploy Dev & Prod releases with Helm
export GIT_SHA=$(git rev-parse --short HEAD)

helm install apty-dev ./helm/apty-static --set env=Dev --set commitSha=$GIT_SHA
helm install apty-prod ./helm/apty-static --set env=Prod --set commitSha=$GIT_SHA

# 4. Verify local port-forwards
kubectl port-forward --address 0.0.0.0 svc/apty-dev-apty-static 8080:80 &
kubectl port-forward --address 0.0.0.0 svc/apty-prod-apty-static 8081:80 &

curl -s http://localhost:8080 | grep "Environment:"
curl -s http://localhost:8081 | grep "Environment:"
```

---

## ⚙️ GitHub Actions CI/CD Pipeline

The pipeline (`.github/workflows/ci.yaml`) runs on push to `main` and pull requests:
- **Security Audit**: Runs Checkov static code analysis against Terraform files.
- **Terraform CI**: Executes `fmt -check`, `validate`, and multi-environment `plan` (Dev & Prod).
- **Terraform Apply**: Gated on push to `main` with manual environment approval.
- **Helm & Kind Integration**: Spins up an ephemeral Kind cluster, builds the image, deploys releases, and verifies pod rollout status.

---

## ⚖️ Key Trade-offs & Future Improvements

**Key Trade-offs:**
- **CloudFront Default Domain vs. Custom Domain + ACM:** Used CloudFront's default domain with standard TLS certificate instead of custom Route53 DNS + ACM certificates. This avoids 20–30 minute DNS validation delays during deployment while securing traffic over HTTPS out-of-the-box.
- **Dynamic Helm SHA Injection:** Passed the Git commit SHA dynamically into Helm ConfigMaps to keep container deployment lightweight and avoid unnecessary Terraform state churn.

**What I'd Do With More Time:**
- **Environment State Isolation:** Use distinct S3 state keys per environment (`-backend-config="key=env/dev.tfstate"`).
- **Keyless AWS Authentication:** Migrate GitHub Actions authentication from IAM long-lived keys to OIDC role assumption.
- **Automated E2E Testing:** Implement Terratest (Go) to validate CloudFront HTTPS endpoints and HTML content automatically after deployment.
