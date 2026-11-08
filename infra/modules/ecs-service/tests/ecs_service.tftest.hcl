mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "account-mock"
    }
  }
}

variables {
  project_name               = "damolak"
  environment                = "dev"
  aws_region                 = "eu-north-1"
  vpc_id                     = "vpc-mock1234"
  vpc_cidr                   = "10.20.0.0/16"
  public_subnet_ids          = ["subnet-pub1", "subnet-pub2"]
  service_subnet_ids         = ["subnet-pub1", "subnet-pub2"]
  assign_public_ip           = true
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
  enable_deletion_protection = false
}

run "valid_fargate_service_plan" {
  command = plan

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "ALB must drop invalid HTTP header fields."
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == false
    error_message = "ALB deletion protection must be disabled in dev."
  }

  assert {
    condition     = aws_lb_target_group.this.health_check[0].path == "/api/v1/health/"
    error_message = "Target group health check path must be /api/v1/health/."
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
