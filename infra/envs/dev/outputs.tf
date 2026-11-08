output "vpc_id" {
  description = "ID of the dev VPC."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the dev Application Load Balancer."
  value       = module.ecs_service.alb_dns_name
}

output "service_url" {
  description = "Public HTTP URL of the deployed dev API service."
  value       = module.ecs_service.service_url
}

output "cluster_name" {
  description = "Name of the dev ECS cluster."
  value       = module.ecs_service.cluster_name
}

output "service_name" {
  description = "Name of the dev ECS service."
  value       = module.ecs_service.service_name
}

output "task_definition_arn" {
  description = "ARN of the active dev ECS task definition."
  value       = module.ecs_service.task_definition_arn
}

output "log_group_name" {
  description = "Name of the CloudWatch Logs group for dev ECS tasks."
  value       = module.observability.log_group_name
}

output "dashboard_name" {
  description = "Name of the dev CloudWatch operational dashboard."
  value       = module.observability.dashboard_name
}

output "alarm_names" {
  description = "List of CloudWatch alarm names monitoring the dev stack."
  value       = module.observability.alarm_names
}
