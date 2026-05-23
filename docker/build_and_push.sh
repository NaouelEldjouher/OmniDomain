#!/bin/bash
# =============================================================================
# Build and push the Nextflow runner image to ECR
# Usage: bash docker/build_and_push.sh <ECR_URL>
# Get ECR_URL from: terraform output ecr_repository_url
# =============================================================================

set -eo pipefail

ECR_URL=${1:-$(cd terraform && terraform output -raw ecr_repository_url)}
REGION=${AWS_REGION:-eu-central-1}
TAG="latest"

echo "Building omni-nextflow:${TAG}..."
docker build -t omni-nextflow:${TAG} docker/

echo "Authenticating with ECR..."
aws ecr get-login-password --region ${REGION} | \
    docker login --username AWS --password-stdin ${ECR_URL}

echo "Tagging and pushing..."
docker tag omni-nextflow:${TAG} ${ECR_URL}:${TAG}
docker push ${ECR_URL}:${TAG}

echo "✅ Image pushed to ${ECR_URL}:${TAG}"
echo "Update your Batch job definition to use this image."
