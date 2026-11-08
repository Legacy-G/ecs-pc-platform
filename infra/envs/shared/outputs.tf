output "ecr_repository_url" {
  description = "Full ECR repository URL for pushing and pulling damolak-api images."
  value       = module.ecr.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the damolak-api ECR repository."
  value       = module.ecr.repository_arn
}

output "jenkins_ci_user_name" {
  description = "IAM username for the local Jenkins deployment agent."
  value       = module.iam_ci.iam_user_name
}

output "jenkins_ci_permissions_boundary_arn" {
  description = "ARN of the permissions boundary attached to the Jenkins CI user."
  value       = module.iam_ci.permissions_boundary_arn
}

output "budget_name" {
  description = "Name of the monthly gross cost budget."
  value       = module.budgets.budget_name
}
