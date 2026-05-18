provider "aws" { region = var.region }
resource "random_id" "suffix" {
  byte_length = 4
}
# ==========================================
# 1. STORAGE (S3) - TWO-TIER ARCHITECTURE
# ==========================================

# --- A. PERSISTENT BUCKET (Genomic Databases) ---
resource "aws_s3_bucket" "amr_static_assets" {
  bucket        = "${var.bucket_name}-static"
  
 
  lifecycle {
    prevent_destroy = true
  }
}

# --- B. EPHEMERAL BUCKET (Nextflow Work & Results) ---
resource "aws_s3_bucket" "amr_compute_storage" {
  bucket        = "${var.bucket_name}-compute"
  force_destroy = true # Allows easy cleanup of temporary data
}

# --- PRIVACY BLOCKS (Repeat for both buckets) ---
resource "aws_s3_bucket_public_access_block" "static_privacy" {
  bucket                  = aws_s3_bucket.amr_static_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "compute_privacy" {
  bucket                  = aws_s3_bucket.amr_compute_storage.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# This deletes any intermediate "work" files older than 7 days 
resource "aws_s3_bucket_lifecycle_configuration" "compute_cleanup" {
  bucket = aws_s3_bucket.amr_compute_storage.id

  rule {
    id     = "auto-delete-old-work"
    status = "Enabled"
    expiration {
      days = 7
    }
  }
}
# ==========================================
# 2. NETWORKING
# ==========================================
resource "aws_security_group" "amr_sg" {
  name   = "amr-flow-sg-${random_id.suffix.hex}"
  vpc_id = var.vpc_id

  # Allowing all outbound traffic so Fargate can talk to S3 and Docker Hub
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {
    create_before_destroy = true
  }
}
# ==========================================
# 3. IAM ROLES (Permissions)
# ==========================================
resource "aws_iam_role" "amr_job_role" {
  name = "AMR-Flow-Job-Role-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { 
        Service = [
          "ecs-tasks.amazonaws.com",
          "batch.amazonaws.com"
        ]
      }
    }]
  })

}
resource "aws_iam_role_policy" "amr_s3_explicit_access" {
  name = "AMR-Flow-S3-Explicit-Access"
  role = aws_iam_role.amr_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketLocation"
        ]
        # This covers BOTH your -static and -compute buckets
        Resource = [
          "arn:aws:s3:::${var.bucket_name}-*",
          "arn:aws:s3:::${var.bucket_name}-*/*"
        ]
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.amr_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.amr_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
# Role for the actual EC2 instances (Required for EC2 Batch workers)
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile-${random_id.suffix.hex}"
  role = aws_iam_role.ecs_instance_role.name
}
# ==========================================
# 4. ENVIRONMENT A: FARGATE SPOT (Lightweight)
# ==========================================
resource "aws_batch_compute_environment" "amr_compute" {
  name = "amr-flow-fargate-${random_id.suffix.hex}"
  type = "MANAGED"
  compute_resources {
    type = "FARGATE_SPOT"
    max_vcpus = 64
    subnets = var.subnet_ids
    security_group_ids = [aws_security_group.amr_sg.id]
  }
  lifecycle { create_before_destroy = true }
}
resource "aws_batch_job_queue" "amr_queue" {
  name     = "nextflow-fargate-queue-${random_id.suffix.hex}"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.amr_compute.arn
  }
} 
# ==========================================
# 5. ENVIRONMENT B: EC2 SPOT (Heavyweight / 200GB)
# ==========================================
resource "aws_iam_role" "spot_fleet_role" {
  name = "AmazonEC2SpotFleetRole-${random_id.suffix.hex}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "spotfleet.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "spot_fleet_role_attachment" {
  role       = aws_iam_role.spot_fleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}
resource "aws_launch_template" "amr_large_disk" {
  name = "amr-large-disk-${random_id.suffix.hex}"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 200
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
}
resource "aws_batch_compute_environment" "amr_ec2_compute" {
  name = "amr-flow-ec2-spot-${random_id.suffix.hex}"
  type = "MANAGED"
  compute_resources {
    type          = "SPOT"
    max_vcpus     = 64
    min_vcpus     = 0
    instance_type = ["optimal"] 
    instance_role = aws_iam_instance_profile.ecs_instance_profile.arn
    spot_iam_fleet_role = aws_iam_role.spot_fleet_role.arn
    
    subnets            = var.subnet_ids
    security_group_ids = [aws_security_group.amr_sg.id]
    
    launch_template {
      launch_template_id = aws_launch_template.amr_large_disk.id
      version            = "$Latest"
    }
  }
  depends_on = [aws_iam_role_policy_attachment.spot_fleet_role_attachment]
  lifecycle { create_before_destroy = true }
}
resource "aws_batch_job_queue" "amr_ec2_queue" {
  name     = "nextflow-ec2-queue-${random_id.suffix.hex}"
  state    = "ENABLED"
  priority = 1
  compute_environment_order {
    order               = 1
    compute_environment = aws_batch_compute_environment.amr_ec2_compute.arn
  }
}

resource "aws_iam_role_policy_attachment" "fargate_execution" {
  role       = aws_iam_role.amr_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ==========================================
# 6. OUTPUTS & ENV FILE GENERATION
# ==========================================
output "static_bucket_name" {
  value = aws_s3_bucket.amr_static_assets.bucket
}

output "batch_job_queue_arn" {
  value = aws_batch_job_queue.amr_queue.arn
}
output "fargate_queue_arn" { 
  value = aws_batch_job_queue.amr_queue.arn 
}

output "ec2_queue_arn" { 
  value = aws_batch_job_queue.amr_ec2_queue.arn 
}
resource "local_file" "streamlit_env" {
  filename = var.env_file_path
  content  = <<-EOT
AMR_STATIC_BUCKET="${aws_s3_bucket.amr_static_assets.bucket}"
AMR_COMPUTE_BUCKET="${aws_s3_bucket.amr_compute_storage.bucket}"
AMR_BATCH_QUEUE="${aws_batch_job_queue.amr_queue.arn}"
AMR_EC2_QUEUE="${aws_batch_job_queue.amr_ec2_queue.arn}"
AMR_JOB_ROLE_ARN="${aws_iam_role.amr_job_role.arn}"
AMR_SUBNETS="${join(",", var.subnet_ids)}"
AMR_SECURITY_GROUPS="${aws_security_group.amr_sg.id}"
AWS_DEFAULT_REGION="${trimspace(var.region)}"
EOT
}
