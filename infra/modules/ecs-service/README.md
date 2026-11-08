# `ecs-service` Terraform Module

Provisions an Application Load Balancer (`drop_invalid_header_fields = true`), target group (`/api/v1/health/`), security groups (ALB TCP/80 ingress -> task TCP/8000; task egress restricted to TCP/443), ECS cluster with Container Insights, least-privilege execution/task IAM roles, Fargate task definition, ECS service with deployment circuit breaker + rollback and `wait_for_steady_state = true`, and CPU TargetTracking Application Auto Scaling (`min = 1`, `max = 2`).

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
| `aws_security_group.alb` | resource |
| `aws_vpc_security_group_ingress_rule.alb_http_in` | resource |
| `aws_vpc_security_group_egress_rule.alb_to_task` | resource |
| `aws_security_group.task` | resource |
| `aws_vpc_security_group_ingress_rule.task_from_alb` | resource |
| `aws_vpc_security_group_egress_rule.task_https_out` | resource |
| `aws_lb.this` | resource |
| `aws_lb_target_group.this` | resource |
| `aws_lb_listener.http` | resource |
| `aws_ecs_cluster.this` | resource |
| `aws_iam_role.execution` | resource |
| `aws_iam_role_policy_attachment.execution_managed` | resource |
| `aws_iam_role_policy.execution_ssm` | resource |
| `aws_iam_role.task` | resource |
| `aws_ecs_task_definition.this` | resource |
| `aws_ecs_service.this` | resource |
| `aws_appautoscaling_target.ecs` | resource |
| `aws_appautoscaling_policy.cpu` | resource |
| `data.aws_caller_identity.current` | data source |
| `data.aws_iam_policy_document.ecs_task_assume_role` | data source |
| `data.aws_iam_policy_document.execution_ssm` | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Short lowercase project identifier used as a resource prefix. | `string` | n/a | yes |
| `environment` | Deployment environment name (dev or prod). | `string` | n/a | yes |
| `aws_region` | AWS region where the ECS service and ALB are deployed. | `string` | `"eu-north-1"` | no |
| `vpc_id` | ID of the VPC hosting the ALB and ECS service. | `string` | n/a | yes |
| `vpc_cidr` | IPv4 CIDR block of the VPC, passed to uvicorn --forwarded-allow-ips. | `string` | n/a | yes |
| `public_subnet_ids` | List of public subnet IDs across at least two Availability Zones for the ALB. | `list(string)` | n/a | yes |
| `service_subnet_ids` | List of subnet IDs across at least two Availability Zones for ECS Fargate tasks. | `list(string)` | n/a | yes |
| `assign_public_ip` | Whether to assign a public IPv4 address to task ENIs (true in NAT-less dev, false in private prod subnets). | `bool` | `true` | no |
| `container_image` | Full container image URI (immutable tag or digest) to deploy. | `string` | n/a | yes |
| `app_version` | Semantic version string exposed by the application telemetry endpoints. | `string` | `"0.1.0"` | no |
| `git_sha` | Git commit SHA exposed by the application telemetry endpoints. | `string` | `"initial"` | no |
| `container_port` | TCP port on which the application container listens. | `number` | `8000` | no |
| `cpu` | Fargate task CPU units (256 = 0.25 vCPU). | `number` | `256` | no |
| `memory` | Fargate task memory in MiB. | `number` | `512` | no |
| `desired_count` | Initial desired number of running Fargate tasks. | `number` | `1` | no |
| `min_capacity` | Minimum number of running tasks maintained by Application Auto Scaling. | `number` | `1` | no |
| `max_capacity` | Maximum number of running tasks permitted by Application Auto Scaling. | `number` | `2` | no |
| `cpu_target_value` | Target average CPU utilization percentage for Application Auto Scaling. | `number` | `70` | no |
| `health_check_path` | HTTP path probed by the ALB target group and container health check. | `string` | `"/api/v1/health/"` | no |
| `log_group_name` | Name of the CloudWatch Logs group receiving container stdout/stderr. | `string` | n/a | yes |
| `ssm_api_key_parameter_name` | SSM Parameter Store path holding the SecureString X-API-Key secret. | `string` | n/a | yes |
| `enable_deletion_protection` | Whether to enable deletion protection on the Application Load Balancer. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | ARN/ID of the ECS cluster. |
| `cluster_name` | Name of the ECS cluster. |
| `cluster_arn` | ARN of the ECS cluster. |
| `service_id` | ID of the ECS service. |
| `service_name` | Name of the ECS service. |
| `task_definition_arn` | Full ARN of the registered ECS task definition revision. |
| `task_execution_role_arn` | ARN of the ECS task execution IAM role. |
| `task_role_arn` | ARN of the ECS task runtime IAM role. |
| `alb_arn` | ARN of the Application Load Balancer. |
| `alb_arn_suffix` | ARN suffix of the ALB for CloudWatch metric dimensions. |
| `alb_dns_name` | Public DNS name of the Application Load Balancer. |
| `alb_zone_id` | Canonical hosted zone ID of the Application Load Balancer. |
| `alb_security_group_id` | Security group ID attached to the Application Load Balancer. |
| `target_group_arn` | ARN of the ALB target group. |
| `target_group_arn_suffix` | ARN suffix of the ALB target group for CloudWatch metric dimensions. |
| `task_security_group_id` | Security group ID attached to ECS Fargate tasks. |
| `service_url` | Base HTTP URL for reaching the service via the Application Load Balancer. |
<!-- END_TF_DOCS -->
