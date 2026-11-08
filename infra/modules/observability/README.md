# `observability` Terraform Module

Provisions a CloudWatch Log Group (`retention_in_days = 7` in `dev`), an encrypted SNS alert topic (`alias/aws/sns`) with optional email subscription, a structured JSON `{ $.level = "ERROR" }` metric filter, five CloudWatch metric alarms (`treat_missing_data = "notBreaching"`), and a CloudWatch operational dashboard.

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
| `aws_cloudwatch_log_group.ecs` | resource |
| `aws_sns_topic.alerts` | resource |
| `aws_sns_topic_subscription.email` | resource |
| `aws_cloudwatch_log_metric_filter.app_errors` | resource |
| `aws_cloudwatch_metric_alarm.alb_5xx` | resource |
| `aws_cloudwatch_metric_alarm.unhealthy_hosts` | resource |
| `aws_cloudwatch_metric_alarm.running_task_count` | resource |
| `aws_cloudwatch_metric_alarm.high_cpu` | resource |
| `aws_cloudwatch_metric_alarm.app_log_errors` | resource |
| `aws_cloudwatch_dashboard.this` | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Short lowercase project identifier used as a resource prefix. | `string` | n/a | yes |
| `environment` | Deployment environment name (dev or prod). | `string` | n/a | yes |
| `aws_region` | AWS region for CloudWatch Logs, alarms, and dashboards. | `string` | `"eu-north-1"` | no |
| `log_retention_days` | CloudWatch Logs retention period in days (7 in dev, 30 in prod). | `number` | `7` | no |
| `alert_email` | Email address subscribed to the SNS alarm notification topic (supplied via gitignored tfvars). | `string` | `""` | no |
| `cluster_name` | ECS cluster name for CloudWatch alarm and dashboard dimensions. | `string` | n/a | yes |
| `service_name` | ECS service name for CloudWatch alarm and dashboard dimensions. | `string` | n/a | yes |
| `alb_arn_suffix` | Application Load Balancer ARN suffix for CloudWatch metrics. | `string` | n/a | yes |
| `target_group_arn_suffix` | ALB target group ARN suffix for CloudWatch metrics. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| `log_group_name` | Name of the CloudWatch Logs group for ECS task logs. |
| `log_group_arn` | ARN of the CloudWatch Logs group. |
| `sns_topic_arn` | ARN of the SNS topic receiving CloudWatch alarm notifications. |
| `dashboard_name` | Name of the CloudWatch operational overview dashboard. |
| `alarm_names` | List of CloudWatch metric alarm names created for the service. |
<!-- END_TF_DOCS -->
