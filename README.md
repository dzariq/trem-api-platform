# Trem API Platform (provider toolkit)

OpenAPI sync, **Scalar docs**, **auto changelog draft** (`oasdiff`), **Schemathesis regression**, and hooks to regenerate **`@dzariq/trem-api`**.

Published SDK: https://github.com/dzariq/trem-api  
This repo (platform): push as `dzariq/trem-api-platform` (see below).

## What you get

| # | Need | Command / CI |
|---|------|----------------|
| 1 | Auto changelog draft | `npm run changelog:diff` → `openapi/CHANGELOG.draft.md` |
| 2 | Auto regression vs schema | `npm run test:regression` (+ GitHub Action) |
| 3 | Auto update when API OpenAPI changes | weekday cron workflow + PR |
| 4 | Detailed docs | `npm run docs:build` / `docs:serve` → Scalar UI |

## Quick start

```bash
cd fern-sdk
cp .env.example .env   # optional: admin email/password for auth tests

npm run fetch:openapi      # pull stg admin OpenAPI + snapshot
npm run changelog:diff     # oasdiff (needs Docker)
npm run docs:build && npm run docs:serve   # http://localhost:4173
npm run test:regression    # Schemathesis (soft-fail by default)
```

With auth for better coverage:

```bash
export TREM_ADMIN_EMAIL='you@trem.com'
export TREM_ADMIN_PASSWORD='…'
npm run test:regression
```

Strict CI (fail on schema violations):

```bash
STRICT_REGRESSION=1 npm run test:regression
```

## Release SDK after OpenAPI changes

```bash
npm run fetch:openapi
npm run changelog:diff
# review openapi/CHANGELOG.draft.md → copy into sdks/typescript/CHANGELOG.md

fern login   # once
fern generate --group local

./scripts/release-sdk.sh 0.1.1
```

## GitHub setup

Repo: **https://github.com/dzariq/trem-api-platform**

1. Enable Actions workflows (needs `workflow` scope once):

```bash
gh auth refresh -h github.com -s workflow,write:packages
mkdir -p .github/workflows
cp ci-templates/*.yml .github/workflows/
git add .github/workflows && git commit -m "Enable CI workflows" && git push
```

2. Enable **GitHub Pages** → Source: **GitHub Actions**
3. Repo **Secrets**: `TREM_ADMIN_EMAIL`, `TREM_ADMIN_PASSWORD` (regression)
4. Repo **Variables** (optional): `TREM_API_BASE_URL`, `STRICT_REGRESSION=1`

CI templates (copy into `.github/workflows/`):

- `ci-templates/sync-openapi.yml` — fetch OpenAPI, changelog, docs, open PR if changed
- `ci-templates/regression.yml` — Schemathesis against stg
- `ci-templates/docs-pages.yml` — deploy Scalar docs to GitHub Pages

## Layout

| Path | What |
|------|------|
| `openapi-admin.json` | Current Admin OpenAPI snapshot |
| `openapi/snapshots/` | Previous snapshot for diffs |
| `docs/` / `docs/dist/` | Scalar API reference |
| `artifacts/` | Changelog draft + Schemathesis reports |
| `fern/` | Fern generators |
| `scripts/` | fetch / changelog / docs / regression / SDK release |
| `sdks/typescript/` | Separate git repo → `@dzariq/trem-api` (gitignored here) |
