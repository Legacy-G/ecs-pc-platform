# Operations Runbook (`RUNBOOK.md`)

This runbook covers routine verification, cost inspection, failure drills, and full teardown for `ecs-pc-platform` in `eu-north-1`.

## 1. Verify Account Plan and Credit Balance

Run the cost and inventory check before starting work and after every teardown:

```bash
AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/cost-check.sh
```

Expected output when torn down:
- `Plan`: `FREE`, `Status`: `ACTIVE`
- `ECS clusters`, `ALBs`, `NAT gateways`, `Elastic IPs`, `EC2 instances`: `none`
- Exit code `0`

## 2. Local Development Lifecycle

Build and start the API container locally:

```bash
cp .env.example .env
docker compose up --build -d
curl -fsS http://127.0.0.1:8000/api/v1/health/
curl -fsS http://127.0.0.1:8000/api/v1/info/
docker compose down
```

## 3. Quality and Security Checks

Run all repository linters, unit tests, and prose checks before committing:

```bash
bash scripts/check-prose.sh
pre-commit run --all-files
```

## 4. Inspect Live ECS Service and Logs (Phase 3+)

View running tasks and recent structured JSON log lines:

```bash
AWS_PROFILE=damolak aws ecs describe-services \
  --region eu-north-1 \
  --cluster damolak-dev \
  --services api \
  --query 'services[0].{Status:status,Desired:desiredCount,Running:runningCount,Deployments:deployments[].{Status:status,Rollout:rolloutState}}'

AWS_PROFILE=damolak aws logs tail /ecs/damolak-dev/api \
  --region eu-north-1 \
  --since 15m
```

## 5. Clean Teardown Procedure

Tear down the environment in reverse dependency order so no orphaned network interfaces, load balancers, or public IPv4 addresses remain active:

1. Destroy `infra/envs/dev` (after explicit confirmation).
2. Delete the `/damolak/dev/api/api_key` SSM parameter if tearing down permanently.
3. Destroy `infra/envs/shared` (after emptying ECR images if tearing down permanently).
4. Run `AWS_PROFILE=damolak AWS_REGION=eu-north-1 bash scripts/cost-check.sh` and confirm zero active hourly resources.
