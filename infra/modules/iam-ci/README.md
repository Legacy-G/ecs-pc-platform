# `iam-ci` Terraform Module

Provisions the `damolak-jenkins-ci` IAM user and its `damolak-jenkins-ci-boundary` permissions boundary for local Jenkins deployments. Never creates an `aws_iam_access_key` resource in Terraform state.

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
| `aws_iam_policy.permissions_boundary` | resource |
| `aws_iam_user.jenkins_ci` | resource |
| `aws_iam_user_policy_attachment.jenkins_ci` | resource |
| `data.aws_caller_identity.current` | data source |
| `data.aws_iam_policy_document.ci_deploy` | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Short lowercase project identifier used as a resource prefix. | `string` | `"damolak"` | no |
| `aws_region` | Primary AWS region where CI/CD deployments are permitted. | `string` | `"eu-north-1"` | no |
| `tfstate_bucket_name` | Name of the S3 bucket storing Terraform remote state. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| `iam_user_name` | Name of the Jenkins CI IAM user (access keys are created out-of-band via CLI script). |
| `iam_user_arn` | ARN of the Jenkins CI IAM user. |
| `permissions_boundary_arn` | ARN of the IAM permissions boundary attached to the Jenkins CI user. |
<!-- END_TF_DOCS -->
