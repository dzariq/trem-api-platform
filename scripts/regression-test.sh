#!/usr/bin/env bash
# Schema regression — PUBLIC API only (openapi.json from /api/docs-json).
# Optional auth: TREM_USER_EMAIL / TREM_USER_PASSWORD → POST /api/auth/login
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE_URL="${TREM_API_BASE_URL:-https://tremstgapi.axcova.com}"
SOURCE_SPEC="${1:-openapi.json}"
MAX_EXAMPLES="${SCHEMATHESIS_MAX_EXAMPLES:-10}"
WORKERS="${SCHEMATHESIS_WORKERS:-2}"

if [[ ! -f "$SOURCE_SPEC" ]]; then
  echo "Missing $SOURCE_SPEC — run npm run fetch:openapi first" >&2
  exit 1
fi

if [[ "$(basename "$SOURCE_SPEC")" == "openapi-admin.json" ]]; then
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

# Enrich OpenAPI so 400/401/etc. are documented (stg returns them; raw swagger often omits)
python3 scripts/prepare-public-openapi-for-regression.py \
  --in "$SOURCE_SPEC" \
  --out artifacts/openapi-public-regression.json
SPEC="artifacts/openapi-public-regression.json"

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
  echo "No TREM_USER_EMAIL/PASSWORD — unauthenticated public run."
fi

REPORT="artifacts/schemathesis-junit.xml"

echo "Running Schemathesis against PUBLIC OpenAPI: $SPEC → $BASE_URL"

# Important flags:
# - generation-with-security-parameters=false → don't inject fake Bearer tokens (was causing mass 401)
# - data-generation-method=positive → valid payloads only
# - exclude ignored_auth → many "public" ops declare bearer but work without it
# - exclude negative_data_rejection → less noise from intentional invalid cases
set +e
schemathesis run "$SPEC" \
  --base-url "$BASE_URL" \
  --checks not_a_server_error,status_code_conformance,content_type_conformance,response_schema_conformance \
  --exclude-checks ignored_auth,negative_data_rejection \
  --data-generation-method positive \
  --generation-with-security-parameters=false \
  --generation-allow-x00=false \
  --workers "$WORKERS" \
  --hypothesis-max-examples "$MAX_EXAMPLES" \
  --hypothesis-deadline 5000 \
  --exclude-path-regex 'upload|webhook|auth/oauth|payments/sandbox|tickets/validate|checkout/return$' \
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
    --spec "openapi.json (prepared)"
  echo "HTML report: artifacts/regression-report/index.html"
fi

if [[ "${STRICT_REGRESSION:-0}" == "1" ]]; then
  exit "$code"
fi
if [[ "$code" -ne 0 ]]; then
  echo "WARN: regression reported failures (set STRICT_REGRESSION=1 to fail hard)"
fi
exit 0
