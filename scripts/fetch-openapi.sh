#!/usr/bin/env bash
# Pull live Admin (+ public) OpenAPI into this workspace and keep a previous snapshot for diffs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE_URL="${TREM_API_BASE_URL:-https://tremstgapi.axcova.com}"
ADMIN_URL="${TREM_OPENAPI_ADMIN_URL:-${BASE_URL}/api/admin-docs-json}"
PUBLIC_URL="${TREM_OPENAPI_PUBLIC_URL:-${BASE_URL}/api/docs-json}"

cd "$ROOT"
mkdir -p openapi/snapshots artifacts

stamp="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -f openapi-admin.json ]]; then
  cp openapi-admin.json "openapi/snapshots/openapi-admin.prev.json"
  cp openapi-admin.json "openapi/snapshots/openapi-admin.${stamp}.json"
fi

echo "Fetching admin OpenAPI ← ${ADMIN_URL}"
curl -fsSL "$ADMIN_URL" -o openapi-admin.json
python3 - <<'PY'
import json
json.load(open("openapi-admin.json"))
print("admin OpenAPI OK")
PY

echo "Fetching public OpenAPI ← ${PUBLIC_URL}"
curl -fsSL "$PUBLIC_URL" -o openapi.json || echo "warn: public OpenAPI fetch failed (continuing)"

mkdir -p fern/openapi
cp openapi-admin.json fern/openapi/openapi.json

# Detect change vs previous snapshot
changed=0
if [[ -f openapi/snapshots/openapi-admin.prev.json ]]; then
  if ! cmp -s openapi-admin.json openapi/snapshots/openapi-admin.prev.json; then
    changed=1
    echo "OpenAPI CHANGED since last fetch"
  else
    echo "OpenAPI unchanged"
  fi
else
  changed=1
  echo "No previous snapshot — treating as changed"
fi

echo "$changed" > artifacts/openapi-changed.txt
echo "Wrote openapi-admin.json, fern/openapi/openapi.json"
