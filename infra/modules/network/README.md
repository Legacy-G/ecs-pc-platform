# `network` Terraform Module

Provisions a two-AZ VPC in `eu-north-1` with public and private subnets, an Internet Gateway, a restricted default security group, and an optional NAT Gateway (`enable_nat_gateway = false` in `dev`, `true` in `prod`).

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
| `aws_vpc.this` | resource |
| `aws_default_security_group.default` | resource |
| `aws_internet_gateway.this` | resource |
| `aws_subnet.public` | resource |
| `aws_subnet.private` | resource |
| `aws_route_table.public` | resource |
| `aws_route_table_association.public` | resource |
| `aws_eip.nat` | resource |
| `aws_nat_gateway.this` | resource |
| `aws_route_table.private` | resource |
| `aws_route_table_association.private` | resource |
| `data.aws_availability_zones.available` | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Short lowercase project identifier used as a resource prefix. | `string` | n/a | yes |
| `environment` | Deployment environment name (dev or prod). | `string` | n/a | yes |
| `vpc_cidr` | IPv4 CIDR block for the VPC. | `string` | `"10.20.0.0/16"` | no |
| `public_subnet_cidrs` | Two public IPv4 subnet CIDRs across two Availability Zones. | `list(string)` | `["10.20.1.0/24", "10.20.2.0/24"]` | no |
| `private_subnet_cidrs` | Two private IPv4 subnet CIDRs across two Availability Zones. | `list(string)` | `["10.20.11.0/24", "10.20.12.0/24"]` | no |
| `enable_private_subnets` | Whether to create private subnets and a private route table. They exist for the prod NAT variant (ADR 0006); dev leaves this false. Forced on when enable_nat_gateway is true. | `bool` | `false` | no |
| `enable_nat_gateway` | Whether to provision a single NAT Gateway in public subnet 0 for private subnet egress (false in dev to avoid hourly NAT charges). | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the provisioned VPC. |
| `vpc_cidr` | IPv4 CIDR block of the VPC. |
| `public_subnet_ids` | List of public subnet IDs across two Availability Zones. |
| `private_subnet_ids` | Private subnet IDs across two Availability Zones. Empty unless enable_private_subnets or enable_nat_gateway is true. |
| `availability_zones` | Two Availability Zones selected for the VPC subnets. |
<!-- END_TF_DOCS -->
