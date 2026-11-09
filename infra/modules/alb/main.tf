locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Public HTTP ingress to the shared ALB. Services add their own egress rules to this group."
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# trivy:ignore:AVD-AWS-0107 Public ALB must accept HTTP ingress from any client IPv4 address.
resource "aws_vpc_security_group_ingress_rule" "http_in" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow public HTTP traffic from the internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# trivy:ignore:AVD-AWS-0053 ALB is intentionally internet-facing to serve the public assessment URL.
resource "aws_lb" "this" {
  # checkov:skip=CKV_AWS_150:Deletion protection is a variable; it is off in dev so make down can tear the stack down.
  # checkov:skip=CKV_AWS_91:ALB access logging to S3 is omitted to avoid S3 request and storage charges in dev.
  # checkov:skip=CKV2_AWS_28:WAFv2 is omitted to stay within the USD 40 credit budget.
  # checkov:skip=CKV2_AWS_20:HTTP-to-HTTPS redirect is omitted because no custom domain or ACM certificate is provisioned.
  name                       = "${local.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

# The default action is a fixed 404 so a request that matches no service rule never reaches a task.
# trivy:ignore:AVD-AWS-0054 HTTP listener is used because no custom DNS domain or ACM certificate is available in the account.
resource "aws_lb_listener" "http" {
  # checkov:skip=CKV_AWS_2:HTTP listener is used intentionally because no Route 53 domain is available for ACM validation.
  # checkov:skip=CKV_AWS_103:TLS policy applies only to HTTPS listeners.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}
