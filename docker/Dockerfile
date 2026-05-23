# =============================================================================
# OmniDomain — Nextflow Runner Image
# This image runs on AWS Batch — it executes Nextflow which then submits
# each pipeline process as a child Batch job using tool-specific containers
#
# Build:  docker build -t omni-nextflow:latest docker/
# Push:   docker tag omni-nextflow:latest <ECR_URL>:latest
#         docker push <ECR_URL>:latest
# =============================================================================

FROM amazoncorretto:17-alpine

# ── System dependencies ───────────────────────────────────────────────────────
RUN apk add --no-cache \
    bash \
    curl \
    wget \
    git \
    python3 \
    py3-pip \
    aws-cli \
    && rm -rf /var/cache/apk/*

# ── Nextflow ──────────────────────────────────────────────────────────────────
ENV NXF_VER=25.10.4
RUN curl -fsSL https://get.nextflow.io | bash \
    && mv nextflow /usr/local/bin/ \
    && chmod +x /usr/local/bin/nextflow \
    && nextflow -version

# ── OmniDomain pipeline code ──────────────────────────────────────────────────
WORKDIR /opt/omniodomain
COPY nextflow/ ./nextflow/

# ── Nextflow config ───────────────────────────────────────────────────────────
ENV NXF_HOME=/opt/nextflow
ENV NXF_WORK=s3://omni-compute/work
ENV NXF_OPTS="-Xms2g -Xmx6g"

# ── Entrypoint ────────────────────────────────────────────────────────────────
# AWS Batch passes the nextflow run command as container override
ENTRYPOINT ["bash", "-c"]
CMD ["nextflow -version"]
