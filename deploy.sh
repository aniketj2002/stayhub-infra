#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}"

# Resolve backend directory (supports monorepo or side-by-side stayhub-be repo)
if [[ -d "${SCRIPT_DIR}/../backend" ]]; then
  BACKEND_DIR="${BACKEND_DIR:-${SCRIPT_DIR}/../backend}"
elif [[ -d "${SCRIPT_DIR}/../../stayhub-be" ]]; then
  BACKEND_DIR="${BACKEND_DIR:-${SCRIPT_DIR}/../../stayhub-be}"
else
  BACKEND_DIR="${BACKEND_DIR:-${SCRIPT_DIR}/../backend}"
fi

# Resolve frontend directory (supports monorepo or side-by-side stayhub-fe repo)
if [[ -d "${SCRIPT_DIR}/../frontend" ]]; then
  FRONTEND_DIR="${FRONTEND_DIR:-${SCRIPT_DIR}/../frontend}"
elif [[ -d "${SCRIPT_DIR}/../../stayhub-fe" ]]; then
  FRONTEND_DIR="${FRONTEND_DIR:-${SCRIPT_DIR}/../../stayhub-fe}"
else
  FRONTEND_DIR="${FRONTEND_DIR:-${SCRIPT_DIR}/../frontend}"
fi

CLI_REGION="$(aws configure get region 2>/dev/null || true)"
AWS_REGION="${AWS_REGION:-${TF_VAR_aws_region:-${AWS_DEFAULT_REGION:-${CLI_REGION:-us-east-1}}}}"
PREFIX="${TF_VAR_prefix:-aniket}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

echo "======================================================================="
echo " StayHub AWS Deployment (${PREFIX}-stayhub in ${AWS_REGION})"
echo "======================================================================="

# 1. Verify required tools & detect Terraform or OpenTofu
TF_BIN=""
if command -v terraform >/dev/null 2>&1; then
  TF_BIN="terraform"
elif command -v tofu >/dev/null 2>&1; then
  TF_BIN="tofu"
else
  echo "ERROR: Neither 'terraform' nor 'tofu' (OpenTofu) is installed."
  echo ""
  echo "To install on macOS, run either:"
  echo "  brew install opentofu"
  echo "OR:"
  echo "  brew tap hashicorp/tap && brew install hashicorp/tap/terraform"
  exit 1
fi

for cmd in aws docker npm; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: Required tool '${cmd}' is not installed."
    if [[ "$(uname -s)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
      echo "Hint: brew install awscli"
    fi
    exit 1
  fi
done

# 2. Verify AWS authentication
echo "[1/6] Verifying AWS credentials..."
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text --region "${AWS_REGION}")"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --region "${AWS_REGION}")"
echo "      Authenticated as: ${CALLER_ARN} (Account: ${ACCOUNT_ID})"

# 3. Initialize Terraform & provision ECR repositories first
echo "[2/6] Initializing with ${TF_BIN} and provisioning ECR repositories..."
"${TF_BIN}" -chdir="${INFRA_DIR}" init -input=false
"${TF_BIN}" -chdir="${INFRA_DIR}" apply -input=false -auto-approve \
  -var="aws_region=${AWS_REGION}" \
  -var="prefix=${PREFIX}" \
  -target=aws_ecr_repository.api \
  -target=aws_ecr_repository.worker

ECR_API_URL="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw ecr_api_repository_url)"
ECR_WORKER_URL="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw ecr_worker_repository_url)"

# 4. Build and push Backend API & Worker images (linux/amd64 for Fargate X86_64)
echo "[3/6] Building and pushing Docker images to Amazon ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

docker build --platform linux/amd64 \
  -f "${BACKEND_DIR}/Dockerfile.api" \
  -t "${ECR_API_URL}:${IMAGE_TAG}" \
  "${BACKEND_DIR}"
docker push "${ECR_API_URL}:${IMAGE_TAG}"

docker build --platform linux/amd64 \
  -f "${BACKEND_DIR}/Dockerfile.worker" \
  -t "${ECR_WORKER_URL}:${IMAGE_TAG}" \
  "${BACKEND_DIR}"
docker push "${ECR_WORKER_URL}:${IMAGE_TAG}"

# 5. Provision complete AWS infrastructure stack (VPC, RDS, Redis, S3, ALB, ECS, CloudFront)
echo "[4/6] Applying full infrastructure stack with ${TF_BIN}..."
"${TF_BIN}" -chdir="${INFRA_DIR}" apply -input=false -auto-approve \
  -var="aws_region=${AWS_REGION}" \
  -var="prefix=${PREFIX}" \
  -var="api_image_tag=${IMAGE_TAG}" \
  -var="worker_image_tag=${IMAGE_TAG}"

FRONTEND_BUCKET="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw frontend_s3_bucket)"
CF_DIST_ID="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw cloudfront_distribution_id)"
ECS_CLUSTER="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw ecs_cluster_name)"
ECS_API_SVC="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw ecs_api_service_name)"
ECS_WORKER_SVC="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw ecs_worker_service_name)"
APP_URL="$("${TF_BIN}" -chdir="${INFRA_DIR}" output -raw app_url)"

# 6. Build Frontend SPA and sync to S3 + CloudFront
echo "[5/6] Building Frontend SPA and syncing to s3://${FRONTEND_BUCKET}..."
(
  cd "${FRONTEND_DIR}"
  npm ci
  VITE_API_BASE_URL="" npm run build
)

aws s3 sync "${FRONTEND_DIR}/dist" "s3://${FRONTEND_BUCKET}" \
  --delete \
  --exclude "index.html" \
  --cache-control "public, max-age=31536000, immutable" \
  --region "${AWS_REGION}"

aws s3 cp "${FRONTEND_DIR}/dist/index.html" "s3://${FRONTEND_BUCKET}/index.html" \
  --cache-control "no-cache, no-store, must-revalidate" \
  --content-type "text/html; charset=utf-8" \
  --region "${AWS_REGION}"

echo "[6/6] Triggering CloudFront cache invalidation and ECS rollout..."
aws cloudfront create-invalidation \
  --distribution-id "${CF_DIST_ID}" \
  --paths "/*" >/dev/null

aws ecs update-service \
  --cluster "${ECS_CLUSTER}" \
  --service "${ECS_API_SVC}" \
  --force-new-deployment \
  --region "${AWS_REGION}" >/dev/null

aws ecs update-service \
  --cluster "${ECS_CLUSTER}" \
  --service "${ECS_WORKER_SVC}" \
  --force-new-deployment \
  --region "${AWS_REGION}" >/dev/null

echo ""
echo "======================================================================="
echo " StayHub Deployment Complete!"
echo "======================================================================="
echo " Application URL (Guest) : ${APP_URL}"
echo " Search Stays URL        : ${APP_URL}/search"
echo " Host Portal URL         : ${APP_URL}/host/listings"
echo "Host Today & Requests   : ${APP_URL}/host/today"
echo " Host Earnings URL       : ${APP_URL}/host/earnings"
echo " Admin Login URL         : ${APP_URL}/admin/login"
echo " System Health Status    : ${APP_URL}/system"
echo " API Healthz Endpoint    : ${APP_URL}/healthz"
echo " Event Log API Endpoint  : ${APP_URL}/api/v1/events"
echo "-----------------------------------------------------------------------"
echo " Seed Credentials (Password for all accounts: Password123!)"
echo "   Guest  : claire.dubois@stayhub.dev"
echo "   Guest 2: arjun.mehta@stayhub.dev"
echo "   Host   : ines.costa@stayhub.dev"
echo "   Host 2 : kenji.takahashi@stayhub.dev"
echo "   Admin  : admin@stayhub.dev"
echo "======================================================================="
