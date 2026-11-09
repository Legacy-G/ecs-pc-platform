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

output "ssm_api_key_parameter_arn" {
  description = "Constructed ARN of the SSM parameter the execution role may read."
  value       = local.ssm_api_key_parameter_arn
}
