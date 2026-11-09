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

variable "vpc_id" {
  description = "ID of the VPC hosting the Application Load Balancer."
  type        = string

  validation {
    condition     = length(trimspace(var.vpc_id)) > 0
    error_message = "vpc_id must not be empty."
  }
}

variable "public_subnet_ids" {
  description = "Public subnet IDs in at least two Availability Zones for the load balancer."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public_subnet_ids are required for the Application Load Balancer."
  }
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the load balancer."
  type        = bool
  default     = false
}
