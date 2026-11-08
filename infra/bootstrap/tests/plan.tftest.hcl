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

run "bootstrap_plan" {
  command = plan

  assert {
    condition     = aws_s3_bucket.tfstate.bucket == "damolak-tfstate-account-redacted-eu-north-1"
    error_message = "Bootstrap state bucket name must follow damolak-tfstate-<account>-eu-north-1."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.tfstate.block_public_acls == true && aws_s3_bucket_public_access_block.tfstate.restrict_public_buckets == true
    error_message = "Bootstrap state bucket must block all public access."
  }
}
