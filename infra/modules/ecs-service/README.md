# `ecs-service` Terraform Module

Provisions an Amazon ECS Fargate service behind a shared Application Load Balancer listener rule, target group (`/api/v1/health/`), security groups (ALB to task egress rule and task ingress rule; task egress restricted to TCP 443), least-privilege execution/task IAM roles, Fargate task definition (`readonlyRootFilesystem = true`), and CPU TargetTracking Application Auto Scaling (`min = 1`, `max = 2`).

A second service can be deployed to the same ALB by instantiating this module with a unique `service_name`, `listener_rule_priority`, and `path_patterns`.

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
| `aws_security_group.task` | resource |
| `aws_vpc_security_group_ingress_rule.task_from_alb` | resource |
| `aws_vpc_security_group_egress_rule.alb_to_task` | resource |
| `aws_vpc_security_group_egress_rule.task_https_out` | resource |
| `aws_lb_target_group.this` | resource |
| `aws_lb_listener_rule.this` | resource |
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
| `service_name` | Short name of this service (for example api). Used in resource names and as the container name. | `string` | `"api"` | no |
| `aws_region` | AWS region where the ECS service is deployed. | `string` | `"eu-north-1"` | no |
| `vpc_id` | ID of the VPC hosting the ECS service. | `string` | n/a | yes |
| `vpc_cidr` | IPv4 CIDR block of the VPC, passed to uvicorn --forwarded-allow-ips. | `string` | n/a | yes |
| `service_subnet_ids` | List of subnet IDs across at least two Availability Zones for ECS Fargate tasks. | `list(string)` | n/a | yes |
| `assign_public_ip` | Whether to assign a public IPv4 address to task ENIs (true in NAT-less dev, false in private prod subnets). | `bool` | `true` | no |
| `cluster_name` | Name of the ECS cluster that runs the service (from the ecs-cluster module). | `string` | n/a | yes |
| `listener_arn` | ARN of the ALB listener that receives this service's listener rule (from the alb module). | `string` | n/a | yes |
| `alb_security_group_id` | Security group ID of the ALB (from the alb module). The service adds its own egress rule to it. | `string` | n/a | yes |
| `listener_rule_priority` | Priority of the listener rule. Each service on the same listener needs a unique value. | `number` | n/a | yes |
| `path_patterns` | Request path patterns routed to this service, for example ["/*"] or ["/orders/*"]. | `list(string)` | n/a | yes |
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

## Outputs

| Name | Description |
|------|-------------|
| `service_id` | ID of the ECS service. |
| `service_name` | Name of the ECS service. |
| `task_definition_arn` | Full ARN of the registered ECS task definition revision. |
| `task_execution_role_arn` | ARN of the ECS task execution IAM role. |
| `task_role_arn` | ARN of the ECS task runtime IAM role. |
| `target_group_arn` | ARN of the ALB target group. |
| `target_group_arn_suffix` | ARN suffix of the ALB target group for CloudWatch metric dimensions. |
| `task_security_group_id` | Security group ID attached to ECS Fargate tasks. |
| `ssm_api_key_parameter_arn` | Constructed ARN of the SSM parameter the execution role may read. |
<!-- END_TF_DOCS -->
