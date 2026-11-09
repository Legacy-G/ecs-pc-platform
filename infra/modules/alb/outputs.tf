output "listener_arn" {
  description = "ARN of the HTTP listener that services attach listener rules to."
  value       = aws_lb_listener.http.arn
}

output "security_group_id" {
  description = "Security group ID of the load balancer. Services add an egress rule to their task port."
  value       = aws_security_group.alb.id
}

output "dns_name" {
  description = "Public DNS name of the load balancer."
  value       = aws_lb.this.dns_name
}

output "arn" {
  description = "ARN of the load balancer."
  value       = aws_lb.this.arn
}

output "arn_suffix" {
  description = "ARN suffix of the load balancer for CloudWatch metric dimensions."
  value       = aws_lb.this.arn_suffix
}

output "zone_id" {
  description = "Canonical hosted zone ID of the load balancer."
  value       = aws_lb.this.zone_id
}
