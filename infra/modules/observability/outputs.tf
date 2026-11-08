output "log_group_name" {
  description = "Name of the CloudWatch Logs group for ECS task logs."
  value       = aws_cloudwatch_log_group.ecs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Logs group."
  value       = aws_cloudwatch_log_group.ecs.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic receiving CloudWatch alarm notifications."
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Name of the CloudWatch operational overview dashboard."
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "alarm_names" {
  description = "List of CloudWatch metric alarm names created for the service."
  value = [
    aws_cloudwatch_metric_alarm.alb_5xx.alarm_name,
    aws_cloudwatch_metric_alarm.unhealthy_hosts.alarm_name,
    aws_cloudwatch_metric_alarm.running_task_count.alarm_name,
    aws_cloudwatch_metric_alarm.high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.app_log_errors.alarm_name,
  ]
}
