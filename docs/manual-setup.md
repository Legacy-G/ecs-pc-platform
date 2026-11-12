# Manual setup

This document lists operator procedures requiring personal credentials, console interaction, or email confirmation. Automated scripts and the deployment pipeline handle other operations.

> [!CAUTION]
> **Account Protection Rules:**
> - Never upgrade the AWS account to a paid plan.
> - Never enable IAM Identity Center, AWS Organizations, or AWS Control Tower.
> - Never modify or delete AWS-managed roles (`AccountFullAccessRole`, `AWSManagedAccountManagementAccessRole`, `AWSManagedAdvancedFeaturesActivationRole`, or service-linked roles under `/aws-service-role/`).
> - Perform CLI and Terraform operations using the IAM user `platform-admin` via named profile `damolak` in region `eu-north-1`.

---

## 1. Local AWS CLI Profile

An IAM user named `platform-admin` operates under `~/.aws/credentials` and `~/.aws/config` as profile `damolak`:

```ini
# ~/.aws/config
[profile damolak]
region = eu-north-1
output = json
```

Caller identity command:

```bash
AWS_PROFILE=damolak aws sts get-caller-identity
```

---

## 2. GitHub CLI Authentication

Authentication command:

```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth status
```

---

## 3. Local Configuration Files

Tracked `.tfvars.example` files omit email addresses and account IDs. Copy `.example` templates to create local `infra/envs/shared/terraform.tfvars` and `infra/envs/dev/terraform.tfvars` files with a valid alert recipient address.

---

## 4. SSM Parameter Store Secret

The `/api/v1/echo/` endpoint requires an `X-API-Key` header loaded from SSM Parameter Store (`SecureString`, standard tier) at `/damolak/dev/api-key`. Creation command:

```bash
AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/create-api-key.sh dev
```

---

## 5. SNS Email Subscription Confirmation

When an alert email is configured on the `damolak-dev-alerts` topic:
1. Open the inbox for the configured address.
2. Locate the email from `AWS Notifications` with subject `AWS Notification - Subscription Confirmation` for topic `damolak-dev-alerts` in `eu-north-1`.
3. Select **Confirm subscription**. CloudWatch alarm actions require confirmation to deliver notification emails.

---

## 6. Pipeline Controller Credentials

Terraform in `infra/envs/shared` creates IAM user `damolak-jenkins-ci` constrained by `damolak-jenkins-ci-boundary`, without persisting secret keys in state.

1. Generate access keys via AWS CLI:
   ```bash
   AWS_PROFILE=damolak bash scripts/create-jenkins-key.sh
   ```
2. Populate the keys into `ci/jenkins/.jenkins.env` as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. The controller loads these credentials at boot via configuration as code (`ci/jenkins/jenkins.yaml`).

---

## 7. Continuous Integration Scope

The AWS Organization Service Control Policy explicitly denies `iam:CreateOpenIDConnectProvider` and `iam:ListOpenIDConnectProviders`. As detailed in [ADR 0007](adr/0007-github-actions-ci-only-scp-oidc-block.md), the repository workflow runs credential-free static analysis and validation. Deployments execute through the isolated pipeline controller using dedicated credentials constrained by permission boundaries.
