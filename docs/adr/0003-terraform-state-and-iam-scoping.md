# ADR 0003: S3 Native State Locking, Secret-Free State, and Scoped Jenkins IAM Policy

* **Status:** Accepted
* **Date:** 2026-11-08

## Context

Terraform state files store resource attributes in plaintext JSON. If an `aws_iam_access_key` or `data.aws_ssm_parameter` is evaluated by Terraform, the raw secret value is written into `terraform.tfstate`. In addition, the S3 state bucket name includes the AWS account ID for global uniqueness, which must not appear in tracked files. Finally, the local Jenkins deployment agent (`damolak-jenkins-ci`) requires permissions to push images to ECR and reconcile the `dev` stack without holding unrestricted administrator rights.

## Decision

1. **S3 Native Lockfile State Backend (`use_lockfile = true`):**
   * `infra/bootstrap` provisions a versioned, SSE-S3 (`AES256`) encrypted S3 bucket with `aws_s3_bucket_public_access_block`, a TLS-only bucket policy (`aws:SecureTransport = false` deny), and a 30-day noncurrent version expiration rule.
   * Terraform 1.17 native S3 state locking (`use_lockfile = true`) is used instead of a deprecated DynamoDB lock table.
   * `make bootstrap` (`scripts/bootstrap.sh`) reads the bucket name output from `infra/bootstrap` and generates gitignored `infra/envs/{shared,dev,prod}/backend.hcl` files. Tracked `.hcl.example` files use `<ACCOUNT_ID>` placeholders.

2. **Zero Secrets in Terraform State:**
   * The `ecs-service` module never reads `data.aws_ssm_parameter`. Instead, it constructs the parameter ARN from `var.aws_region`, `data.aws_caller_identity.current.account_id`, and `var.ssm_api_key_parameter_name`, passing that ARN to the ECS container `secrets` block and granting `ssm:GetParameters` on that single ARN to the ECS task execution role.
   * The `iam-ci` module creates the `damolak-jenkins-ci` user and its permissions boundary, but never creates `aws_iam_access_key`. Access keys are created out-of-band by `scripts/create-jenkins-key.sh`.

3. **Time-Boxed `damolak-jenkins-ci` IAM Policy and Permissions Boundary:**
   * **Scoped to exact ARNs or `damolak-*` prefixes:**
     * S3 state access is restricted to `arn:aws:s3:::${var.tfstate_bucket_name}` and its objects.
     * ECR image push/pull and repository inspection are restricted to `arn:aws:ecr:eu-north-1:<account>:repository/damolak-*`.
     * IAM role creation, policy attachment, and inspection are restricted to `arn:aws:iam::<account>:role/damolak-*`.
     * `iam:PassRole` is restricted to `arn:aws:iam::<account>:role/damolak-*` AND conditioned on `iam:PassedToService = ecs-tasks.amazonaws.com`.
     * SSM read access is restricted to `arn:aws:ssm:eu-north-1:<account>:parameter/damolak/*`.
   * **Explicitly denied in the permissions boundary:**
     * `iam:CreateUser`, `iam:DeleteUser`, `iam:CreateAccessKey`, `iam:DeleteAccessKey`, `iam:UpdateAccessKey`, `iam:PutUserPolicy`, `iam:AttachUserPolicy`, `iam:PutUserPermissionsBoundary`, `iam:DeleteUserPermissionsBoundary`, `organizations:*`, `account:*`, and `budgets:*`.
   * **Documented wildcard exceptions (not scoped tighter within the 2-hour time-box):**
     * `ecr:GetAuthorizationToken` and `sts:GetCallerIdentity` require `Resource = "*"` by AWS IAM specification.
     * Regional stack actions (`ecs:*`, `ec2:*`, `elasticloadbalancing:*`, `logs:*`, `cloudwatch:*`, `sns:*`, `application-autoscaling:*`) use `Resource = "*"` constrained by `Condition: StringEquals: aws:RequestedRegion = eu-north-1` because EC2/VPC/ELB `Describe*` calls, `ecs:RegisterTaskDefinition`, and newly created VPC/subnet/security-group IDs do not support static ARN prefix conditions prior to creation unless `aws:RequestTag` conditions are added to every individual EC2/ELB action.

## Consequences

* No secret (`API_KEY` or IAM secret access key) is ever stored in local or S3 Terraform state.
* No AWS account ID is committed to git.
* Even if the local Jenkins credentials were compromised, the permissions boundary prevents IAM user/key creation, permissions-boundary removal, billing/organization access, and operations outside `eu-north-1`.
