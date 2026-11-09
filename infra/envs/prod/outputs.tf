output "vpc_id" {
  description = "ID of the prod VPC."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "Public DNS name of the prod Application Load Balancer."
  value       = module.alb.dns_name
}

output "service_url" {
  description = "Public HTTP URL of the deployed prod API service."
  value       = "http://${module.alb.dns_name}"
}

output "cluster_name" {
  description = "Name of the prod ECS cluster."
  value       = module.ecs_cluster.cluster_name
}

output "service_name" {
  description = "Name of the prod ECS service."
  value       = module.ecs_service.service_name
}
