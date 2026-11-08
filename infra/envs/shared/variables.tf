variable "project_name" {
  description = "Short lowercase project identifier used as a resource prefix."
  type        = string
  default     = "damolak"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for shared platform resources."
  type        = string
  default     = "eu-north-1"
}

variable "monthly_budget_limit_usd" {
  description = "Monthly gross cost budget limit in USD before Free Plan credits."
  type        = string
  default     = "40"
}

variable "alert_email" {
  description = "Email address receiving budget threshold alerts (supplied via gitignored terraform.tfvars)."
  type        = string
  default     = "operator@example.com"
  sensitive   = true
}
