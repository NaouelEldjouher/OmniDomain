#!/bin/bash
# =============================================================================
# OmniDomain — AWS Batch Setup Script
# Run this ONCE after terraform apply to:
#   1. Build and push the Nextflow runner image to ECR
#   2. Mount EFS and populate tool databases
#   3. Verify the setup
#
# Prerequisites:
#   - AWS CLI configured (aws configure)
#   - Docker running
#   - terraform apply completed
#   - .env file generated (terraform output -raw env_template > .env)
#
# Usage:
#   bash bin/setup_aws_batch.sh
#   bash bin/setup_aws_batch.sh --skip-databases  # skip if databases already loaded
# =============================================================================

set -eo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env
if [ -f "${REPO_ROOT}/.env" ]; then
    export $(grep -v '^#' "${REPO_ROOT}/.env" | xargs)
else
    echo "ERROR: .env file not found. Run: terraform output -raw env_template > .env"
    exit 1
fi

SKIP_DATABASES=false
[ "$1" == "--skip-databases" ] && SKIP_DATABASES=true

log()  { echo "[$(date '+%H:%M:%S')] $1"; }
error(){ echo "[ERROR] $1"; exit 1; }

# =============================================================================
# Step 1 — Get Terraform outputs
# =============================================================================
log "Reading Terraform outputs..."
cd "${REPO_ROOT}/terraform"

ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null) \
    || error "terraform output failed — run terraform apply first"
EFS_ID=$(terraform output -raw efs_id 2>/dev/null)
EFS_DNS=$(terraform output -raw efs_dns 2>/dev/null)
BATCH_QUEUE=$(terraform output -raw batch_job_queue 2>/dev/null)

log "ECR: ${ECR_URL}"
log "EFS: ${EFS_ID} (${EFS_DNS})"
log "Batch Queue: ${BATCH_QUEUE}"

cd "${REPO_ROOT}"

# =============================================================================
# Step 2 — Build and push Docker image to ECR
# =============================================================================
log "Building Nextflow runner image..."

docker build -t omni-nextflow:latest docker/

log "Authenticating with ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | \
    docker login --username AWS --password-stdin "${ECR_URL}"

log "Pushing image to ECR..."
docker tag omni-nextflow:latest "${ECR_URL}:latest"
docker push "${ECR_URL}:latest"

log "✅ Image pushed to ECR"

# =============================================================================
# Step 3 — Mount EFS and populate tool databases
# =============================================================================
if [ "$SKIP_DATABASES" = true ]; then
    log "Skipping database setup (--skip-databases)"
else
    log "Mounting EFS for database population..."

    # Create a temporary EC2 instance to mount EFS and run database downloads
    # This is the recommended approach — EFS can't be mounted from WSL directly

    log "Launching temporary EC2 instance to populate EFS..."

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id ami-0faab6bdbac9486fb \
        --instance-type t3.medium \
        --key-name omni-keypair \
        --security-groups omni-batch-sg \
        --user-data "$(cat << 'USERDATA'
#!/bin/bash
yum install -y amazon-efs-utils
mkdir -p /mnt/databases
mount -t efs -o tls ${EFS_ID}:/ /mnt/databases

# Download tool databases
mkdir -p /mnt/databases/{eggnog,busco,helixer,nlr,dbcan,checkm2,funannotate}

# NLR-Annotator (2MB — fast)
wget -q https://github.com/steuernb/NLR-Annotator/raw/master/NLR-Annotator-v2.1b.jar \
    -O /mnt/databases/nlr/NLR-Annotator-v2.1b.jar
wget -q https://github.com/steuernb/NLR-Annotator/raw/master/src/mot.txt \
    -O /mnt/databases/nlr/mot.txt
wget -q https://github.com/steuernb/NLR-Annotator/raw/master/src/store.txt \
    -O /mnt/databases/nlr/store.txt

echo "NLR done" > /tmp/nlr.done
USERDATA
)" \
        --query 'Instances[0].InstanceId' \
        --output text 2>/dev/null) || {
        log "⚠️  Could not launch EC2 — populate EFS manually"
        log "Mount EFS ${EFS_DNS} to an EC2 in the same VPC"
        log "Then run: bash bin/setup_fungalflow.sh && bash bin/setup_phytoflow.sh"
    }

    if [ -n "$INSTANCE_ID" ]; then
        log "EC2 instance ${INSTANCE_ID} launched — databases downloading to EFS"
        log "Monitor: aws ec2 describe-instance-status --instance-ids ${INSTANCE_ID}"
        log "Terminate when done: aws ec2 terminate-instances --instance-ids ${INSTANCE_ID}"
    fi
fi

# =============================================================================
# Step 4 — Verify Batch setup
# =============================================================================
log "Verifying AWS Batch..."

QUEUE_STATE=$(aws batch describe-job-queues \
    --job-queues omni-batch-queue \
    --query 'jobQueues[0].state' \
    --output text 2>/dev/null) || QUEUE_STATE="UNKNOWN"

log "Job queue state: ${QUEUE_STATE}"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "══════════════════════════════════════════════════════"
echo " OmniDomain — AWS Batch Setup Complete"
echo "══════════════════════════════════════════════════════"
echo " ECR image:   ${ECR_URL}:latest ✅"
echo " EFS:         ${EFS_ID} ✅"
echo " Batch queue: ${QUEUE_STATE}"
echo ""
echo " Next steps:"
echo "  1. Populate EFS databases (if not done)"
echo "  2. streamlit run ui/app.py"
echo "  3. Submit a test job via the UI"
echo "══════════════════════════════════════════════════════"
