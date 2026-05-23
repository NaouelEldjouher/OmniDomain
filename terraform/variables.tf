# =============================================================================
# OmniDomain — Input Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

# ── S3 ────────────────────────────────────────────────────────────────────────

variable "compute_bucket" {
  description = "S3 bucket for raw reads and Nextflow work directory"
  type        = string
  default     = "omni-compute"
}

variable "results_bucket" {
  description = "S3 bucket for pipeline outputs"
  type        = string
  default     = "omni-results"
}

# ── AWS Batch ─────────────────────────────────────────────────────────────────

variable "batch_min_vcpus" {
  description = "Minimum vCPUs in Batch compute environment (0 = scale to zero when idle)"
  type        = number
  default     = 0
}

variable "batch_max_vcpus" {
  description = "Maximum vCPUs in Batch compute environment"
  type        = number
  default     = 256
}

variable "batch_instance_types" {
  description = "EC2 instance types for Batch — mix for Spot availability"
  type        = list(string)
  default = [
    "c5.2xlarge", # 8 vCPU  16GB  — QC, light assembly
    "c5.4xlarge", # 16 vCPU 32GB  — SPAdes, Flye assembly
    "m5.4xlarge", # 16 vCPU 64GB  — annotation (Funannotate, BRAKER3)
    "r5.4xlarge", # 16 vCPU 128GB — eggNOG, Helixer (memory-intensive)
  ]
}

# ── EFS ───────────────────────────────────────────────────────────────────────

variable "efs_mount_point" {
  description = "Mount point for tool databases inside Batch containers"
  type        = string
  default     = "/mnt/databases"
}

# ── ECR ───────────────────────────────────────────────────────────────────────

variable "ecr_repo_name" {
  description = "ECR repository name for the Nextflow runner image"
  type        = string
  default     = "omni-nextflow"
}

variable "nextflow_image_tag" {
  description = "Docker image tag for the Nextflow runner"
  type        = string
  default     = "latest"
}
