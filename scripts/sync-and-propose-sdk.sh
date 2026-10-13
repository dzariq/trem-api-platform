#!/usr/bin/env bash
# After OpenAPI changes: remind / optionally regenerate Fern SDK locally.
# Full cloud generate needs: fern login + FERN_TOKEN
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

changed="$(cat artifacts/openapi-changed.txt 2>/dev/null || echo 1)"
if [[ "$changed" != "1" ]]; then
  echo "OpenAPI unchanged — skip SDK propose step"
  exit 0
fi

echo "OpenAPI changed — draft changelog at openapi/CHANGELOG.draft.md"
if [[ -f openapi/CHANGELOG.draft.md ]]; then
  head -n 60 openapi/CHANGELOG.draft.md
fi

if command -v fern >/dev/null 2>&1 && [[ -n "${FERN_TOKEN:-}" ]]; then
  echo "Running fern generate --group local…"
  (cd fern && FERN_TOKEN="$FERN_TOKEN" fern generate --group local) || {
    echo "fern generate failed (cloud login/token?). Skip auto SDK update."
    exit 0
  }
  echo "SDK regenerated under sdks/typescript — bump CHANGELOG + ./scripts/release-sdk.sh"
else
  cat <<EOF

Next steps for SDK release:
  1) Review openapi/CHANGELOG.draft.md
  2) fern login && fern generate --group local
  3) Edit sdks/typescript/CHANGELOG.md with the draft notes
  4) ./scripts/release-sdk.sh x.y.z

EOF
fi
