# =============================================================================
# OmniDomain — ECR Repository
# Stores the Docker image that runs Nextflow + pipeline scripts on AWS Batch
# =============================================================================

resource "aws_ecr_repository" "nextflow" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Lifecycle policy — keep only last 5 images to control storage costs
resource "aws_ecr_lifecycle_policy" "nextflow" {
  repository = aws_ecr_repository.nextflow.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}
