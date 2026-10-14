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

python3 - <<'PY'
import json
from pathlib import Path
p = Path("docs/dist/openapi-admin.json")
data = json.loads(p.read_text())
info = data.setdefault("info", {})
info.setdefault("title", "Trem Admin API")
info.setdefault("version", info.get("version") or "stg")
p.write_text(json.dumps(data))
print("spec ready:", info.get("title"), info.get("version"), "paths:", len(data.get("paths", {})))
PY

# Use Scalar browser standalone bundle (package root / wrong versions = blank page).
# On GitHub project pages, relative data-url resolves under /trem-api-platform/.
cat > docs/dist/index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Trem Admin API Docs</title>
    <style>
      html, body { margin: 0; height: 100%; background: #0f1117; color: #e8eaed; }
      #boot {
        font-family: ui-sans-serif, system-ui, sans-serif;
        padding: 1.5rem;
        max-width: 40rem;
      }
      #boot a { color: #8ab4ff; }
      #boot.hidden { display: none; }
    </style>
  </head>
  <body>
    <div id="boot">
      <p>Loading Trem Admin API docs…</p>
      <p>If this stays blank, open
        <a href="./openapi-admin.json">openapi-admin.json</a>
        or the
        <a href="https://github.com/dzariq/trem-api-platform/blob/main/docs/BEGINNER-GUIDE.md">beginner guide</a>.
      </p>
    </div>

    <script
      id="api-reference"
      data-url="./openapi-admin.json"
      data-configuration='{"theme":"kepler","layout":"modern","hideModels":false,"showSidebar":true}'
    ></script>
    <script
      src="https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.74.0/dist/browser/standalone.js"
      onload="document.getElementById('boot')?.classList.add('hidden')"
      onerror="document.getElementById('boot').innerHTML='<p><strong>Failed to load Scalar CDN.</strong> Spec is still available: <a href=./openapi-admin.json>openapi-admin.json</a></p>'"
    ></script>
  </body>
</html>
HTML

cp docs/dist/index.html docs/index.html
cp docs/dist/openapi-admin.json docs/openapi-admin.json

echo "Docs built → docs/dist/ (open docs/dist/index.html or npm run docs:serve)"
