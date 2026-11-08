mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "account-redacted"
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
