mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "account-redacted"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"sts:GetCallerIdentity\"],\"Resource\":[\"*\"]}]}"
    }
  }
}

run "dev_plan" {
  command = plan

  variables {
    alert_email = "operator@example.com"
    image_tag   = "initial"
    git_sha     = "initial"
    app_version = "0.1.0"
  }

  assert {
    condition     = output.cluster_name == "damolak-dev-cluster"
    error_message = "Expected dev ECS cluster name to be damolak-dev-cluster."
  }

  assert {
    condition     = output.service_name == "damolak-dev-api"
    error_message = "Expected dev ECS service name to be damolak-dev-api."
  }

  assert {
    condition     = output.log_group_name == "/ecs/damolak-dev"
    error_message = "Expected dev CloudWatch log group to be /ecs/damolak-dev."
  }

  assert {
    condition     = length(output.alarm_names) == 5
    error_message = "Expected five CloudWatch metric alarms in dev."
  }
}
