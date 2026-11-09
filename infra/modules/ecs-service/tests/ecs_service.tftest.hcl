mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "account-mock"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"sts:GetCallerIdentity\"],\"Resource\":[\"*\"]}]}"
    }
  }
}

variables {
  project_name               = "damolak"
  environment                = "dev"
  service_name               = "api"
  aws_region                 = "eu-north-1"
  vpc_id                     = "vpc-mock1234"
  vpc_cidr                   = "10.20.0.0/16"
  service_subnet_ids         = ["subnet-pub1", "subnet-pub2"]
  assign_public_ip           = true
  cluster_name               = "damolak-dev-cluster"
  listener_arn               = "arn:aws:elasticloadbalancing:eu-north-1:aws-managed:listener/app/mock/1/2"
  alb_security_group_id      = "sg-alb0123"
  listener_rule_priority     = 100
  path_patterns              = ["/*"]
  container_image            = "public.ecr.aws/docker/library/python:3.13-slim-bookworm"
  app_version                = "0.1.0"
  git_sha                    = "deadbeef"
  container_port             = 8000
  cpu                        = 256
  memory                     = 512
  desired_count              = 1
  min_capacity               = 1
  max_capacity               = 2
  cpu_target_value           = 70
  health_check_path          = "/api/v1/health/"
  log_group_name             = "/ecs/damolak-dev"
  ssm_api_key_parameter_name = "/damolak/dev/api-key"
}

run "valid_fargate_service_plan" {
  command = plan

  assert {
    condition     = aws_lb_target_group.this.health_check[0].path == "/api/v1/health/"
    error_message = "Target group health check path must be /api/v1/health/."
  }

  assert {
    condition     = aws_lb_listener_rule.this.priority == 100
    error_message = "Listener rule must use the priority passed in."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.task_https_out.from_port == 443 && aws_vpc_security_group_egress_rule.task_https_out.to_port == 443
    error_message = "Task security group egress must be restricted to TCP port 443."
  }

  assert {
    condition     = aws_ecs_service.this.wait_for_steady_state == true
    error_message = "ECS service must enable wait_for_steady_state."
  }

  assert {
    condition     = aws_ecs_service.this.deployment_circuit_breaker[0].enable == true && aws_ecs_service.this.deployment_circuit_breaker[0].rollback == true
    error_message = "ECS service must enable the deployment circuit breaker with rollback."
  }

  assert {
    condition     = aws_appautoscaling_target.ecs.min_capacity == 1 && aws_appautoscaling_target.ecs.max_capacity == 2
    error_message = "Autoscaling target must enforce min_capacity=1 and max_capacity=2."
  }

  assert {
    condition     = aws_ecs_service.this.name == "damolak-dev-api"
    error_message = "Service name must be <project>-<environment>-<service_name>."
  }
}

run "second_service_gets_distinct_names" {
  command = plan

  variables {
    service_name           = "worker"
    listener_rule_priority = 200
    path_patterns          = ["/worker/*"]
  }

  assert {
    condition     = aws_ecs_service.this.name == "damolak-dev-worker" && aws_lb_target_group.this.name == "damolak-dev-worker-tg"
    error_message = "A second service must get its own service and target group names."
  }

  assert {
    condition     = aws_iam_role.execution.name == "damolak-dev-worker-task-exec-role"
    error_message = "A second service must get its own IAM roles."
  }
}

run "reject_invalid_fargate_cpu" {
  command = plan

  variables {
    cpu = 300
  }

  expect_failures = [
    var.cpu,
  ]
}

run "reject_relative_ssm_parameter_path" {
  command = plan

  variables {
    ssm_api_key_parameter_name = "damolak/dev/api-key"
  }

  expect_failures = [
    var.ssm_api_key_parameter_name,
  ]
}

run "reject_path_pattern_without_slash" {
  command = plan

  variables {
    path_patterns = ["orders/*"]
  }

  expect_failures = [
    var.path_patterns,
  ]
}
