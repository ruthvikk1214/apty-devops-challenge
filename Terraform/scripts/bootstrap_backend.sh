#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------
# 1️⃣  Configuration
# -----------------------------------------------------------------
STATE_BUCKET="apty-remote-state-2026"
LOCK_TABLE="apty-remote-state-2026"
REGION="us-east-1"   # keep this the same as you use in provider.tf

# -----------------------------------------------------------------
# 2️⃣  Create‑bucket with proper arguments for the region
# -----------------------------------------------------------------
create_bucket() {
  local bucket_name=$1
  local region=$2

  echo "Creating S3 bucket \"$bucket_name\" in region \"$region\" …"

  if [[ "$region" == "us-east-1" ]]; then
    # us-east-1 does NOT accept a LocationConstraint
    aws s3api create-bucket --bucket "$bucket_name" --region "$region"
  else
    # All other regions require the constraint flag
    aws s3api create-bucket \
      --bucket "$bucket_name" \
      --region "$region" \
      --create-bucket-configuration LocationConstraint="$region"
  fi
}

# -----------------------------------------------------------------
# 3️⃣  Create the bucket
# -----------------------------------------------------------------
create_bucket "$STATE_BUCKET" "$REGION"

# -----------------------------------------------------------------
# 4️⃣  Enable versioning
# -----------------------------------------------------------------
aws s3api put-bucket-versioning \
  --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled

# -----------------------------------------------------------------
# 5️⃣  Enable server‑side encryption (AES‑256)
# -----------------------------------------------------------------
aws s3api put-bucket-encryption \
  --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{ "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" } }]
  }'

# -----------------------------------------------------------------
# 6️⃣  Create the DynamoDB lock table (used by Terraform)
# -----------------------------------------------------------------
aws dynamodb create-table \
  --table-name "$LOCK_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION"

# -----------------------------------------------------------------
# 7️⃣  Result
# -----------------------------------------------------------------
echo "Remote‑state bucket & lock table created."

