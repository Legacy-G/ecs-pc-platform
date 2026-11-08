mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "account-redacted"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"sts:GetCallerIdentity\"],\"Resource\":[\"*\"]}]}"
    }
  }
}

run "shared_plan" {
  command = plan

  variables {
    alert_email              = "operator@example.com"
    monthly_budget_limit_usd = "40"
  }

  assert {
    condition     = output.jenkins_ci_user_name == "damolak-jenkins-ci"
    error_message = "Expected Jenkins CI IAM username to be damolak-jenkins-ci."
  }

  assert {
    condition     = output.budget_name == "damolak-monthly-gross-budget"
    error_message = "Expected monthly gross cost budget name to be damolak-monthly-gross-budget."
  }
}
