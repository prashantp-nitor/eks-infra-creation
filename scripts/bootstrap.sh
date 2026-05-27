#!/usr/bin/env bash
# Provisions the S3 bucket and DynamoDB table used as Terraform remote state backend.
# Run once per AWS account before any `terraform init`.
#
# Usage: ./scripts/bootstrap.sh [REGION] [PROJECT]
# Example: ./scripts/bootstrap.sh us-east-1 daas
set -euo pipefail

REGION="${1:-us-east-1}"
PROJECT="${2:-daas}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="${PROJECT}-terraform-state-${ACCOUNT_ID}"
DYNAMODB_TABLE="terraform-state-lock"

echo "==> Bootstrapping Terraform backend"
echo "    Account  : ${ACCOUNT_ID}"
echo "    Region   : ${REGION}"
echo "    Bucket   : ${BUCKET_NAME}"
echo "    DynamoDB : ${DYNAMODB_TABLE}"
echo ""

# ── S3 Bucket ──────────────────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "[skip] S3 bucket already exists: ${BUCKET_NAME}"
else
  echo "[create] S3 bucket: ${BUCKET_NAME}"
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET_NAME}" --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

echo "[config] Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET_NAME}" \
  --versioning-configuration Status=Enabled

echo "[config] Enabling server-side encryption (SSE-KMS)..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "aws:kms" },
      "BucketKeyEnabled": true
    }]
  }'

echo "[config] Blocking all public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ── DynamoDB Table ──────────────────────────────────────────────────────────────
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${REGION}" &>/dev/null; then
  echo "[skip] DynamoDB table already exists: ${DYNAMODB_TABLE}"
else
  echo "[create] DynamoDB table: ${DYNAMODB_TABLE}"
  aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}"

  echo "[wait] Waiting for table to become active..."
  aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${REGION}"
fi

# ── Update backend configs ──────────────────────────────────────────────────────
echo ""
echo "==> Bootstrap complete! Update the backend blocks in each environment:"
echo ""
echo '    bucket         = "'"${BUCKET_NAME}"'"'
echo '    dynamodb_table = "'"${DYNAMODB_TABLE}"'"'
echo '    region         = "'"${REGION}"'"'
echo ""
echo "    Example sed command:"
echo '    sed -i "s/REPLACE_WITH_YOUR_STATE_BUCKET/'"${BUCKET_NAME}"'/g" \\'
echo '      terraform/environments/*/main.tf'
