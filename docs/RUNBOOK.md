# Operations Runbook (`RUNBOOK.md`)

This runbook covers routine verification, cost inspection, alarm management, failure recovery drills, and complete infrastructure teardown for `ecs-pc-platform` in region `eu-north-1`.

---

## 1. Verify Account Plan and Credit Balance

Run the read-only AWS inventory and credit check:

```bash
AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/cost-check.sh
```

Expected output:
- `Plan`: `FREE`, `Status`: `ACTIVE`
- `CreditsUSD`: Remaining credit balance
- Active inventory breakdown: ECS clusters, ALBs, NAT gateways, ALB public IPs, EC2 instances, ECR repositories, and CloudWatch log groups.

---

## 2. Local Development Lifecycle

Build and execute the API container locally with Docker Compose:

```bash
cp .env.example .env
docker compose up --build -d
curl -fsS http://127.0.0.1:8000/api/v1/health/
curl -fsS http://127.0.0.1:8000/api/v1/info/
docker compose down
```

---

## 3. Quality and Security Checks

Execute pre-commit audits, prose validation, unit tests, and security scans:

```bash
bash scripts/check-hygiene.sh
pre-commit run --all-files
gitleaks detect --log-opts="--all"
```

---

## 4. Live ECS Service Inspection and Log Streaming

Inspect the active Fargate task, deployment rollout status, and recent JSON log streams:

```bash
AWS_PROFILE=damolak aws ecs describe-services \
  --region eu-north-1 \
  --cluster damolak-dev-cluster \
  --services damolak-dev-api \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Deployments:deployments[].{Status:status,Rollout:rolloutState}}'

AWS_PROFILE=damolak aws logs tail /ecs/damolak-dev \
  --region eu-north-1 \
  --since 15m
```

---

## 5. CloudWatch Alarms and Operational Notifications

List all active alarms and their state:

```bash
AWS_PROFILE=damolak aws cloudwatch describe-alarms \
  --region eu-north-1 \
  --alarm-name-prefix "damolak-dev" \
  --query "MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}" \
  --output table
```

To test the alert notification pipeline:

```bash
# Inject ALARM state
AWS_PROFILE=damolak aws cloudwatch set-alarm-state \
  --alarm-name damolak-dev-alb-5xx \
  --state-value ALARM \
  --state-reason "Operator test: verifying alarm dispatch" \
  --region eu-north-1

# Verify email is delivered to the subscribed operator address
# Reset alarm state back to OK or allow automatic metric evaluation to clear it
AWS_PROFILE=damolak aws cloudwatch set-alarm-state \
  --alarm-name damolak-dev-alb-5xx \
  --state-value OK \
  --state-reason "Operator reset" \
  --region eu-north-1
```

---

## 6. Failure Recovery and Single-Task Availability Gap

During failure drills (e.g., stopping an active task via `aws ecs stop-task`), ECS Fargate launches a replacement task automatically to satisfy `desired_count = 1`.

### Observed Behavior (Task Recovery Drill)
- **Recovery Time:** Replacement task reached healthy status and resumed HTTP 200 responses in **59.0 seconds**.
- **Error Profile During Replacement:**
  - `T+0s` to `T+10s`: In-flight requests drain cleanly via ALB deregistration delay (30 seconds).
  - `T+12s` to `T+36s`: Connection resets as the terminated task socket closes.
  - `T+44s` to `T+55s`: ALB returns `HTTP 503 Service Unavailable` because the target group has zero registered healthy hosts.
  - `T+59s`: Newly provisioned task passes two consecutive health checks and begins serving traffic.

### Architectural Limitation and Recommendation
In single-task environments (`desired_count = 1`), task failure produces a temporary availability gap (~1 minute). In production, set `desired_count >= 2` across multiple Availability Zones to ensure zero dropped connections during replacement.

---

## 7. Clean Infrastructure Teardown

Tear down resources in reverse dependency order to prevent orphaned ENIs or lingering charges:

```bash
# 1. Destroy dev application stack
terraform -chdir=infra/envs/dev destroy -auto-approve

# 2. Destroy shared infrastructure (ECR, Budgets, CI IAM)
terraform -chdir=infra/envs/shared destroy -auto-approve

# 3. Verify zero billable resources remain
AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/cost-check.sh
```
