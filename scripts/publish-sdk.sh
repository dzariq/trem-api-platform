#!/usr/bin/env bash
# Build & publish @dzariq/trem-api to GitHub Packages from this workspace.
# Usage: ./scripts/publish-sdk.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$ROOT/sdks/typescript"
VERSION="${1:-}"

cd "$SDK"

if [[ -n "$VERSION" ]]; then
  npm version "$VERSION" --no-git-tag-version --allow-same-version
fi

npm install
npm run build

export NODE_AUTH_TOKEN="${NODE_AUTH_TOKEN:-$(gh auth token)}"
npm publish --registry=https://npm.pkg.github.com

echo "Published $(node -p "require('./package.json').name + '@' + require('./package.json').version")"
