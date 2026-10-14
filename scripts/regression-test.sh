#!/usr/bin/env bash
# Schema regression: Schemathesis validates live API responses against OpenAPI.
# Auth: optional login via TREM_ADMIN_EMAIL / TREM_ADMIN_PASSWORD.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE_URL="${TREM_API_BASE_URL:-https://tremstgapi.axcova.com}"
SPEC="${1:-openapi-admin.json}"
MAX_EXAMPLES="${SCHEMATHESIS_MAX_EXAMPLES:-10}"
WORKERS="${SCHEMATHESIS_WORKERS:-2}"

if [[ ! -f "$SPEC" ]]; then
  echo "Missing $SPEC — run npm run fetch:openapi first" >&2
  exit 1
fi

mkdir -p artifacts .venv

if [[ ! -d .venv ]] || [[ ! -f .venv/bin/schemathesis ]]; then
  echo "Creating Python venv + installing schemathesis…"
  python3 -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install -q -U pip
  pip install -q -r requirements-regression.txt
else
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

AUTH_ARGS=()

if [[ -n "${TREM_ADMIN_EMAIL:-}" && -n "${TREM_ADMIN_PASSWORD:-}" ]]; then
  echo "Logging in as ${TREM_ADMIN_EMAIL}…"
  login_json="$(curl -fsS -X POST "${BASE_URL}/api/admin/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${TREM_ADMIN_EMAIL}\",\"password\":\"${TREM_ADMIN_PASSWORD}\"}")"
  token="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])' <<<"$login_json")"
  AUTH_ARGS=(-H "Authorization: Bearer ${token}")
  echo "Auth header ready"
else
  echo "No TREM_ADMIN_EMAIL/PASSWORD — unauthenticated run (many auth failures expected)."
fi

REPORT="artifacts/schemathesis-junit.xml"

set +e
schemathesis run "$SPEC" \
  --base-url "$BASE_URL" \
  --checks all \
  --workers "$WORKERS" \
  --hypothesis-max-examples "$MAX_EXAMPLES" \
  --hypothesis-deadline 5000 \
  --exclude-path-regex 'upload|delete|bulk|apply-setup|asset' \
  --include-path-regex '^/api/admin/(auth/login|shows|venues|articles|cron-jobs)' \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
  --junit-xml "$REPORT" \
  2>&1 | tee artifacts/schemathesis.log
code=${PIPESTATUS[0]}
set -e

echo "Schemathesis exit: $code (report: $REPORT)"

if [[ -f "$REPORT" ]]; then
  python3 scripts/build-regression-report.py \
    --junit "$REPORT" \
    --out-dir artifacts/regression-report \
    --base-url "$BASE_URL" \
    --spec "$SPEC"
  echo "HTML report: artifacts/regression-report/index.html"
fi

if [[ "${STRICT_REGRESSION:-0}" == "1" ]]; then
  exit "$code"
fi
if [[ "$code" -ne 0 ]]; then
  echo "WARN: regression reported failures (set STRICT_REGRESSION=1 to fail hard)"
fi
exit 0
