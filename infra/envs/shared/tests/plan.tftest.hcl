mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "account-redacted"
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
