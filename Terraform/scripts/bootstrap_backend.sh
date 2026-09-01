#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------
# 1️⃣  Configuration — edit these to match your provider.tf backend
# -----------------------------------------------------------------
STATE_BUCKET="apty-remote-state-2026"
LOCK_TABLE="apty-remote-state-2026"
REGION="us-east-1"

echo "=== Bootstrapping Terraform Remote State ==="
echo "  Bucket : $STATE_BUCKET"
echo "  Table  : $LOCK_TABLE"
echo "  Region : $REGION"
echo ""

# -----------------------------------------------------------------
# 2️⃣  Create the S3 state bucket (idempotent)
# -----------------------------------------------------------------
if aws s3api head-bucket --bucket "$STATE_BUCKET" --region "$REGION" 2>/dev/null; then
  echo "✔ S3 bucket \"$STATE_BUCKET\" already exists — skipping."
else
  echo "Creating S3 bucket \"$STATE_BUCKET\" in region \"$REGION\" …"
  if [[ "$REGION" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION"
  else
    aws s3api create-bucket \
      --bucket "$STATE_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  echo "✔ Bucket created."
fi

# -----------------------------------------------------------------
# 3️⃣  Enable versioning
# -----------------------------------------------------------------
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled
echo "✔ Versioning enabled."

# -----------------------------------------------------------------
# 4️⃣  Enable server-side encryption (AES-256)
# -----------------------------------------------------------------
aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }]
  }'
echo "✔ Encryption enabled."

# -----------------------------------------------------------------
# 5️⃣  Block all public access
# -----------------------------------------------------------------
aws s3api put-public-access-block \
  --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
echo "✔ Public access blocked."

# -----------------------------------------------------------------
# 6️⃣  Create the DynamoDB lock table (idempotent)
# -----------------------------------------------------------------
if aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$REGION" >/dev/null 2>&1; then
  echo "✔ DynamoDB table \"$LOCK_TABLE\" already exists — skipping."
else
  echo "Creating DynamoDB table \"$LOCK_TABLE\" …"
  aws dynamodb create-table \
    --table-name "$LOCK_TABLE" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "$REGION"
  echo "✔ Lock table created."
fi

# -----------------------------------------------------------------
# 7️⃣  Done
# -----------------------------------------------------------------
echo ""
echo "=== Bootstrap complete ==="
echo "You can now run:  cd Terraform/root && terraform init"
