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
  description = "AWS region for the dev environment."
  type        = string
  default     = "eu-north-1"
}

variable "container_image" {
  description = "Optional explicit container image URI; when empty, defaults to the account ECR repository with image_tag."
  type        = string
  default     = ""
}

variable "image_tag" {
  description = "Immutable ECR image tag (Git SHA) to deploy."
  type        = string
  default     = "initial"
}

variable "app_version" {
  description = "Semantic application version string."
  type        = string
  default     = "0.1.0"
}

variable "git_sha" {
  description = "Git commit SHA reported by /api/v1/info/ and /."
  type        = string
  default     = "initial"
}

variable "ssm_api_key_parameter_name" {
  description = "SSM Parameter Store SecureString path for the X-API-Key secret."
  type        = string
  default     = "/damolak/dev/api-key"
}

variable "alert_email" {
  description = "Email address subscribed to the dev SNS alarm topic (supplied via gitignored terraform.tfvars)."
  type        = string
  default     = ""
  sensitive   = true
}
