variable "repository_name" {
  description = "Name of the ECR repository."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-_./]+$", var.repository_name))
    error_message = "repository_name must be a valid ECR repository name."
  }
}

variable "force_delete" {
  description = "Whether to allow deleting the ECR repository even when it contains images."
  type        = bool
  default     = true
}

variable "max_tagged_image_count" {
  description = "Number of most-recent tagged images retained by the lifecycle policy."
  type        = number
  default     = 10

  validation {
    condition     = var.max_tagged_image_count >= 1 && var.max_tagged_image_count <= 100
    error_message = "max_tagged_image_count must be between 1 and 100."
  }
}

variable "untagged_retention_days" {
  description = "Number of days before untagged images expire."
  type        = number
  default     = 1

  validation {
    condition     = var.untagged_retention_days >= 1 && var.untagged_retention_days <= 30
    error_message = "untagged_retention_days must be between 1 and 30."
  }
}
