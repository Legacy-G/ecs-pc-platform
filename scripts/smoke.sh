#!/usr/bin/env bash
# Verify that the deployed API service is reachable, healthy, and serving the
# expected Git SHA on both HTML and JSON endpoints.
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8000}"
EXPECTED_SHA="${2:-}"
SSM_PARAM_NAME="${3:-}"
MAX_ATTEMPTS="${SMOKE_MAX_ATTEMPTS:-20}"
SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-6}"

BASE_URL="${BASE_URL%/}"

echo "Smoke testing ${BASE_URL} (expected_sha=${EXPECTED_SHA:-any})"

API_KEY=""
if [[ -n "${SSM_PARAM_NAME}" ]]; then
  echo "Fetching API key from SSM parameter ${SSM_PARAM_NAME} without echoing..."
  export AWS_PROFILE="${AWS_PROFILE:-damolak}"
  export AWS_REGION="${AWS_REGION:-eu-north-1}"
  export AWS_PAGER=""
  export MSYS_NO_PATHCONV=1
  API_KEY="$(aws ssm get-parameter --name "${SSM_PARAM_NAME}" --with-decryption --query "Parameter.Value" --output text 2>/dev/null || true)"
fi

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  if health_json="$(curl -fsS --max-time 5 "${BASE_URL}/api/v1/health/" 2>/dev/null)" &&
     info_json="$(curl -fsS --max-time 5 "${BASE_URL}/api/v1/info/" 2>/dev/null)" &&
     status_html="$(curl -fsS --max-time 5 "${BASE_URL}/" 2>/dev/null)"; then

    if echo "$health_json" | grep -q '"status":"ok"'; then
      if [[ -z "$EXPECTED_SHA" ]] || echo "$info_json" | grep -q "\"git_sha\":\"${EXPECTED_SHA}\""; then
        if echo "$status_html" | grep -q "Runtime Telemetry"; then
          if [[ -n "$API_KEY" ]]; then
            echo "Testing unauthenticated request (missing key -> expect 401)..."
            missing_code="$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/echo/" \
              -H "Content-Type: application/json" \
              -d '{"message":"no-key"}' || true)"
            if [[ "$missing_code" != "401" ]]; then
              echo "Expected HTTP 401 for missing API key, got ${missing_code}" >&2
              exit 1
            fi

            echo "Testing invalid request (wrong key -> expect 401)..."
            INVALID_KEY="invalid-key"
            wrong_code="$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/echo/" \
              -H "Content-Type: application/json" \
              -H "X-API-Key: ${INVALID_KEY}" \
              -d '{"message":"wrong-key"}' || true)"
            if [[ "$wrong_code" != "401" ]]; then
              echo "Expected HTTP 401 for wrong API key, got ${wrong_code}" >&2
              exit 1
            fi

            echo "Testing authenticated POST /api/v1/echo/ using SSM key (expect 200)..."
            echo_resp="$(curl -fsS -X POST "${BASE_URL}/api/v1/echo/" \
              -H "Content-Type: application/json" \
              -H "X-API-Key: ${API_KEY}" \
              -d '{"message":"smoke-check"}' 2>/dev/null || true)"
            if ! echo "$echo_resp" | grep -q '"echo":"smoke-check"'; then
              echo "Authenticated echo verification failed: ${echo_resp}" >&2
              exit 1
            fi
            echo "echo  : verified authenticated response"

            echo "Testing unknown route (expect 404)..."
            not_found_code="$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/nonexistent" || true)"
            if [[ "$not_found_code" != "404" ]]; then
              echo "Expected HTTP 404 for nonexistent route, got ${not_found_code}" >&2
              exit 1
            fi
            echo "route : verified 404 on nonexistent path"
          fi
          echo "smoke-test: PASS on attempt ${attempt}/${MAX_ATTEMPTS}"
          echo "health: ${health_json}"
          echo "info  : ${info_json}"
          exit 0
        fi
      fi
    fi
  fi
  echo "Attempt ${attempt}/${MAX_ATTEMPTS} not ready yet; sleeping ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo "smoke-test: FAIL after ${MAX_ATTEMPTS} attempts against ${BASE_URL}" >&2
exit 1
