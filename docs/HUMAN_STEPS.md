# Manual Operator Steps (`HUMAN_STEPS.md`)

This document lists every action that requires human credentials, console interaction, email confirmation, or explicit operator approval in chat. Automation scripts and the Jenkins CI/CD pipeline handle everything else.

> [!CAUTION]
> **AWS Free Plan Account Protection Rules:**
> - **Never** upgrade the AWS account from the Free Plan to a Paid Plan, and **never** add a credit or debit card beyond the initial signup verification.
> - **Never** enable or configure IAM Identity Center (AWS SSO), AWS Organizations, or AWS Control Tower.
> - **Never** modify, detach policies from, or delete AWS-managed roles (`AccountFullAccessRole`, `AWSManagedAccountManagementAccessRole`, `AWSManagedAdvancedFeaturesActivationRole`, or any role under `/aws-service-role/`).
> - Perform all CLI and Terraform operations using the IAM user `platform-admin` via the named profile `AWS_PROFILE=damolak` in region `eu-north-1`.

---

## 1. Local AWS CLI Profile (`damolak`)

**Status:** Configured and active.

The account is accessed in the browser via Google federation into AWS's managed `AccountFullAccessRole`. Because that browser session cannot be used directly by non-interactive CLI tools without IAM Identity Center, an IAM user named `platform-admin` with `AdministratorAccess` is configured under `~/.aws/credentials` and `~/.aws/config` as profile `damolak`:

```ini
# ~/.aws/config
[profile damolak]
region = eu-north-1
output = json
```

Verify caller identity:

```bash
AWS_PROFILE=damolak aws sts get-caller-identity
```

---

## 2. GitHub CLI Authentication (`gh auth login`)

Authenticate the GitHub CLI before pushing branches or managing pull requests:

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth status
```

---

## 3. Local Untracked Configuration Files (`tfvars` and `.env`)

Committed `.tfvars.example` files never contain email addresses or account IDs. Create the untracked `infra/envs/shared/terraform.tfvars` and `infra/envs/dev/terraform.tfvars` files locally by copying their `.example` templates and supplying an alert email address.

---

## 4. SSM Parameter Store Secret (`X-API-Key`)

The `/api/v1/echo/` endpoint requires an `X-API-Key` header loaded from SSM Parameter Store (`SecureString`, standard tier) at `/damolak/dev/api-key`. The key is generated and written out-of-band so the secret value never enters Terraform state or git history:

```bash
AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/create-api-key.sh dev
```

---

## 5. SNS Email Subscription Confirmation

When an alert email is configured on the `damolak-dev-alerts` topic:
1. Open the inbox for the configured address.
2. Locate the email from `AWS Notifications` with subject `AWS Notification - Subscription Confirmation` for topic `damolak-dev-alerts` in `eu-north-1`.
3. Click **Confirm subscription**. Until confirmed, CloudWatch alarm actions cannot deliver notification emails.

---

## 6. Jenkins Controller Credentials (`damolak-jenkins-ci`)

Terraform in `infra/envs/shared` creates the IAM user `damolak-jenkins-ci` constrained by the `damolak-jenkins-ci-boundary` permissions boundary, without persisting secret keys in state.

1. Generate the access key via AWS CLI:
   ```bash
   AWS_PROFILE=damolak bash scripts/create-jenkins-key.sh
   ```
2. Populate the key into `ci/jenkins/.jenkins.env` as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` (gitignored). Jenkins loads these credentials at boot via Jenkins Configuration as Code (`ci/jenkins/jenkins.yaml`).

---

## 7. GitHub Actions Scope (CI-Only Gate)

**Account Organization SCP Constraint:** AWS Free Plan accounts sit inside an AWS-managed Organization whose Service Control Policy explicitly denies `iam:CreateOpenIDConnectProvider` and `iam:ListOpenIDConnectProviders`. As documented in [ADR 0007](adr/0007-github-actions-ci-only-scp-oidc-block.md), GitHub Actions is strictly credential-free and performs offline verification only (lint, format, test, scan, and validation). All cloud deployments execute through the isolated Jenkins controller using dedicated IAM credentials with permission boundaries.
