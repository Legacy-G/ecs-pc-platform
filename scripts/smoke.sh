#!/usr/bin/env bash
# Verify that the deployed API service is reachable, healthy, and serving the
# expected Git SHA on both HTML and JSON endpoints.
set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8000}"
EXPECTED_SHA="${2:-}"
MAX_ATTEMPTS="${SMOKE_MAX_ATTEMPTS:-20}"
SLEEP_SECONDS="${SMOKE_SLEEP_SECONDS:-6}"

BASE_URL="${BASE_URL%/}"

echo "Smoke testing ${BASE_URL} (expected_sha=${EXPECTED_SHA:-any})"

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  if health_json="$(curl -fsS --max-time 5 "${BASE_URL}/api/v1/health/" 2>/dev/null)" &&
     info_json="$(curl -fsS --max-time 5 "${BASE_URL}/api/v1/info/" 2>/dev/null)" &&
     status_html="$(curl -fsS --max-time 5 "${BASE_URL}/" 2>/dev/null)"; then

    if echo "$health_json" | grep -q '"status":"ok"'; then
      if [[ -z "$EXPECTED_SHA" ]] || echo "$info_json" | grep -q "\"git_sha\":\"${EXPECTED_SHA}\""; then
        if echo "$status_html" | grep -q "Runtime Telemetry"; then
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
