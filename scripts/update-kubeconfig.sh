#!/usr/bin/env bash
# Updates ~/.kube/config with credentials for the specified EKS cluster.
#
# Usage: ./scripts/update-kubeconfig.sh <environment> [region]
# Example: ./scripts/update-kubeconfig.sh prod us-east-1
set -euo pipefail

ENVIRONMENT="${1:?Usage: $0 <environment> [region]}"
REGION="${2:-us-east-1}"
TF_DIR="terraform/environments/${ENVIRONMENT}"

if [ ! -d "${TF_DIR}" ]; then
  echo "Error: environment directory not found: ${TF_DIR}" >&2
  exit 1
fi

echo "==> Reading cluster name from Terraform state (${ENVIRONMENT})..."
CLUSTER_NAME=$(terraform -chdir="${TF_DIR}" output -raw cluster_name 2>/dev/null)

if [ -z "${CLUSTER_NAME}" ]; then
  echo "Error: could not read cluster_name output from ${TF_DIR}" >&2
  echo "       Make sure you have run 'terraform apply' for this environment first." >&2
  exit 1
fi

echo "==> Updating kubeconfig for cluster: ${CLUSTER_NAME}"
aws eks update-kubeconfig \
  --region "${REGION}" \
  --name "${CLUSTER_NAME}" \
  --alias "eks-${ENVIRONMENT}"

echo ""
echo "==> Done. Active context set to: eks-${ENVIRONMENT}"
echo "    kubectl get nodes"
