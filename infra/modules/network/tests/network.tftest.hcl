mock_provider "aws" {
  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]
    }
  }
}

run "dev_natless_network" {
  command = plan

  variables {
    project_name       = "damolak"
    environment        = "dev"
    vpc_cidr           = "10.20.0.0/16"
    enable_nat_gateway = false
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.20.0.0/16"
    error_message = "Expected VPC CIDR to match 10.20.0.0/16."
  }

  assert {
    condition     = aws_vpc.this.enable_dns_support == true && aws_vpc.this.enable_dns_hostnames == true
    error_message = "VPC must enable both DNS support and DNS hostnames."
  }

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "Expected two public and two private subnets across two AZs."
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 0
    error_message = "Dev network must not create a NAT Gateway when enable_nat_gateway is false."
  }

  assert {
    condition     = output.availability_zones == tolist(["eu-north-1a", "eu-north-1b"])
    error_message = "Expected first two Availability Zones to be selected."
  }
}

run "prod_nat_network" {
  command = plan

  variables {
    project_name       = "damolak"
    environment        = "prod"
    vpc_cidr           = "10.30.0.0/16"
    enable_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Prod network must create a NAT Gateway when enable_nat_gateway is true."
  }
}

run "reject_invalid_environment" {
  command = plan

  variables {
    project_name = "damolak"
    environment  = "staging"
  }

  expect_failures = [
    var.environment,
  ]
}
