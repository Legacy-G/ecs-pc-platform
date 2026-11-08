data "aws_caller_identity" "current" {}

locals {
  resolved_container_image = (
    length(trimspace(var.container_image)) > 0
    ? var.container_image
    : "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.project_name}-api:${var.image_tag}"
  )
}

module "network" {
  source = "../../modules/network"

  project_name         = var.project_name
  environment          = "prod"
  vpc_cidr             = "10.30.0.0/16"
  public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24"]
  enable_nat_gateway   = true
}

module "ecs_service" {
  source = "../../modules/ecs-service"

  project_name               = var.project_name
  environment                = "prod"
  aws_region                 = var.aws_region
  vpc_id                     = module.network.vpc_id
  vpc_cidr                   = module.network.vpc_cidr
  public_subnet_ids          = module.network.public_subnet_ids
  service_subnet_ids         = module.network.private_subnet_ids
  assign_public_ip           = false
  container_image            = local.resolved_container_image
  app_version                = var.app_version
  git_sha                    = var.git_sha
  container_port             = 8000
  cpu                        = 512
  memory                     = 1024
  desired_count              = 2
  min_capacity               = 2
  max_capacity               = 4
  cpu_target_value           = 70
  health_check_path          = "/api/v1/health/"
  log_group_name             = module.observability.log_group_name
  ssm_api_key_parameter_name = var.ssm_api_key_parameter_name
  enable_deletion_protection = true
}

module "observability" {
  source = "../../modules/observability"

  project_name            = var.project_name
  environment             = "prod"
  aws_region              = var.aws_region
  log_retention_days      = 30
  alert_email             = var.alert_email
  cluster_name            = module.ecs_service.cluster_name
  service_name            = module.ecs_service.service_name
  alb_arn_suffix          = module.ecs_service.alb_arn_suffix
  target_group_arn_suffix = module.ecs_service.target_group_arn_suffix
}
