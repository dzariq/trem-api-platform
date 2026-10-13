#!/usr/bin/env bash
# Build a static Scalar API reference from openapi-admin.json → docs/dist
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SPEC="openapi-admin.json"
if [[ ! -f "$SPEC" ]]; then
  echo "Missing $SPEC — run npm run fetch:openapi first" >&2
  exit 1
fi

mkdir -p docs/dist
cp "$SPEC" docs/dist/openapi-admin.json

# Pretty-print for browser load reliability
python3 - <<'PY'
import json
from pathlib import Path
p = Path("docs/dist/openapi-admin.json")
data = json.loads(p.read_text())
# Scalar works better with an OpenAPI title
info = data.setdefault("info", {})
info.setdefault("title", "Trem Admin API")
info.setdefault("version", info.get("version") or "stg")
p.write_text(json.dumps(data))
print("spec ready:", info.get("title"), info.get("version"))
PY

cat > docs/dist/index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Trem Admin API Docs</title>
    <style>
      body { margin: 0; }
    </style>
  </head>
  <body>
    <script
      id="api-reference"
      data-url="./openapi-admin.json"
      data-configuration='{"theme":"default","layout":"modern","hideModels":false,"showSidebar":true}'
    ></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.28.0"></script>
  </body>
</html>
HTML

# Also copy into docs/ for GitHub Pages from /docs if preferred
cp docs/dist/index.html docs/index.html
cp docs/dist/openapi-admin.json docs/openapi-admin.json

echo "Docs built → docs/dist/ (open docs/dist/index.html or npm run docs:serve)"
