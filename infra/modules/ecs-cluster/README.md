# `ecs-cluster` Terraform Module

Provisions an Amazon ECS Cluster with Container Insights disabled (`setting { name = "containerInsights", value = "disabled" }`) to eliminate custom metric and log ingestion charges on the Free Plan credit budget (ADR 0005).

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
| `aws_ecs_cluster.this` | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Short lowercase project identifier used as a resource prefix. | `string` | n/a | yes |
| `environment` | Deployment environment name (dev or prod). | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | ID of the ECS cluster. |
| `cluster_arn` | ARN of the ECS cluster. |
| `cluster_name` | Name of the ECS cluster. |
<!-- END_TF_DOCS -->
