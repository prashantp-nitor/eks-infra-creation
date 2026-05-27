#!/usr/bin/env bash
# Creates the GitHub Actions OIDC provider and per-environment IAM roles in AWS.
# This eliminates the need for long-lived AWS access keys in GitHub secrets.
#
# Usage: ./scripts/setup-github-oidc.sh <github-org> <github-repo> [region]
# Example: ./scripts/setup-github-oidc.sh myorg daas-eks-infra-setup us-east-1
set -euo pipefail

GITHUB_ORG="${1:?Usage: $0 <github-org> <github-repo> [region]}"
GITHUB_REPO="${2:?Usage: $0 <github-org> <github-repo> [region]}"
REGION="${3:-us-east-1}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_URL="token.actions.githubusercontent.com"
OIDC_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

echo "==> Setting up GitHub Actions OIDC for ${GITHUB_ORG}/${GITHUB_REPO}"
echo "    Account: ${ACCOUNT_ID} | Region: ${REGION}"
echo ""

# ── OIDC Provider ──────────────────────────────────────────────────────────────
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"

if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "${OIDC_ARN}" &>/dev/null; then
  echo "[skip] GitHub OIDC provider already exists"
else
  echo "[create] GitHub OIDC provider"
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_URL}" \
    --client-id-list "sts.amazonaws.com" \
    --thumbprint-list "${OIDC_THUMBPRINT}"
fi

# ── IAM Roles per environment ──────────────────────────────────────────────────
for ENV in dev staging prod; do
  ROLE_NAME="github-actions-eks-${ENV}"
  echo "[create] IAM role: ${ROLE_NAME}"

  TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Federated": "${OIDC_ARN}" },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${OIDC_URL}:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "${OIDC_URL}:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
)

  if aws iam get-role --role-name "${ROLE_NAME}" &>/dev/null; then
    echo "[skip] Role already exists: ${ROLE_NAME}"
  else
    aws iam create-role \
      --role-name "${ROLE_NAME}" \
      --assume-role-policy-document "${TRUST_POLICY}" \
      --description "GitHub Actions OIDC role for EKS ${ENV} environment"
  fi

  # Attach AdministratorAccess — scope down to least-privilege in production
  aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"

  ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"
  echo "    ARN: ${ROLE_ARN}"
  echo ""
done

echo "==> Add these as GitHub repository secrets:"
echo ""
echo "    Secret name           Value"
echo "    ─────────────────     ───────────────────────────────────────────────────────────"
echo "    AWS_ROLE_ARN_DEV      arn:aws:iam::${ACCOUNT_ID}:role/github-actions-eks-dev"
echo "    AWS_ROLE_ARN_STAGING  arn:aws:iam::${ACCOUNT_ID}:role/github-actions-eks-staging"
echo "    AWS_ROLE_ARN_PROD     arn:aws:iam::${ACCOUNT_ID}:role/github-actions-eks-prod"
