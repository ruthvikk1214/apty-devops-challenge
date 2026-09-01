# APTY DevOps Challenge — Environment Banner

A static web page that displays its deployment environment (**Dev** or **Prod**), shipped two ways:

1. **AWS** — S3 + CloudFront via Terraform
2. **Local Kubernetes** — Nginx container via Docker + Helm

CI validates the Terraform and deploys the Helm chart into an ephemeral Kind cluster on every push.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | ≥ 1.5 | Infrastructure as Code |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) | v2 | AWS API access |
| [Docker](https://docs.docker.com/get-docker/) | ≥ 20 | Container builds |
| [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) | ≥ 0.22 | Local Kubernetes cluster |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | ≥ 1.28 | Kubernetes CLI |
| [Helm](https://helm.sh/docs/intro/install/) | ≥ 3.14 | Kubernetes package manager |

### Quick Install on EC2 (Amazon Linux 2023)
Run this block to install Docker, Git, Helm, Kind, and Kubectl all at once:
```bash
# 1. Update and install Git & Docker
sudo dnf update -y
sudo dnf install -y git docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# 2. Install kubectl
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.28.3/2023-11-14/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# 3. Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
rm get_helm.sh

# 4. Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# 5. Apply Docker group changes (Log out and log back in, or run this)
newgrp docker

# 6. Validate Installations
git --version
docker --version
kubectl version --client
helm version
kind --version
```

---

## Repository Structure

```
.
├── .github/workflows/ci.yaml          # GitHub Actions CI pipeline
├── Docker/
│   ├── Dockerfile                      # Nginx container image
│   └── index.html                      # Placeholder (overridden by ConfigMap)
├── Terraform/
│   ├── modules/
│   │   ├── backend/                    # Bootstrap module for state bucket + DynamoDB
│   │   └── s3_cloudfront/              # S3 + CloudFront + OAC + cache invalidation
│   │       └── templates/
│   │           └── index.html.tftpl    # HTML template with ${environment} placeholder
│   ├── root/                           # Root Terraform configuration
│   │   ├── provider.tf                 # Backend (S3 + DynamoDB lock) & AWS provider
│   │   ├── main.tf                     # Module call
│   │   ├── variables.tf                # environment, commit_sha, region, project_name
│   │   ├── outputs.tf                  # CloudFront URL + bucket name
│   │   ├── locals.tf                   # Computed bucket name
│   │   ├── env-dev.tfvars              # Dev variable values
│   │   └── env-prod.tfvars             # Prod variable values
│   └── scripts/
│       └── bootstrap_backend.sh        # One-time state backend setup
└── helm/apty-static/                   # Helm chart
    ├── Chart.yaml
    ├── values.yaml                     # Defaults: env=Dev, commitSha=local-build
    └── templates/
        ├── _helpers.tpl
        ├── configmap.yaml              # Renders index.html with env + commitSha
        ├── deployment.yaml             # Nginx pod with security context + probes
        ├── hpa.yaml                    # HPA (disabled by default)
        └── service.yaml                # ClusterIP service
```

---

## Part 1 — Terraform: S3 + CloudFront

### 1.1 Bootstrap Remote State (one-time)

The Terraform backend stores state in S3 with DynamoDB locking. Before the first `terraform init`, create the backend resources:

```bash
# Configure AWS credentials
export AWS_ACCESS_KEY_ID="<your-key>"
export AWS_SECRET_ACCESS_KEY="<your-secret>"
export AWS_DEFAULT_REGION="us-east-1"

# Run the bootstrap script (idempotent — safe to re-run)
bash Terraform/scripts/bootstrap_backend.sh
```

This creates:
- S3 bucket `apty-remote-state-2026` (versioned, encrypted, public access blocked)
- DynamoDB table `apty-remote-state-2026` (PAY_PER_REQUEST, LockID key)

### 1.2 Deploy

```bash
cd Terraform/root

# Initialise (connects to remote backend)
terraform init

# Format check (CI also runs this)
terraform fmt -check -recursive ../

# Validate
terraform validate

# Deploy Dev environment
terraform apply -var-file=env-dev.tfvars -var="commit_sha=$(git rev-parse --short HEAD)"

# Deploy Prod environment (uses the same state — switch via tfvars)
terraform apply -var-file=env-prod.tfvars -var="commit_sha=$(git rev-parse --short HEAD)"
```

### 1.3 Access the Site

After apply, retrieve the live URL:

```bash
terraform output -raw cloudfront_url
# → https://d1234abcdef.cloudfront.net
```

> **Live CloudFront URL:** `https://<CLOUDFRONT_DOMAIN>` _(replace after apply)_

### 1.4 Cleanup

```bash
terraform destroy -var-file=env-dev.tfvars
```

---

## Part 2 — Docker + Helm on Local Kubernetes

### 2.1 Build the Docker Image

```bash
cd Docker
docker build -t apty-static:latest .
```

### 2.2 Create a Kind Cluster & Load the Image

```bash
kind create cluster --name apty-cluster
kind load docker-image apty-static:latest --name apty-cluster
```

### 2.3 Deploy with Helm

```bash
# Set the Git SHA for the banner
export GIT_SHA=$(git rev-parse --short HEAD)

# Deploy Dev
helm install apty-dev ./helm/apty-static \
  --set env=Dev \
  --set commitSha=$GIT_SHA \
  --set image.pullPolicy=IfNotPresent

# Deploy Prod (side-by-side on the same cluster)
helm install apty-prod ./helm/apty-static \
  --set env=Prod \
  --set commitSha=$GIT_SHA \
  --set image.pullPolicy=IfNotPresent
```

### 2.4 Verify

```bash
# Check pods are Running
kubectl get pods -l "app.kubernetes.io/name=apty-static"

# Port-forward Dev (localhost:8080) — bind to all interfaces for EC2 access
kubectl port-forward --address 0.0.0.0 svc/apty-dev-apty-static 8080:80 &

# Port-forward Prod (localhost:8081) — bind to all interfaces for EC2 access
kubectl port-forward --address 0.0.0.0 svc/apty-prod-apty-static 8081:80 &

# Test via cURL locally
curl -s http://localhost:8080 | grep "Environment:"
curl -s http://localhost:8081 | grep "Environment:"

# Open in browser (if on a local machine, or using EC2 Public IP)
# Dev:  http://<IP>:8080  → Blue banner "Environment: Dev"
# Prod: http://<IP>:8081  → Red banner "Environment: Prod"
```

### 2.5 Cleanup

```bash
helm uninstall apty-dev
helm uninstall apty-prod
kind delete cluster --name apty-cluster
```

---

## Part 3 — GitHub Actions CI

The CI pipeline (`.github/workflows/ci.yaml`) runs on every **push to `main`** and **pull request**:

| Job | What it does |
|-----|-------------|
| **Security Scan** | Runs [Checkov](https://www.checkov.io/) against all Terraform code |
| **Terraform CI** | `fmt -check` → `init` → `validate` → `plan` (Dev + Prod) |
| **Terraform Apply** | _(main only, manual approval)_ Applies the Dev environment |
| **Helm & Kind** | `helm lint` → builds Docker image → spins up a Kind cluster → deploys Dev + Prod releases and checks rollout status |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM access key with S3, CloudFront, DynamoDB permissions |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |

> **Note:** For OIDC-based auth (no long-lived keys), see the commented-out `role-to-assume` block in `ci.yaml`.

### Manual Approval Gate

The `terraform-apply` job uses the GitHub `production` environment, which requires manual approval in **Settings → Environments → production → Required reviewers**.

---

## Bonus Features Implemented

| Feature | Where |
|---------|-------|
| ✅ CloudFront cache invalidation on deploy | `modules/s3_cloudfront/main.tf` — `null_resource.invalidate_cache` |
| ✅ `terraform apply` gated on `main` with manual approval | `.github/workflows/ci.yaml` — `terraform-apply` job |
| ✅ Helm lint + Kind integration test in CI | `.github/workflows/ci.yaml` — `helm-and-kind-ci` job |
| ✅ Checkov security scanning in pipeline | `.github/workflows/ci.yaml` — `security-scan` job |
| ✅ HPA on the Deployment | `helm/apty-static/templates/hpa.yaml` (disabled by default) |
| ✅ Banner shows Git commit SHA | Terraform `commit_sha` variable + Helm `commitSha` value |
| 📝 OIDC auth to AWS | Documented in `ci.yaml` as commented alternative |

---

## Key Trade-offs & What I'd Do With More Time

**Trade-off: Default CloudFront domain vs. custom domain.** I chose the default `*.cloudfront.net` URL instead of a custom domain with ACM certificate. A custom domain adds ACM provisioning + DNS validation which takes 20–30 minutes per apply and significantly complicates the feedback loop during development. For a real production deployment, I'd add the custom domain behind a feature flag and use a pre-provisioned wildcard certificate.

**What I'd do with more time:**
- **Separate state paths per environment** — use `-backend-config="key=environments/dev/terraform.tfstate"` at `terraform init` to fully isolate dev/prod state, rather than switching via tfvars within the same state file.
- **OIDC authentication** — replace long-lived IAM keys with GitHub's OIDC provider for keyless AWS access in CI.
- **Terratest** — add Go-based integration tests that verify the CloudFront distribution returns the correct HTML after apply.
- **Multi-stage Helm environments** — use separate `values-dev.yaml` and `values-prod.yaml` files instead of `--set` flags for more complex configurations.
- **Monitoring** — add CloudWatch alarms for CloudFront error rates and a Prometheus ServiceMonitor for the Kubernetes deployment.
