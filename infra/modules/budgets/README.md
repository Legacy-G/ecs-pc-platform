# `budgets` Terraform Module

Provisions a monthly AWS Cost Budget (`limit_amount = "40" USD`, `include_credit = false` to track gross usage before Free Plan credits) with email alert notifications at 50%, 80%, and 100% actual spend.

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
| `aws_budgets_budget.monthly` | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `project_name` | Short lowercase project identifier used as a resource prefix. | `string` | n/a | yes |
| `monthly_limit_usd` | Monthly gross cost budget limit in USD before Free Plan credits. | `string` | `"40"` | no |
| `alert_email` | Email address receiving budget threshold alerts at 50, 80, and 100 percent. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| `budget_id` | ID of the monthly AWS Cost Budget. |
| `budget_name` | Name of the monthly AWS Cost Budget. |
<!-- END_TF_DOCS -->
