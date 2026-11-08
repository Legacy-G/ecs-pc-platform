# `ecr` Terraform Module

Provisions an Amazon ECR repository with immutable image tags, scan-on-push enabled, AES256 encryption at rest, `force_delete = true`, and a lifecycle policy expiring untagged images after 1 day and retaining the last 10 tagged images.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.17.0, < 2.0.0 |
| aws | = 6.72.0 |

## Providers

| Name | Version |
|------|---------|
| aws | = 6.72.0 |

## Resources

| Name | Type |
|------|------|
| `aws_ecr_repository.this` | resource |
| `aws_ecr_lifecycle_policy.this` | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `repository_name` | Name of the ECR repository. | `string` | n/a | yes |
| `force_delete` | Whether to allow deleting the ECR repository even when it contains images. | `bool` | `true` | no |
| `max_tagged_image_count` | Number of most-recent tagged images retained by the lifecycle policy. | `number` | `10` | no |
| `untagged_retention_days` | Number of days before untagged images expire. | `number` | `1` | no |

## Outputs

| Name | Description |
|------|-------------|
| `repository_arn` | ARN of the ECR repository. |
| `repository_url` | Full registry/repository URL for docker push and pull. |
| `repository_name` | Name of the ECR repository. |
<!-- END_TF_DOCS -->
