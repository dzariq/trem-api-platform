#!/usr/bin/env bash
# Schema regression — PUBLIC API only (openapi.json from /api/docs-json).
# Optional auth: TREM_USER_EMAIL / TREM_USER_PASSWORD → POST /api/auth/login
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE_URL="${TREM_API_BASE_URL:-https://tremstgapi.axcova.com}"
SPEC="${1:-openapi.json}"
MAX_EXAMPLES="${SCHEMATHESIS_MAX_EXAMPLES:-10}"
WORKERS="${SCHEMATHESIS_WORKERS:-2}"

if [[ ! -f "$SPEC" ]]; then
  echo "Missing $SPEC — run npm run fetch:openapi first" >&2
  exit 1
fi

if [[ "$(basename "$SPEC")" == "openapi-admin.json" ]]; then
  echo "Public-only suite — pass openapi.json, not openapi-admin.json" >&2
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
export TREM_REGRESSION_API="public"
export TREM_REGRESSION_AUTH="none"

EMAIL="${TREM_USER_EMAIL:-}"
PASSWORD="${TREM_USER_PASSWORD:-}"

if [[ -n "$EMAIL" && -n "$PASSWORD" ]]; then
  echo "Logging in (public) as ${EMAIL}…"
  if login_json="$(curl -fsS -X POST "${BASE_URL}/api/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")"; then
    token="$(printf '%s' "$login_json" | python3 -c 'import json,sys; b=json.load(sys.stdin); d=b.get("data") or b; t=d.get("access_token") or d.get("accessToken"); assert t; print(t)')"
    AUTH_ARGS=(-H "Authorization: Bearer ${token}")
    export TREM_REGRESSION_AUTH="public bearer"
    echo "Auth header ready (public bearer)"
  else
    echo "Public login failed — continuing unauthenticated" >&2
  fi
else
  echo "No TREM_USER_EMAIL/PASSWORD — unauthenticated public run (some 401s expected)."
fi

REPORT="artifacts/schemathesis-junit.xml"

echo "Running Schemathesis against PUBLIC OpenAPI: $SPEC → $BASE_URL"

set +e
schemathesis run "$SPEC" \
  --base-url "$BASE_URL" \
  --checks all \
  --workers "$WORKERS" \
  --hypothesis-max-examples "$MAX_EXAMPLES" \
  --hypothesis-deadline 5000 \
  --exclude-path-regex 'upload|webhook' \
  ${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"} \
  --junit-xml "$REPORT" \
  2>&1 | tee artifacts/schemathesis.log
code=${PIPESTATUS[0]}
set -e

echo "Schemathesis exit: $code (report: $REPORT) [public API]"

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
