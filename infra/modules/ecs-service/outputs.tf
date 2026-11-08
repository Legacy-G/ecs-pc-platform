output "cluster_id" {
  description = "ARN/ID of the ECS cluster."
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "service_id" {
  description = "ID of the ECS service."
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "Name of the ECS service."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "Full ARN of the registered ECS task definition revision."
  value       = aws_ecs_task_definition.this.arn
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN of the ECS task runtime IAM role."
  value       = aws_iam_role.task.arn
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB for CloudWatch metric dimensions."
  value       = aws_lb.this.arn_suffix
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the Application Load Balancer."
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "Security group ID attached to the Application Load Balancer."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the ALB target group."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group for CloudWatch metric dimensions."
  value       = aws_lb_target_group.this.arn_suffix
}

output "task_security_group_id" {
  description = "Security group ID attached to ECS Fargate tasks."
  value       = aws_security_group.task.id
}

output "service_url" {
  description = "Base HTTP URL for reaching the service via the Application Load Balancer."
  value       = "http://${aws_lb.this.dns_name}"
}
