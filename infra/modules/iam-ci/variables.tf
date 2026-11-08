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
  description = "Primary AWS region where CI/CD deployments are permitted."
  type        = string
  default     = "eu-north-1"
}

variable "tfstate_bucket_name" {
  description = "Name of the S3 bucket storing Terraform remote state."
  type        = string

  validation {
    condition     = length(trimspace(var.tfstate_bucket_name)) > 0
    error_message = "tfstate_bucket_name must not be empty."
  }
}
