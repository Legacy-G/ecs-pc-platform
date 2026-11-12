# ADR 0001: Record Architecture Decisions in the Repository

- **Status:** Accepted
- **Date:** 2026-11-08

## Context

Infrastructure and platform choices involve concrete trade-offs between cost, security boundaries, AWS Free Plan Service Control Policies (SCPs), and operational complexity. Reviewers and operators inspecting the repository need to see why each option was selected and which alternatives were rejected without reading commit logs.

## Decision

Store numbered Architecture Decision Records in `docs/adr/` using `0000-template.md`. Every architectural choice in application runtime, compute, networking, state locking, secrets, CI authentication, and observability is recorded as an ADR.

## Alternatives considered

1. **Inline code comments only:** Scatters cross-cutting rationale across Terraform files and scripts.
2. **Single monolithic design section in `README.md`:** Extends `README.md` and mixes reproduction steps with architectural trade-offs.
3. **Numbered Architecture Decision Records under `docs/adr/`:** One focused document per decision, indexed in `README.md`.

## Consequences

- **Positive:** Reviewers can inspect each trade-off in isolation, including exact AWS Price List numbers and Free Plan SCP findings.
- **Negative / Limits:** Adding or changing an architectural boundary requires updating the corresponding ADR alongside the code change.
