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
  description = "AWS region for the Terraform state S3 bucket."
  type        = string
  default     = "eu-north-1"
}
