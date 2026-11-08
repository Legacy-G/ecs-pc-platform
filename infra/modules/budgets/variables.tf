variable "project_name" {
  description = "Short lowercase project identifier used as a resource prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "monthly_limit_usd" {
  description = "Monthly gross cost budget limit in USD before Free Plan credits."
  type        = string
  default     = "40"

  validation {
    condition     = tonumber(var.monthly_limit_usd) > 0 && tonumber(var.monthly_limit_usd) <= 100
    error_message = "monthly_limit_usd must be a positive number no greater than 100."
  }
}

variable "alert_email" {
  description = "Email address receiving budget threshold alerts at 50, 80, and 100 percent."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", trimspace(var.alert_email)))
    error_message = "alert_email must be a valid email address."
  }
}
