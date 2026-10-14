#!/usr/bin/env python3
"""Build a simple HTML UI from Schemathesis JUnit XML (+ optional log)."""
from __future__ import annotations

import argparse
import html
import os
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path


def parse_junit(path: Path) -> dict:
    root = ET.parse(path).getroot()
    # Root may be testsuites or testsuite
    suites = []
    if root.tag == "testsuites":
        suites = list(root.findall("testsuite"))
        totals = {
            "tests": int(root.attrib.get("tests") or 0),
            "failures": int(root.attrib.get("failures") or 0),
            "errors": int(root.attrib.get("errors") or 0),
            "time": float(root.attrib.get("time") or 0),
        }
    else:
        suites = [root]
        totals = {
            "tests": int(root.attrib.get("tests") or 0),
            "failures": int(root.attrib.get("failures") or 0),
            "errors": int(root.attrib.get("errors") or 0),
            "time": float(root.attrib.get("time") or 0),
        }

    cases = []
    for suite in suites:
        for case in suite.findall("testcase"):
            failure = case.find("failure")
            error = case.find("error")
            status = "passed"
            detail = ""
            if failure is not None:
                status = "failed"
                detail = failure.attrib.get("message") or (failure.text or "")
            elif error is not None:
                status = "error"
                detail = error.attrib.get("message") or (error.text or "")
            cases.append(
                {
                    "name": case.attrib.get("name") or "(unnamed)",
                    "time": float(case.attrib.get("time") or 0),
                    "status": status,
                    "detail": detail.strip(),
                }
            )

    if not totals["tests"] and cases:
        totals["tests"] = len(cases)
        totals["failures"] = sum(1 for c in cases if c["status"] == "failed")
        totals["errors"] = sum(1 for c in cases if c["status"] == "error")
        totals["time"] = sum(c["time"] for c in cases)

    return {"totals": totals, "cases": cases}


def short_detail(text: str, limit: int = 400) -> str:
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) <= limit:
        return text
    return text[: limit - 1] + "…"


def render(data: dict, meta: dict) -> str:
    t = data["totals"]
    passed = t["tests"] - t["failures"] - t["errors"]
    failed = t["failures"] + t["errors"]
    rate = (passed / t["tests"] * 100) if t["tests"] else 0
    overall = "pass" if failed == 0 else "fail"

    rows = []
    for c in sorted(data["cases"], key=lambda x: (0 if x["status"] == "passed" else 1, x["name"])):
        detail_html = ""
        if c["detail"]:
            detail_html = f'<pre class="detail">{html.escape(short_detail(c["detail"]))}</pre>'
        rows.append(
            f"""
            <tr class="{c['status']}">
              <td><span class="badge {c['status']}">{c['status']}</span></td>
              <td><code>{html.escape(c['name'])}</code>{detail_html}</td>
              <td class="num">{c['time']:.2f}s</td>
            </tr>
            """
        )

    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Trem API Regression Report</title>
  <style>
    :root {{
      --bg: #0f1117; --fg: #e8eaed; --muted: #9aa3b2; --card: #171a22;
      --line: rgba(255,255,255,.08); --pass: #3dd68c; --fail: #ff6b6b; --accent: #8ab4ff;
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0; font-family: ui-sans-serif, system-ui, sans-serif;
      background: radial-gradient(ellipse 70% 40% at 0% 0%, #1d3a66 0%, transparent 50%), var(--bg);
      color: var(--fg); min-height: 100vh;
    }}
    main {{ width: min(960px, calc(100% - 2rem)); margin: 0 auto; padding: 2.5rem 0 4rem; }}
    a {{ color: var(--accent); }}
    h1 {{ margin: 0 0 .35rem; font-size: 1.75rem; letter-spacing: -.02em; }}
    .meta {{ color: var(--muted); font-size: .9rem; margin-bottom: 1.5rem; line-height: 1.5; }}
    .cards {{ display: grid; grid-template-columns: repeat(4, 1fr); gap: .75rem; margin-bottom: 1.5rem; }}
    @media (max-width: 720px) {{ .cards {{ grid-template-columns: 1fr 1fr; }} }}
    .card {{ background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 1rem; }}
    .card .label {{ color: var(--muted); font-size: .75rem; text-transform: uppercase; letter-spacing: .06em; }}
    .card .value {{ font-size: 1.6rem; font-weight: 700; margin-top: .25rem; }}
    .card.pass .value {{ color: var(--pass); }}
    .card.fail .value {{ color: var(--fail); }}
    .banner {{
      border-radius: 12px; padding: .85rem 1rem; margin-bottom: 1.25rem;
      border: 1px solid var(--line); background: var(--card);
    }}
    .banner.pass {{ border-color: rgba(61,214,140,.35); }}
    .banner.fail {{ border-color: rgba(255,107,107,.4); }}
    table {{ width: 100%; border-collapse: collapse; background: var(--card); border-radius: 12px; overflow: hidden; }}
    th, td {{ text-align: left; padding: .75rem .9rem; border-bottom: 1px solid var(--line); vertical-align: top; }}
    th {{ color: var(--muted); font-size: .75rem; text-transform: uppercase; letter-spacing: .05em; }}
    tr:last-child td {{ border-bottom: 0; }}
    .num {{ white-space: nowrap; color: var(--muted); width: 5rem; }}
    .badge {{
      display: inline-block; padding: .15rem .45rem; border-radius: 999px;
      font-size: .7rem; text-transform: uppercase; letter-spacing: .04em; font-weight: 700;
    }}
    .badge.passed {{ background: rgba(61,214,140,.15); color: var(--pass); }}
    .badge.failed, .badge.error {{ background: rgba(255,107,107,.15); color: var(--fail); }}
    pre.detail {{
      margin: .5rem 0 0; white-space: pre-wrap; word-break: break-word;
      color: var(--muted); font-size: .78rem; line-height: 1.4;
      font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    }}
    code {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: .85rem; }}
    .filters {{ margin: 0 0 1rem; display: flex; gap: .5rem; flex-wrap: wrap; }}
    .filters button {{
      background: var(--card); border: 1px solid var(--line); color: var(--fg);
      border-radius: 999px; padding: .35rem .8rem; cursor: pointer; font: inherit; font-size: .85rem;
    }}
    .filters button.active {{ border-color: var(--accent); color: var(--accent); }}
    tr.hide {{ display: none; }}
  </style>
</head>
<body>
  <main>
    <h1>Trem API regression</h1>
    <p class="meta">
      Generated {html.escape(meta.get("generated", ""))}<br/>
      Base URL: <code>{html.escape(meta.get("base_url", ""))}</code><br/>
      Spec: <code>{html.escape(meta.get("spec", ""))}</code>
      · Auth: <code>{html.escape(meta.get("auth", "none"))}</code><br/>
      <a href="../">← Docs home</a>
      · <a href="https://github.com/dzariq/trem-api-platform/actions">GitHub Actions</a>
    </p>

    <div class="banner {overall}">
      <strong>{"All checks passed" if overall == "pass" else "Failures detected"}</strong>
      — {passed} passed / {failed} failed · {rate:.0f}% pass rate · {t["time"]:.1f}s
    </div>

    <div class="cards">
      <div class="card"><div class="label">Tests</div><div class="value">{t["tests"]}</div></div>
      <div class="card pass"><div class="label">Passed</div><div class="value">{passed}</div></div>
      <div class="card fail"><div class="label">Failed</div><div class="value">{failed}</div></div>
      <div class="card"><div class="label">Duration</div><div class="value" style="font-size:1.25rem">{t["time"]:.1f}s</div></div>
    </div>

    <div class="filters">
      <button type="button" class="active" data-filter="all">All</button>
      <button type="button" data-filter="failed">Failed only</button>
      <button type="button" data-filter="passed">Passed only</button>
    </div>

    <table>
      <thead><tr><th>Status</th><th>Operation</th><th>Time</th></tr></thead>
      <tbody>
        {"".join(rows)}
      </tbody>
    </table>
  </main>
  <script>
    document.querySelectorAll('.filters button').forEach(btn => {{
      btn.addEventListener('click', () => {{
        document.querySelectorAll('.filters button').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        const f = btn.dataset.filter;
        document.querySelectorAll('tbody tr').forEach(tr => {{
          const st = tr.classList.contains('passed') ? 'passed' : 'failed';
          tr.classList.toggle('hide', f !== 'all' && f !== st && !(f === 'failed' && (tr.classList.contains('failed') || tr.classList.contains('error'))));
        }});
      }});
    }});
  </script>
</body>
</html>
"""


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--junit", default="artifacts/schemathesis-junit.xml")
    ap.add_argument("--out-dir", default="artifacts/regression-report")
    ap.add_argument("--base-url", default=os.environ.get("TREM_API_BASE_URL", ""))
    ap.add_argument("--spec", default="openapi-admin.json")
    args = ap.parse_args()

    junit = Path(args.junit)
    if not junit.is_file():
        raise SystemExit(f"Missing JUnit report: {junit}")

    data = parse_junit(junit)
    auth = "admin bearer" if os.environ.get("TREM_ADMIN_EMAIL") else "none (expect many 401s)"
    meta = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC"),
        "base_url": args.base_url or "https://tremstgapi.axcova.com",
        "spec": args.spec,
        "auth": auth,
    }

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "index.html").write_text(render(data, meta), encoding="utf-8")
    # Keep raw junit next to the UI
    (out_dir / "schemathesis-junit.xml").write_bytes(junit.read_bytes())
    print(f"Wrote {out_dir / 'index.html'}")
    print(
        f"Summary: {data['totals']['tests']} tests, "
        f"{data['totals']['failures']} failures, {data['totals']['errors']} errors"
    )


if __name__ == "__main__":
    main()
