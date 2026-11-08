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
  description = "AWS region where the ECS service and ALB are deployed."
  type        = string
  default     = "eu-north-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier such as eu-north-1."
  }
}

variable "vpc_id" {
  description = "ID of the VPC hosting the ALB and ECS service."
  type        = string

  validation {
    condition     = length(trimspace(var.vpc_id)) > 0
    error_message = "vpc_id must not be empty."
  }
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block of the VPC, passed to uvicorn --forwarded-allow-ips."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs across at least two Availability Zones for the ALB."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "At least two public_subnet_ids are required for the Application Load Balancer."
  }
}

variable "service_subnet_ids" {
  description = "List of subnet IDs across at least two Availability Zones for ECS Fargate tasks."
  type        = list(string)

  validation {
    condition     = length(var.service_subnet_ids) >= 2
    error_message = "At least two service_subnet_ids are required for high-availability task placement."
  }
}

variable "assign_public_ip" {
  description = "Whether to assign a public IPv4 address to task ENIs (true in NAT-less dev, false in private prod subnets)."
  type        = bool
  default     = true
}

variable "container_image" {
  description = "Full container image URI (immutable tag or digest) to deploy."
  type        = string

  validation {
    condition     = length(trimspace(var.container_image)) > 0
    error_message = "container_image must not be empty."
  }
}

variable "app_version" {
  description = "Semantic version string exposed by the application telemetry endpoints."
  type        = string
  default     = "0.1.0"

  validation {
    condition     = length(trimspace(var.app_version)) > 0
    error_message = "app_version must not be empty."
  }
}

variable "git_sha" {
  description = "Git commit SHA exposed by the application telemetry endpoints."
  type        = string
  default     = "initial"

  validation {
    condition     = length(trimspace(var.git_sha)) > 0
    error_message = "git_sha must not be empty."
  }
}

variable "container_port" {
  description = "TCP port on which the application container listens."
  type        = number
  default     = 8000

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be a valid Fargate CPU value (256, 512, 1024, 2048, or 4096)."
  }
}

variable "memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512

  validation {
    condition     = var.memory >= 512 && var.memory <= 30720
    error_message = "memory must be between 512 and 30720 MiB."
  }
}

variable "desired_count" {
  description = "Initial desired number of running Fargate tasks."
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1 && var.desired_count <= 10
    error_message = "desired_count must be between 1 and 10."
  }
}

variable "min_capacity" {
  description = "Minimum number of running tasks maintained by Application Auto Scaling."
  type        = number
  default     = 1

  validation {
    condition     = var.min_capacity >= 1 && var.min_capacity <= 10
    error_message = "min_capacity must be between 1 and 10."
  }
}

variable "max_capacity" {
  description = "Maximum number of running tasks permitted by Application Auto Scaling."
  type        = number
  default     = 2

  validation {
    condition     = var.max_capacity >= 1 && var.max_capacity <= 10
    error_message = "max_capacity must be between 1 and 10."
  }
}

variable "cpu_target_value" {
  description = "Target average CPU utilization percentage for Application Auto Scaling."
  type        = number
  default     = 70

  validation {
    condition     = var.cpu_target_value >= 20 && var.cpu_target_value <= 90
    error_message = "cpu_target_value must be between 20 and 90."
  }
}

variable "health_check_path" {
  description = "HTTP path probed by the ALB target group and container health check."
  type        = string
  default     = "/api/v1/health/"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with a forward slash."
  }
}

variable "log_group_name" {
  description = "Name of the CloudWatch Logs group receiving container stdout/stderr."
  type        = string

  validation {
    condition     = length(trimspace(var.log_group_name)) > 0
    error_message = "log_group_name must not be empty."
  }
}

variable "ssm_api_key_parameter_name" {
  description = "SSM Parameter Store path holding the SecureString X-API-Key secret."
  type        = string

  validation {
    condition     = startswith(var.ssm_api_key_parameter_name, "/")
    error_message = "ssm_api_key_parameter_name must start with a leading slash."
  }
}

variable "enable_deletion_protection" {
  description = "Whether to enable deletion protection on the Application Load Balancer."
  type        = bool
  default     = false
}
