#!/usr/bin/env bash
# Auto-draft changelog from OpenAPI diff (previous snapshot → current).
# Uses oasdiff via Docker. Output: artifacts/openapi-changelog.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p artifacts openapi openapi/snapshots

PREV="openapi/snapshots/openapi-admin.prev.json"
CUR="openapi-admin.json"
OUT="openapi/CHANGELOG.draft.md"
ARTIFACT_COPY="artifacts/openapi-changelog.md"

finish() {
  cp "$OUT" "$ARTIFACT_COPY"
  echo "Wrote $OUT"
}

if [[ ! -f "$CUR" ]]; then
  echo "Missing $CUR — run npm run fetch:openapi first" >&2
  exit 1
fi

if [[ ! -f "$PREV" ]]; then
  cat > "$OUT" <<EOF
# OpenAPI changelog draft

_No previous snapshot yet. Next fetch will produce a real diff._

Baseline: \`openapi-admin.json\` ($(wc -c < "$CUR" | tr -d ' ') bytes)
EOF
  finish
  echo "(baseline only)"
  exit 0
fi

if cmp -s "$PREV" "$CUR"; then
  cat > "$OUT" <<EOF
# OpenAPI changelog draft

No changes detected between previous snapshot and current \`openapi-admin.json\`.
EOF
  finish
  echo "No OpenAPI diff"
  exit 0
fi

echo "Running oasdiff changelog…"
if docker info >/dev/null 2>&1; then
  docker run --rm \
    -v "$ROOT:/work" -w /work \
    tufin/oasdiff:latest \
    changelog \
    /work/openapi/snapshots/openapi-admin.prev.json \
    /work/openapi-admin.json \
    --format text \
    > "$OUT" || {
      # Older/newer oasdiff CLI flag differences — fallback to diff
      docker run --rm \
        -v "$ROOT:/work" -w /work \
        tufin/oasdiff:latest \
        diff \
        /work/openapi/snapshots/openapi-admin.prev.json \
        /work/openapi-admin.json \
        --format text \
        > "$OUT"
    }
else
  echo "Docker unavailable — writing file-size hint only" >&2
  cat > "$OUT" <<EOF
# OpenAPI changelog draft

Docker not available; install Docker and re-run \`npm run changelog:diff\`.

Files differ:
- prev: $(wc -c < "$PREV" | tr -d ' ') bytes
- curr: $(wc -c < "$CUR" | tr -d ' ') bytes
EOF
fi

# Prepend header for pasting into sdks/typescript/CHANGELOG.md
tmp="$(mktemp)"
{
  echo "# OpenAPI changelog draft"
  echo ""
  echo "_Generated $(date -u +%Y-%m-%dT%H:%M:%SZ). Copy relevant bits into \`sdks/typescript/CHANGELOG.md\` under a new version._"
  echo ""
  cat "$OUT"
} > "$tmp"
mv "$tmp" "$OUT"

finish
head -n 40 "$OUT"
