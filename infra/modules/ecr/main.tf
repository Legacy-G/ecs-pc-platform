# trivy:ignore:AVD-AWS-0033 AES256 SSE-S3 encryption is used instead of a paid customer-managed KMS key to preserve the USD 40 credit budget.
resource "aws_ecr_repository" "this" {
  # checkov:skip=CKV_AWS_136:AES256 encryption is used instead of a paid customer-managed KMS key ($1/month) to stay within the Free Plan budget.
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = var.repository_name
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${var.untagged_retention_days} day(s)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.untagged_retention_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain only the last ${var.max_tagged_image_count} tagged images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_tagged_image_count
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
