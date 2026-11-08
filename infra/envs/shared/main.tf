data "aws_caller_identity" "current" {}

locals {
  tfstate_bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
}

module "ecr" {
  source = "../../modules/ecr"

  repository_name         = "${var.project_name}-api"
  force_delete            = true
  max_tagged_image_count  = 10
  untagged_retention_days = 1
}

module "iam_ci" {
  source = "../../modules/iam-ci"

  project_name        = var.project_name
  aws_region          = var.aws_region
  tfstate_bucket_name = local.tfstate_bucket_name
}

module "budgets" {
  source = "../../modules/budgets"

  project_name      = var.project_name
  monthly_limit_usd = var.monthly_budget_limit_usd
  alert_email       = var.alert_email
}
