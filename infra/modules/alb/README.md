# `alb` Terraform Module

Provisions an Application Load Balancer (`drop_invalid_header_fields = true`), an ALB security group accepting public HTTP (TCP 80), and an HTTP listener whose default action returns a fixed `404 Not Found`.

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
| `aws_vpc_security_group_ingress_rule.http_in` | resource |
| `aws_lb.this` | resource |
| `aws_lb_listener.http` | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Short lowercase project identifier used as a resource prefix. | `string` | n/a | yes |
| `environment` | Deployment environment name (dev or prod). | `string` | n/a | yes |
| `vpc_id` | ID of the VPC hosting the Application Load Balancer. | `string` | n/a | yes |
| `public_subnet_ids` | Public subnet IDs in at least two Availability Zones for the load balancer. | `list(string)` | n/a | yes |
| `enable_deletion_protection` | Whether to enable deletion protection on the load balancer. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `listener_arn` | ARN of the HTTP listener that services attach listener rules to. |
| `security_group_id` | Security group ID of the load balancer. Services add an egress rule to their task port. |
| `dns_name` | Public DNS name of the load balancer. |
| `arn` | ARN of the load balancer. |
| `arn_suffix` | ARN suffix of the load balancer for CloudWatch metric dimensions. |
| `zone_id` | Canonical hosted zone ID of the load balancer. |
<!-- END_TF_DOCS -->
