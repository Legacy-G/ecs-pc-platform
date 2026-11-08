data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

# trivy:ignore:AVD-AWS-0089 Access logging on the state bucket is omitted in dev to avoid extra S3 log-bucket storage charges.
# trivy:ignore:AVD-AWS-0132 SSE-S3 (AES256) encryption is used instead of a paid customer-managed KMS key ($1/month) to stay within the USD 40 credit budget.
resource "aws_s3_bucket" "tfstate" {
  # checkov:skip=CKV_AWS_18:S3 access logging is omitted for the single-operator challenge state bucket.
  # checkov:skip=CKV_AWS_144:Cross-region replication is unnecessary for a single-region challenge deployment and adds data transfer cost.
  # checkov:skip=CKV_AWS_145:SSE-S3 (AES256) is used instead of a paid customer-managed KMS key ($1/month).
  # checkov:skip=CKV2_AWS_62:S3 event notifications are not required for Terraform state storage.
  bucket        = local.bucket_name
  force_destroy = false

  tags = {
    Name = local.bucket_name
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# trivy:ignore:AVD-AWS-0132 SSE-S3 (AES256) is used instead of a paid customer-managed KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

data "aws_iam_policy_document" "enforce_tls" {
  statement {
    sid       = "DenyNonTlsRequests"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.tfstate.arn, "${aws_s3_bucket.tfstate.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tfstate" {
  bucket     = aws_s3_bucket.tfstate.id
  policy     = data.aws_iam_policy_document.enforce_tls.json
  depends_on = [aws_s3_bucket_public_access_block.tfstate]
}
