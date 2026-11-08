# Manual Operator Steps (`HUMAN_STEPS.md`)

This document lists every action that requires human credentials, console interaction, email confirmation, or explicit approval in chat. Automation scripts handle everything else.

> [!CAUTION]
> **AWS Free Plan Account Protection Rules:**
> - **Never** upgrade the AWS account from the Free Plan to a Paid Plan, and **never** add a credit or debit card beyond the initial signup verification.
> - **Never** enable or configure IAM Identity Center (AWS SSO), AWS Organizations, or AWS Control Tower.
> - **Never** modify, detach policies from, or delete AWS-managed roles (`AccountFullAccessRole`, `AWSManagedAccountManagementAccessRole`, `AWSManagedAdvancedFeaturesActivationRole`, or any role under `/aws-service-role/`).
> - Perform all CLI and Terraform operations using the IAM user `platform-admin` via the named profile `AWS_PROFILE=damolak` in region `eu-north-1`.

---

## 1. Local AWS CLI Profile (`damolak`)

**Status:** Completed and verified in Phase 0.

The account is accessed in the browser via Google federation into AWS's managed `AccountFullAccessRole`. Because that browser session cannot be used directly by non-interactive CLI tools without IAM Identity Center, an IAM user named `platform-admin` with `AdministratorAccess` is configured under `~/.aws/credentials` and `~/.aws/config` as profile `damolak`:

```ini
# ~/.aws/config
[profile damolak]
region = eu-north-1
output = json
```

Verify the profile before running any infrastructure command:

```bash
AWS_PROFILE=damolak aws sts get-caller-identity
AWS_PROFILE=damolak aws freetier get-account-plan-state --region us-east-1
```

---

## 2. GitHub CLI Authentication (`gh auth login`)

**When required:** Before pushing branches or creating pull requests from the CLI.

Run the following command in your terminal and complete the browser device flow for user `Legacy-G`:

```bash
gh auth login --hostname github.com --git-protocol https --web
```

Verify authentication:

```bash
gh auth status
```

---

## 3. Local Untracked Configuration Files (`tfvars` and `.env`)

**When required:** Phase 2 (before `terraform plan`).

Committed `.tfvars.example` files never contain email addresses or account IDs. Create the untracked `infra/envs/shared/terraform.tfvars` and `infra/envs/dev/terraform.tfvars` files locally by copying their `.example` templates and setting `alert_email` to your notification address.

---

## 4. SSM Parameter Store Secret (`X-API-Key`)

**When required:** Phase 3 (after explicit chat approval, before starting the ECS service).

The `/api/v1/echo/` endpoint requires an `X-API-Key` header loaded from SSM Parameter Store (`SecureString`, standard tier) at `/damolak/dev/api-key`. The key is generated and written out-of-band so the secret value never enters Terraform state or git history:

```bash
AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/create-api-key.sh dev
```

---

## 5. SNS Email Subscription and Budget Alert Confirmation

**When required:** Phase 3 (immediately after `terraform apply` on `shared` and `dev`).

1. Open the inbox for the configured `alert_email`.
2. Locate the message from `AWS Notifications` with subject `AWS Notification - Subscription Confirmation` for topic `damolak-dev-alerts` in `eu-north-1`.
3. Click **Confirm subscription**. Until confirmed, CloudWatch alarm actions do not deliver emails.

---

## 6. Jenkins Controller Credentials (`damolak-jenkins-ci`)

**When required:** Phase 4.

Terraform in `infra/envs/shared` creates the IAM user `damolak-jenkins-ci` constrained by the `damolak-jenkins-ci-boundary` permissions boundary, but **never** creates an `aws_iam_access_key` resource so the secret key stays out of `.tfstate`.

1. After approving the `shared` apply, run the helper script to generate the key via the AWS CLI and load it into the local Jenkins credential store:
   ```bash
   AWS_PROFILE=damolak bash scripts/create-jenkins-key.sh
   ```
2. Open `http://127.0.0.1:8080`, sign in with the local admin password from `.env`, go to **Manage Jenkins -> Credentials -> System -> Global credentials**, and verify credential ID `aws-jenkins-ci` is populated, then delete `jenkins-ci-access-key.json`.

---

## 7. GitHub Actions Scope (CI-Only Mirror)

**Finding from Phase 0 SCP check:** AWS Free Plan accounts sit inside an AWS-managed Organization whose Service Control Policy explicitly denies `iam:CreateOpenIDConnectProvider` and `iam:ListOpenIDConnectProviders`, and restricts regional resource creation to `eu-north-1`.

Because the account SCP blocks creating an IAM OIDC identity provider on the Free Plan:
- GitHub Actions runs as a credential-free CI pipeline (`.github/workflows/ci.yml`) executing linting, prose checks, unit tests, Docker image builds, Trivy/Gitleaks/Checkov security scans, and `terraform fmt` / `terraform validate` (`-backend=false`) on every push and pull request.
- Jenkins performs all AWS deployments. The OIDC constraint is recorded in ADR 0007 and listed under production improvements in `README.md`.

---

## 8. Explicit Approval Gates for Cloud Changes

No command that creates, modifies, or deletes AWS resources (`terraform apply`, `terraform destroy`, `aws ssm put-parameter`, `aws iam create-access-key`) will ever be executed by the assistant without first printing the estimated hourly and daily credit impact and receiving explicit approval in chat.

---

## 9. Teardown Tiers (`make down` vs `make nuke`)

1. **`make down` (`scripts/down.sh` - Routine Dev Teardown):**
   - Destroys `infra/envs/dev` (VPC, subnets, internet gateway, Application Load Balancer, target group, ECS cluster, ECS service, task definitions, IAM task roles, CloudWatch log group, metric filter, 5 alarms, dashboard, and SNS topic) and runs `scripts/cost-check.sh`.
   - Leaves `infra/envs/shared` (ECR repository `damolak-api`, IAM user `damolak-jenkins-ci`, and monthly AWS Cost Budget) and `infra/bootstrap` (S3 remote state bucket) intact so subsequent `dev` deployments take ~2 minutes without rebuilding state or re-pushing base layers.
   - **Residual cost after `make down`:** Hourly compute and ALB cost drops to **USD 0.0000/hr**. Storage left behind consists of ~80 MB compressed container layers in ECR (`USD 0.10/GB-month` -> ~**USD 0.008/month**) and < 100 KB of `.tfstate` objects in S3 (~**USD 0.001/month**), totaling **< USD 0.01/month**.
2. **`make nuke` (`scripts/nuke.sh` - Complete Account Cleanup):**
   - Requires interactive confirmation (`NUKE`), then destroys `infra/envs/dev`, deletes SSM parameter `/damolak/dev/api-key`, destroys `infra/envs/shared` (including force-deleting the ECR repository), empties all object versions/delete markers in the `infra/bootstrap` S3 bucket and destroys the bucket, removes local `backend.hcl` files, and runs `scripts/cost-check.sh` to verify zero remaining billable resources.
