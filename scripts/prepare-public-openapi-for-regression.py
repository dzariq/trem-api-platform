#!/usr/bin/env python3
"""Normalize public OpenAPI so Schemathesis regression is less noisy.

- Ensures common error statuses (400/401/403/404) are documented
- Documents 503 for oauth when Google isn't configured
Writes artifacts/openapi-public-regression.json
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path


ERROR_BODY = {
    "description": "Error",
    "content": {
        "application/json": {
            "schema": {
                "type": "object",
                "additionalProperties": True,
            }
        }
    },
}


def ensure_response(op: dict, code: str, description: str) -> None:
    responses = op.setdefault("responses", {})
    if code in responses:
        return
    body = copy.deepcopy(ERROR_BODY)
    body["description"] = description
    responses[code] = body


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", default="openapi.json")
    ap.add_argument("--out", default="artifacts/openapi-public-regression.json")
    args = ap.parse_args()

    data = json.loads(Path(args.inp).read_text())
    touched = 0

    for path, methods in data.get("paths", {}).items():
        for method, op in methods.items():
            if method.startswith("x-") or not isinstance(op, dict):
                continue
            ensure_response(op, "400", "Bad request / validation error")
            ensure_response(op, "401", "Unauthorized")
            ensure_response(op, "403", "Forbidden")
            ensure_response(op, "404", "Not found")
            if path.endswith("/auth/oauth") and method == "post":
                ensure_response(op, "503", "OAuth provider not configured")
            touched += 1

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(data))
    print(f"Prepared {out} ({touched} operations enriched with error responses)")


if __name__ == "__main__":
    main()
