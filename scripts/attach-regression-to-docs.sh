#!/usr/bin/env bash
# Merge HTML regression report into docs/dist for GitHub Pages deploy.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash scripts/build-docs.sh

mkdir -p docs/dist/regression
if [[ -d artifacts/regression-report ]]; then
  cp -R artifacts/regression-report/. docs/dist/regression/
else
  cat > docs/dist/regression/index.html <<'HTML'
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>No report</title></head>
<body><p>No regression report generated for this run.</p>
<p><a href="../">← Docs home</a></p></body></html>
HTML
fi

echo "Attached regression UI → docs/dist/regression/"
