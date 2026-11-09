mock_provider "aws" {}

variables {
  project_name      = "damolak"
  environment       = "dev"
  vpc_id            = "vpc-mock1234"
  public_subnet_ids = ["subnet-pub1", "subnet-pub2"]
}

run "alb_defaults" {
  command = plan

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true
    error_message = "ALB must drop invalid HTTP header fields."
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == false
    error_message = "ALB deletion protection must default to off."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "fixed-response" && aws_lb_listener.http.default_action[0].fixed_response[0].status_code == "404"
    error_message = "Listener default action must be a fixed 404."
  }
}

run "reject_single_subnet" {
  command = plan

  variables {
    public_subnet_ids = ["subnet-pub1"]
  }

  expect_failures = [
    var.public_subnet_ids,
  ]
}
