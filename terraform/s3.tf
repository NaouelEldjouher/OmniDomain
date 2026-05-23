# =============================================================================
# OmniDomain — S3 Buckets
# Two buckets: compute (inputs + work) and results (outputs)
# =============================================================================

# ── Compute bucket — raw reads + Nextflow work directory ─────────────────────
resource "aws_s3_bucket" "compute" {
  bucket        = var.compute_bucket
  force_destroy = true # Allow terraform destroy to delete non-empty bucket

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "compute" {
  bucket = aws_s3_bucket.compute.id
  versioning_configuration {
    status = "Disabled" # No versioning — reads are immutable
  }
}

# Lifecycle rule — delete Nextflow work files after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "compute" {
  bucket = aws_s3_bucket.compute.id

  rule {
    id     = "cleanup-work-dir"
    status = "Enabled"

    filter {
      prefix = "work/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "cleanup-uploads"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "compute" {
  bucket = aws_s3_bucket.compute.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "compute" {
  bucket                  = aws_s3_bucket.compute.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── Results bucket — pipeline outputs ────────────────────────────────────────
resource "aws_s3_bucket" "results" {
  bucket        = var.results_bucket
  force_destroy = false # Protect results from accidental deletion
}

resource "aws_s3_bucket_versioning" "results" {
  bucket = aws_s3_bucket.results.id
  versioning_configuration {
    status = "Enabled" # Version results — protect against accidental overwrites
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "results" {
  bucket = aws_s3_bucket.results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "results" {
  bucket                  = aws_s3_bucket.results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
