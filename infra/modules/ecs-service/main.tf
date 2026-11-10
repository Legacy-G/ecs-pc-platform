data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  svc_prefix  = "${var.project_name}-${var.environment}-${var.service_name}"
  # Construct the SSM parameter ARN without reading the secret value into Terraform state.
  ssm_api_key_parameter_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${trimprefix(var.ssm_api_key_parameter_name, "/")}"
}

resource "aws_security_group" "task" {
  name        = "${local.svc_prefix}-task-sg"
  description = "Allow HTTP from the ALB only and outbound HTTPS TCP/443 for AWS APIs and ECR"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${local.svc_prefix}-task-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  security_group_id            = aws_security_group.task.id
  description                  = "Accept HTTP traffic exclusively from the ALB security group"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.alb_security_group_id
}

# Each service opens its own port on the shared ALB security group, so adding a service needs no change in the alb module.
resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  security_group_id            = var.alb_security_group_id
  description                  = "Forward HTTP requests to the ${var.service_name} task security group"
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id
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

resource "aws_lb_target_group" "this" {
  name                 = "${local.svc_prefix}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

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
    Name = "${local.svc_prefix}-tg"
  }
}

resource "aws_lb_listener_rule" "this" {
  listener_arn = var.listener_arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    path_pattern {
      values = var.path_patterns
    }
  }

  tags = {
    Name = "${local.svc_prefix}-rule"
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
  name               = "${local.svc_prefix}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.svc_prefix}-task-exec-role"
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
  name   = "${local.svc_prefix}-exec-ssm-policy"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_ssm.json
}

resource "aws_iam_role" "task" {
  name               = "${local.svc_prefix}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Name = "${local.svc_prefix}-task-role"
  }
}

resource "aws_ecs_task_definition" "this" {
  # checkov:skip=CKV_AWS_336:Read-only root filesystem is enabled on the container with a writable /tmp volume.
  family                   = local.svc_prefix
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
      name                   = var.service_name
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
          value = "${var.project_name}-${var.service_name}"
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
    Name = local.svc_prefix
  }
}

resource "aws_ecs_service" "this" {
  name                               = local.svc_prefix
  cluster                            = var.cluster_name
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
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.this]

  tags = {
    Name = local.svc_prefix
  }
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${local.svc_prefix}-cpu-autoscaling"
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
