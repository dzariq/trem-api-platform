#!/usr/bin/env bash
# Build Scalar docs for BOTH Admin + Public OpenAPI → docs/dist
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ADMIN_SPEC="openapi-admin.json"
PUBLIC_SPEC="openapi.json"

if [[ ! -f "$ADMIN_SPEC" ]]; then
  echo "Missing $ADMIN_SPEC — run npm run fetch:openapi first" >&2
  exit 1
fi
if [[ ! -f "$PUBLIC_SPEC" ]]; then
  echo "Missing $PUBLIC_SPEC — run npm run fetch:openapi first" >&2
  exit 1
fi

mkdir -p docs/dist/admin docs/dist/public
cp "$ADMIN_SPEC" docs/dist/admin/openapi.json
cp "$PUBLIC_SPEC" docs/dist/public/openapi.json

python3 - <<'PY'
import json
from pathlib import Path

def normalize(path: Path, default_title: str) -> None:
    data = json.loads(path.read_text())
    info = data.setdefault("info", {})
    info.setdefault("title", default_title)
    info.setdefault("version", info.get("version") or "stg")
    path.write_text(json.dumps(data))
    print(f"{path}: {info.get('title')} v{info.get('version')} paths={len(data.get('paths', {}))}")

normalize(Path("docs/dist/admin/openapi.json"), "Trem Admin API")
normalize(Path("docs/dist/public/openapi.json"), "Trem Public API")
PY

SCALAR_JS="https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.74.0/dist/browser/standalone.js"

write_scalar_page() {
  local out="$1"
  local title="$2"
  local home_href="$3"
  cat > "$out" <<HTML
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>${title}</title>
    <style>
      html, body { margin: 0; height: 100%; background: #0f1117; color: #e8eaed; }
      #boot {
        font-family: ui-sans-serif, system-ui, sans-serif;
        padding: 1.5rem;
        max-width: 40rem;
      }
      #boot a { color: #8ab4ff; }
      #boot.hidden { display: none; }
      .top {
        position: sticky; top: 0; z-index: 50;
        display: flex; gap: 1rem; align-items: center;
        padding: 0.65rem 1rem;
        background: rgba(15,17,23,0.92);
        border-bottom: 1px solid rgba(255,255,255,0.08);
        font-family: ui-sans-serif, system-ui, sans-serif;
        font-size: 0.9rem;
      }
      .top a { color: #8ab4ff; text-decoration: none; }
      .top strong { color: #fff; font-weight: 600; }
    </style>
  </head>
  <body>
    <nav class="top">
      <a href="${home_href}">← All APIs</a>
      <strong>${title}</strong>
    </nav>
    <div id="boot">
      <p>Loading ${title}…</p>
      <p>Raw spec: <a href="./openapi.json">openapi.json</a></p>
    </div>
    <script
      id="api-reference"
      data-url="./openapi.json"
      data-configuration='{"theme":"kepler","layout":"modern","hideModels":false,"showSidebar":true}'
    ></script>
    <script
      src="${SCALAR_JS}"
      onload="document.getElementById('boot')?.classList.add('hidden')"
      onerror="document.getElementById('boot').innerHTML='<p><strong>Failed to load Scalar CDN.</strong> Spec: <a href=./openapi.json>openapi.json</a></p>'"
    ></script>
  </body>
</html>
HTML
}

write_scalar_page "docs/dist/admin/index.html" "Trem Admin API" "../"
write_scalar_page "docs/dist/public/index.html" "Trem Public API" "../"

cat > docs/dist/index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Trem API Docs</title>
    <style>
      :root {
        --bg: #0f1117;
        --fg: #e8eaed;
        --muted: #9aa3b2;
        --card: #171a22;
        --line: rgba(255,255,255,0.08);
        --accent: #8ab4ff;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        font-family: ui-sans-serif, system-ui, -apple-system, sans-serif;
        background:
          radial-gradient(ellipse 80% 50% at 10% -10%, #1d3a66 0%, transparent 55%),
          radial-gradient(ellipse 60% 40% at 100% 0%, #3a2818 0%, transparent 50%),
          var(--bg);
        color: var(--fg);
      }
      main {
        width: min(720px, calc(100% - 2rem));
        margin: 0 auto;
        padding: 3.5rem 0 4rem;
      }
      h1 {
        font-size: clamp(1.75rem, 4vw, 2.25rem);
        margin: 0 0 0.5rem;
        letter-spacing: -0.02em;
      }
      .lead { color: var(--muted); line-height: 1.5; margin: 0 0 2rem; }
      .grid { display: grid; gap: 1rem; }
      @media (min-width: 640px) { .grid { grid-template-columns: 1fr 1fr; } }
      a.card {
        display: block;
        text-decoration: none;
        color: inherit;
        background: var(--card);
        border: 1px solid var(--line);
        border-radius: 12px;
        padding: 1.25rem 1.35rem;
        transition: border-color .15s ease, transform .15s ease;
      }
      a.card:hover { border-color: var(--accent); transform: translateY(-1px); }
      a.card h2 { margin: 0 0 0.4rem; font-size: 1.15rem; }
      a.card p { margin: 0; color: var(--muted); font-size: 0.92rem; line-height: 1.45; }
      a.card .tag {
        display: inline-block;
        margin-top: 0.85rem;
        font-size: 0.75rem;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--accent);
      }
      .links { margin-top: 2rem; font-size: 0.9rem; color: var(--muted); }
      .links a { color: var(--accent); }
    </style>
  </head>
  <body>
    <main>
      <h1>Trem API Docs</h1>
      <p class="lead">
        Two OpenAPI specs from staging. Pick Admin (CMS) or Public (mobile / consumer app).
      </p>
      <div class="grid">
        <a class="card" href="./admin/">
          <h2>Admin API</h2>
          <p>CMS / backoffice endpoints — shows, venues, tickets, articles, auth admin.</p>
          <span class="tag">/api/admin-docs-json</span>
        </a>
        <a class="card" href="./public/">
          <h2>Public API</h2>
          <p>Consumer app endpoints — auth, shows, booking, checkout, payments, push.</p>
          <span class="tag">/api/docs-json</span>
        </a>
      </div>
      <p class="links">
        <a href="./regression/">Regression report</a>
        ·
        <a href="https://github.com/dzariq/trem-api-platform/blob/main/docs/BEGINNER-GUIDE.md">Beginner guide</a>
        ·
        <a href="https://github.com/dzariq/trem-api">TypeScript SDK</a>
        ·
        <a href="https://github.com/dzariq/trem-api-platform">Platform repo</a>
      </p>
    </main>
  </body>
</html>
HTML

# Keep copies under docs/ for convenience in git
mkdir -p docs/admin docs/public
cp docs/dist/index.html docs/index.html
cp docs/dist/admin/index.html docs/admin/index.html
cp docs/dist/admin/openapi.json docs/admin/openapi.json
cp docs/dist/public/index.html docs/public/index.html
cp docs/dist/public/openapi.json docs/public/openapi.json
# Remove old single-file admin-only artifacts if present
rm -f docs/openapi-admin.json docs/dist/openapi-admin.json

echo "Docs built → docs/dist/"
echo "  Landing:  docs/dist/index.html"
echo "  Admin:    docs/dist/admin/"
echo "  Public:   docs/dist/public/"
