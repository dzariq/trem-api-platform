#!/usr/bin/env bash
# Bump, build, tag, and push @dzariq/trem-api. Requires CHANGELOG.md entry for the version.
#
# Usage:
#   ./scripts/release-sdk.sh 0.1.1
#   ./scripts/release-sdk.sh 0.1.1 --no-push
#   ./scripts/release-sdk.sh 0.1.1 --notes-only   # only print release notes from CHANGELOG
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$ROOT/sdks/typescript"
CHANGELOG="$SDK/CHANGELOG.md"
VERSION="${1:-}"
NO_PUSH=0
NOTES_ONLY=0

shift || true
for arg in "$@"; do
  case "$arg" in
    --no-push) NO_PUSH=1 ;;
    --notes-only) NOTES_ONLY=1 ;;
    *) echo "Unknown flag: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version> [--no-push] [--notes-only]" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "Version must look like 0.1.1 (got: $VERSION)" >&2
  exit 1
fi

if [[ ! -f "$CHANGELOG" ]]; then
  echo "Missing $CHANGELOG" >&2
  exit 1
fi

if ! grep -qE "^## \[${VERSION}\]" "$CHANGELOG"; then
  echo "CHANGELOG.md has no section: ## [${VERSION}] - YYYY-MM-DD" >&2
  echo "Add the section (move items out of ## [Unreleased]), then re-run." >&2
  exit 1
fi

extract_notes() {
  awk -v ver="$VERSION" '
    $0 ~ "^## \\[" ver "\\]" {grab=1; next}
    grab && $0 ~ /^## \[/ {exit}
    grab {print}
  ' "$CHANGELOG"
}

NOTES="$(extract_notes | sed -e 's/[[:space:]]*$//' )"
if [[ -z "$(echo "$NOTES" | tr -d '[:space:]')" ]]; then
  echo "Changelog section for ${VERSION} is empty. Add Added/Changed/Breaking notes." >&2
  exit 1
fi

if [[ "$NOTES_ONLY" -eq 1 ]]; then
  echo "$NOTES"
  exit 0
fi

cd "$SDK"

npm version "$VERSION" --no-git-tag-version --allow-same-version
npm install
npm run build

git add -A
if git diff --cached --quiet; then
  echo "Nothing to commit (already at $VERSION?)."
else
  git commit -m "Release ${VERSION}"
fi

git tag -f "v${VERSION}"

echo ""
echo "=== Release notes (v${VERSION}) ==="
echo "$NOTES"
echo "==================================="

if [[ "$NO_PUSH" -eq 1 ]]; then
  echo "Skipped push (--no-push). Tag v${VERSION} is local only."
  exit 0
fi

TOKEN="$(gh auth token)"
REMOTE_URL="https://x-access-token:${TOKEN}@github.com/dzariq/trem-api.git"

# Bypass global https→ssh insteadOf rewrite (dzariq vs other SSH accounts).
GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  git -c "credential.helper=" push "$REMOTE_URL" HEAD:main

GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
  git -c "credential.helper=" push "$REMOTE_URL" "v${VERSION}" --force

if gh release view "v${VERSION}" >/dev/null 2>&1; then
  gh release edit "v${VERSION}" --notes "$NOTES"
else
  gh release create "v${VERSION}" --title "v${VERSION}" --notes "$NOTES"
fi

echo ""
echo "Released @dzariq/trem-api@${VERSION}"
echo "  git:   github:dzariq/trem-api#v${VERSION}"
echo "  page:  https://github.com/dzariq/trem-api/releases/tag/v${VERSION}"
echo "  log:   https://github.com/dzariq/trem-api/blob/main/CHANGELOG.md"
