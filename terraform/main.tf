# =============================================================================
# OmniDomain — Terraform Root
# Multi-kingdom genomics platform — AWS Batch + S3 + EFS + ECR
# Author: Naouel El Djouher
# =============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — store in S3 so teammates can share state
  # Create this bucket manually before running terraform init:
  #   aws s3 mb s3://omni-terraform-state --region eu-central-1
  backend "s3" {
    bucket = "omni-terraform-state"
    key    = "omniodomain/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "OmniDomain"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "Naouel El Djouher"
    }
  }
}

# =============================================================================
# Data sources — reference existing AWS resources
# =============================================================================

# Default VPC — no custom VPC needed for a personal project
data "aws_vpc" "default" {
  default = true
}

# Default subnets — Batch compute nodes launch here
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Current AWS account ID — used in IAM policies
data "aws_caller_identity" "current" {}

# Current region
data "aws_region" "current" {}
