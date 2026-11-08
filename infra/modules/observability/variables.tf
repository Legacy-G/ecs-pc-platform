variable "project_name" {
  description = "Short lowercase project identifier used as a resource prefix."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name (dev or prod)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be either 'dev' or 'prod'."
  }
}

variable "aws_region" {
  description = "AWS region for CloudWatch Logs, alarms, and dashboards."
  type        = string
  default     = "eu-north-1"
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days (7 in dev, 30 in prod)."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention period."
  }
}

variable "alert_email" {
  description = "Email address subscribed to the SNS alarm notification topic (supplied via gitignored tfvars)."
  type        = string
  default     = ""
  sensitive   = true
}

variable "cluster_name" {
  description = "ECS cluster name for CloudWatch alarm and dashboard dimensions."
  type        = string
}

variable "service_name" {
  description = "ECS service name for CloudWatch alarm and dashboard dimensions."
  type        = string
}

variable "alb_arn_suffix" {
  description = "Application Load Balancer ARN suffix for CloudWatch metrics."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ALB target group ARN suffix for CloudWatch metrics."
  type        = string
}
