data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  # Construct the SSM parameter ARN without reading the secret value into Terraform state.
  ssm_api_key_parameter_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.ssm_api_key_parameter_name, "/")}"
}

# trivy:ignore:AVD-AWS-0107 Public internet-facing ALB intentionally accepts HTTP TCP/80 from 0.0.0.0/0.
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allow public HTTP ingress to ALB and forward only to ECS task port"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# trivy:ignore:AVD-AWS-0107 Public ALB must accept HTTP ingress from any client IPv4 address.
resource "aws_vpc_security_group_ingress_rule" "alb_http_in" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow public HTTP traffic from the internet"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward HTTP requests only to ECS task security group on container port"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id
}

resource "aws_security_group" "task" {
  name        = "${local.name_prefix}-task-sg"
  description = "Allow HTTP from ALB only and outbound HTTPS TCP/443 for AWS APIs and ECR"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.name_prefix}-task-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "Accept HTTP traffic exclusively from the ALB security group"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# trivy:ignore:AVD-AWS-0104 Outbound TCP 443 to 0.0.0.0/0 is required to reach ECR, S3 layer storage, CloudWatch Logs, and SSM without paid VPC interface endpoints.
resource "aws_vpc_security_group_egress_rule" "task_https_out" {
  security_group_id = aws_security_group.task.id
  description       = "Allow outbound HTTPS TCP 443 for ECR pulls, SSM Parameter Store, and CloudWatch Logs"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# trivy:ignore:AVD-AWS-0053 ALB is intentionally internet-facing to serve the public assessment URL.
resource "aws_lb" "this" {
  # checkov:skip=CKV_AWS_150:Deletion protection is disabled in dev so make down / make nuke can tear down cleanly.
  # checkov:skip=CKV_AWS_91:ALB access logging to S3 is omitted to avoid additional S3 request/storage charges in dev.
  # checkov:skip=CKV2_AWS_28:WAFv2 is omitted to stay within the USD 40 Free Plan credit budget.
  # checkov:skip=CKV2_AWS_20:HTTP-to-HTTPS redirect is omitted because no custom Route 53 domain or ACM certificate is provisioned.
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

resource "aws_lb_target_group" "this" {
  name                 = "${local.name_prefix}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 25

  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

# trivy:ignore:AVD-AWS-0054 HTTP listener is used because no custom DNS domain or ACM TLS certificate is available in the challenge account.
resource "aws_lb_listener" "http" {
  # checkov:skip=CKV_AWS_2:HTTP listener is used intentionally because no Route 53 domain is available for ACM validation.
  # checkov:skip=CKV_AWS_103:TLS cipher policy applies only to HTTPS listeners.
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name_prefix}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.name_prefix}-task-exec-role"
  }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "execution_ssm" {
  statement {
    sid       = "ReadApiKeyParameterOnly"
    effect    = "Allow"
    actions   = ["ssm:GetParameters"]
    resources = [local.ssm_api_key_parameter_arn]
  }
}

resource "aws_iam_role_policy" "execution_ssm" {
  name   = "${local.name_prefix}-exec-ssm-policy"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_ssm.json
}

resource "aws_iam_role" "task" {
  name               = "${local.name_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.name_prefix}-task-role"
  }
}

resource "aws_ecs_task_definition" "this" {
  # checkov:skip=CKV_AWS_336:Read-only root filesystem is enabled on the container with a writable /tmp volume.
  family                   = "${local.name_prefix}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "tmp"
  }

  container_definitions = jsonencode([
    {
      name                   = "api"
      image                  = var.container_image
      essential              = true
      readonlyRootFilesystem = true
      stopTimeout            = 30
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      mountPoints = [
        {
          sourceVolume  = "tmp"
          containerPath = "/tmp"
          readOnly      = false
        }
      ]
      environment = [
        {
          name  = "APP_NAME"
          value = "${var.project_name}-api"
        },
        {
          name  = "APP_ENV"
          value = var.environment
        },
        {
          name  = "APP_VERSION"
          value = var.app_version
        },
        {
          name  = "GIT_SHA"
          value = var.git_sha
        },
        {
          name  = "AWS_REGION"
          value = var.aws_region
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        },
        {
          name  = "FORWARDED_ALLOW_IPS"
          value = var.vpc_cidr
        }
      ]
      secrets = [
        {
          name      = "API_KEY"
          valueFrom = local.ssm_api_key_parameter_arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.container_port}${var.health_check_path}', timeout=2)\""
        ]
        interval    = 15
        timeout     = 5
        retries     = 3
        startPeriod = 20
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-api"
  }
}

resource "aws_ecs_service" "this" {
  name                               = "${local.name_prefix}-api"
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "1.4.0"
  wait_for_steady_state              = true
  health_check_grace_period_seconds  = 30
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.service_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = var.assign_public_ip
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "api"
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${local.name_prefix}-api"
  }
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.name_prefix}-cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
