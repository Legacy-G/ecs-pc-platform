output "vpc_id" {
  description = "ID of the prod VPC."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the prod Application Load Balancer."
  value       = module.ecs_service.alb_dns_name
}

output "service_url" {
  description = "Public HTTP URL of the deployed prod API service."
  value       = module.ecs_service.service_url
}

output "cluster_name" {
  description = "Name of the prod ECS cluster."
  value       = module.ecs_service.cluster_name
}

output "service_name" {
  description = "Name of the prod ECS service."
  value       = module.ecs_service.service_name
}
