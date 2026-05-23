# =============================================================================
# OmniDomain — IAM Roles and Policies
# =============================================================================

# ── Batch Service Role ────────────────────────────────────────────────────────
# Allows AWS Batch to manage EC2 instances on your behalf

resource "aws_iam_role" "batch_service" {
  name = "omni-batch-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "batch.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_service" {
  role       = aws_iam_role.batch_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

# ── EC2 Instance Role ─────────────────────────────────────────────────────────
# Role assumed by EC2 instances in the Batch compute environment

resource "aws_iam_role" "batch_instance" {
  name = "omni-batch-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "batch_instance_ecs" {
  role       = aws_iam_role.batch_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# S3 access for Batch instances — read uploads, write results and work dir
resource "aws_iam_role_policy" "batch_instance_s3" {
  name = "omni-batch-s3-access"
  role = aws_iam_role.batch_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
          "s3:ListBucket", "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.compute.arn,
          "${aws_s3_bucket.compute.arn}/*",
          aws_s3_bucket.results.arn,
          "${aws_s3_bucket.results.arn}/*",
        ]
      },
      {
        # Allow Nextflow to submit child jobs back to Batch
        Effect = "Allow"
        Action = [
          "batch:SubmitJob", "batch:DescribeJobs",
          "batch:TerminateJob", "batch:ListJobs"
        ]
        Resource = "*"
      },
      {
        # Allow pulling images from ECR
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "batch_instance" {
  name = "omni-batch-instance-profile"
  role = aws_iam_role.batch_instance.name
}

# ── Job Execution Role ────────────────────────────────────────────────────────
# Role assumed by the Batch job container itself

resource "aws_iam_role" "batch_job" {
  name = "omni-batch-job-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "batch_job_s3" {
  name = "omni-batch-job-s3"
  role = aws_iam_role.batch_job.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject", "s3:PutObject", "s3:DeleteObject",
        "s3:ListBucket", "s3:GetBucketLocation"
      ]
      Resource = [
        aws_s3_bucket.compute.arn,
        "${aws_s3_bucket.compute.arn}/*",
        aws_s3_bucket.results.arn,
        "${aws_s3_bucket.results.arn}/*",
      ]
    }]
  })
}

# ── Streamlit App User ────────────────────────────────────────────────────────
# IAM user for the Streamlit app running locally or on EC2
# Least privilege — only what the UI needs

resource "aws_iam_user" "streamlit" {
  name = "omni-streamlit-app"
}

resource "aws_iam_user_policy" "streamlit" {
  name = "omni-streamlit-policy"
  user = aws_iam_user.streamlit.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Upload reads to compute bucket
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.compute.arn,
          "${aws_s3_bucket.compute.arn}/*"
        ]
      },
      {
        # Read results
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.results.arn,
          "${aws_s3_bucket.results.arn}/*"
        ]
      },
      {
        # Submit and monitor Batch jobs
        Effect = "Allow"
        Action = [
          "batch:SubmitJob", "batch:DescribeJobs",
          "batch:ListJobs", "batch:TerminateJob"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "streamlit" {
  user = aws_iam_user.streamlit.name
}
