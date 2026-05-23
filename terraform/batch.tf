# =============================================================================
# OmniDomain — AWS Batch
# Compute environment, job queue, and job definition for Nextflow pipelines
# =============================================================================

# ── Security Group for Batch compute nodes ────────────────────────────────────
resource "aws_security_group" "batch" {
  name        = "omni-batch-sg"
  description = "Security group for Batch compute nodes"
  vpc_id      = data.aws_vpc.default.id

  # Outbound — allow all (Docker pulls, S3, EFS)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "omni-batch-sg" }
}

# ── Compute Environment — Spot instances ──────────────────────────────────────
# Scales from 0 to max_vcpus automatically
# Uses Spot for 60-80% cost savings — Nextflow -resume handles interruptions

resource "aws_batch_compute_environment" "spot" {
  compute_environment_name = "omni-spot"
  type                     = "MANAGED"
  service_role             = aws_iam_role.batch_service.arn

  compute_resources {
    type                = "SPOT"
    bid_percentage      = 60 # Max 60% of On-Demand price
    spot_iam_fleet_role = aws_iam_role.spot_fleet.arn

    min_vcpus     = var.batch_min_vcpus
    max_vcpus     = var.batch_max_vcpus
    desired_vcpus = 0

    instance_type = var.batch_instance_types

    instance_role = aws_iam_instance_profile.batch_instance.arn

    subnets            = data.aws_subnets.default.ids
    security_group_ids = [aws_security_group.batch.id]

    # EFS mount for tool databases
    launch_template {
      launch_template_id = aws_launch_template.batch.id
      version            = "$Latest"
    }
  }

  depends_on = [aws_iam_role_policy_attachment.batch_service]
}

# ── Spot Fleet Role ───────────────────────────────────────────────────────────
resource "aws_iam_role" "spot_fleet" {
  name = "omni-spot-fleet-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "spotfleet.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "spot_fleet" {
  role       = aws_iam_role.spot_fleet.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

# ── Launch Template — mounts EFS at boot ─────────────────────────────────────
resource "aws_launch_template" "batch" {
  name_prefix = "omni-batch-"

  user_data = base64encode(<<-USERDATA
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==BOUNDARY=="

    --==BOUNDARY==
    Content-Type: text/cloud-boothook; charset="us-ascii"

    #!/bin/bash
    # Mount EFS for tool databases
    yum install -y amazon-efs-utils
    mkdir -p ${var.efs_mount_point}
    mount -t efs -o tls ${aws_efs_file_system.databases.id}:/ ${var.efs_mount_point}
    echo "${aws_efs_file_system.databases.id}:/ ${var.efs_mount_point} efs tls,_netdev 0 0" >> /etc/fstab

    --==BOUNDARY==--
  USERDATA
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "omni-batch-node" }
  }
}

# ── Job Queue ─────────────────────────────────────────────────────────────────
resource "aws_batch_job_queue" "main" {
  name     = "omni-batch-queue"
  state    = "ENABLED"
  priority = 1

  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.spot.arn
  }
}

# ── Job Definition — Nextflow runner ─────────────────────────────────────────
# This is the container that runs `nextflow run ...`
# The Nextflow head job then submits child jobs back to the same queue

resource "aws_batch_job_definition" "nextflow" {
  name = "omni-nextflow-job"
  type = "container"

  container_properties = jsonencode({
    image      = "${aws_ecr_repository.nextflow.repository_url}:${var.nextflow_image_tag}"
    jobRoleArn = aws_iam_role.batch_job.arn

    resourceRequirements = [
      { type = "VCPU", value = "4" },
      { type = "MEMORY", value = "8192" }
    ]

    # EFS database mount inside the container
    mountPoints = [{
      containerPath = var.efs_mount_point
      readOnly      = true
      sourceVolume  = "databases"
    }]

    volumes = [{
      name = "databases"
      efsVolumeConfiguration = {
        fileSystemId      = aws_efs_file_system.databases.id
        rootDirectory     = "/databases"
        transitEncryption = "ENABLED"
        authorizationConfig = {
          accessPointId = aws_efs_access_point.databases.id
          iam           = "ENABLED"
        }
      }
    }]

    environment = [
      { name = "NXF_WORK", value = "s3://${var.compute_bucket}/work" },
      { name = "NXF_OPTS", value = "-Xms2g -Xmx6g" },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "OMNI_BASE_OUTDIR", value = "s3://${var.results_bucket}" },

      # Database paths — match EFS mount point
      { name = "OMNI_EGGNOG_DB", value = "${var.efs_mount_point}/eggnog" },
      { name = "OMNI_DBCAN_DB", value = "${var.efs_mount_point}/dbcan" },
      { name = "OMNI_FUNANNOTATE_DB", value = "${var.efs_mount_point}/funannotate" },
      { name = "OMNI_HELIXER_MODEL", value = "${var.efs_mount_point}/helixer" },
      { name = "OMNI_BUSCO_DB", value = "${var.efs_mount_point}/busco" },
      { name = "OMNI_NLR_JAR", value = "${var.efs_mount_point}/nlr/NLR-Annotator-v2.1b.jar" },
      { name = "OMNI_NLR_MOT", value = "${var.efs_mount_point}/nlr/mot.txt" },
      { name = "OMNI_NLR_STORE", value = "${var.efs_mount_point}/nlr/store.txt" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/aws/batch/omniodomain"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "nextflow"
      }
    }
  })

  retry_strategy {
    attempts = 3 # Retry on Spot interruption
  }

  timeout {
    attempt_duration_seconds = 86400 # 24h max per job
  }
}

# ── CloudWatch Log Group ──────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "batch" {
  name              = "/aws/batch/omniodomain"
  retention_in_days = 30
}
