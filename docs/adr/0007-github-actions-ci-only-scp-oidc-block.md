# ADR 0007: Credential-Free GitHub Actions CI and Jenkins Deployment under Free Plan SCP

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

The initial architecture planned for GitHub Actions to authenticate to AWS via an IAM OpenID Connect (OIDC) identity provider (`token.actions.githubusercontent.com`) to run `terraform plan` on pull requests and `terraform apply` on manual workflow dispatch.

During the Phase 0 and Phase 1 read-only Service Control Policy (SCP) audit on the AWS Free Plan account, `aws iam simulate-principal-policy` and `aws iam list-open-id-connect-providers` confirmed that the parent organization SCP explicitly denies `iam:CreateOpenIDConnectProvider` and `iam:ListOpenIDConnectProviders`.

## Options Considered

1. **GitHub Actions as credential-free CI; Jenkins as sole deployment engine:**
   - GitHub Actions runs on every push and pull request without AWS credentials, executing prose checks, `ruff`, `yamllint`, `shellcheck`, `pytest` unit tests, Docker image build, `hadolint`, `trivy`, `gitleaks`, `checkov`, `terraform fmt -check`, and `terraform validate` (`-backend=false`).
   - Local Jenkins controller performs all AWS authenticated stages (`ecr` push, `terraform plan` against remote state, `terraform apply`, and ALB smoke test) by assuming a time-boxed deployment role via an IAM user (`jenkins-ci`) whose access key is created outside Terraform.
2. **Store long-lived AWS IAM access keys in GitHub Actions secrets:**
   - Violates the zero-stored-cloud-keys rule in the public GitHub repository and creates a second deployment path that could race with Jenkins.

## Decision

Choose Option 1. Do not include OIDC provider resources in Terraform modules for this account, and do not store AWS credentials in GitHub Actions. Configure `.github/workflows/ci.yml` as a credential-free verification pipeline and run all AWS state and deployment operations through the Jenkins pipeline.

## Consequences

- **Positive:** Zero cloud credentials stored in GitHub; eliminates concurrent deployment races between GitHub Actions and Jenkins; every pull request still receives full static analysis, unit test, container build, security scan, and offline Terraform validation feedback.
- **Negative / Limits:** `terraform plan` against live AWS state runs in Jenkins rather than on GitHub pull requests. Adding an IAM OIDC provider for GitHub Actions when running on a standard paid AWS account without the Free Plan SCP is documented under production improvements in `README.md`.
