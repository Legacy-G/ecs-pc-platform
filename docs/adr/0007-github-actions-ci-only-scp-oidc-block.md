# ADR 0007: Credential-Free GitHub Actions CI and Jenkins Deployment under Free Plan SCP

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

The initial architecture evaluated GitHub Actions authenticating to AWS via an IAM OpenID Connect (OIDC) identity provider (`token.actions.githubusercontent.com`) to run `terraform plan` on pull requests.

During the read-only Service Control Policy (SCP) audit on the AWS account, `aws iam simulate-principal-policy` and `aws iam list-open-id-connect-providers` verified that the parent organization SCP explicitly denies `iam:CreateOpenIDConnectProvider` and `iam:ListOpenIDConnectProviders`.

## Decision

Configure `.github/workflows/ci.yml` as a credential-free verification pipeline (executing linters, formatters, unit tests, container builds, security scans, and offline Terraform validation). Run all AWS state and deployment operations through an isolated pipeline controller using dedicated credentials constrained by permission boundaries. Do not declare OIDC provider resources in Terraform.

## Alternatives considered

1. **Store long-lived AWS IAM access keys in GitHub Actions secrets:**
   Violates the credential isolation standard for the public repository and introduces dual deployment paths.
2. **Request parent organization SCP exception:**
   External management boundaries prevent modifying organizational policies.

## Consequences

- **Positive:** Zero cloud credentials stored in GitHub; eliminates concurrent deployment races between GitHub Actions and Jenkins; every pull request still receives full static analysis, unit test, container build, security scan, and offline Terraform validation feedback.
- **Negative / Limits:** `terraform plan` against live AWS state runs in Jenkins rather than on GitHub pull requests. Adding an IAM OIDC provider for GitHub Actions when running on a standard paid AWS account without the Free Plan SCP is documented under production improvements in `README.md`.
