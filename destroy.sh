#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}"

AWS_REGION="${AWS_REGION:-${TF_VAR_aws_region:-eu-west-1}}"
PREFIX="${TF_VAR_prefix:-aniket}"

echo "======================================================================="
echo " StayHub AWS Stack Tear-Down (${PREFIX}-stayhub in ${AWS_REGION})"
echo "======================================================================="

TF_BIN=""
if command -v terraform >/dev/null 2>&1; then
  TF_BIN="terraform"
elif command -v tofu >/dev/null 2>&1; then
  TF_BIN="tofu"
else
  echo "ERROR: Neither 'terraform' nor 'tofu' (OpenTofu) is installed."
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: Required tool 'aws' is not installed."
  exit 1
fi

"${TF_BIN}" -chdir="${INFRA_DIR}" init -input=false

# Empty S3 buckets if they exist before running terraform destroy
FRONTEND_BUCKET="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw frontend_s3_bucket 2>/dev/null || true)"
MEDIA_BUCKET="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw media_s3_bucket 2>/dev/null || true)"

if [[ -n "${FRONTEND_BUCKET}" ]]; then
  echo "Emptying S3 frontend bucket s3://${FRONTEND_BUCKET}..."
  aws s3 rm "s3://${FRONTEND_BUCKET}" --recursive --region "${AWS_REGION}" 2>/dev/null || true
fi

if [[ -n "${MEDIA_BUCKET}" ]]; then
  echo "Emptying S3 media bucket s3://${MEDIA_BUCKET}..."
  aws s3 rm "s3://${MEDIA_BUCKET}" --recursive --region "${AWS_REGION}" 2>/dev/null || true
fi

echo "Destroying all ${TF_BIN}-managed AWS resources..."
"${TF_BIN}" -chdir="${INFRA_DIR}" destroy -input=false -auto-approve \
  -var="aws_region=${AWS_REGION}" \
  -var="prefix=${PREFIX}"

echo "======================================================================="
echo " StayHub AWS Stack Destroyed Successfully!"
echo "======================================================================="
