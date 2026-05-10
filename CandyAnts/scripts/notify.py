#!/usr/bin/env python3
"""
Discord webhook notifier for user-attention events.

Usage:
    python scripts/notify.py "message"
    echo "message" | python scripts/notify.py

Requires env var DISCORD_WEBHOOK_URL.

Send notes only at branchpoints, completions, or blockers — not per-step
progress. Discord supports up to 2000 chars; code blocks (```...```) render.
"""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

WEBHOOK_ENV = "DISCORD_WEBHOOK_URL"
MAX_LEN = 2000

ROOT = Path(__file__).resolve().parent.parent
DOTENV_FILES = (ROOT / ".env.local", ROOT / ".env")  # .env.local takes precedence


def _load_dotenv() -> str | None:
    """Read DISCORD_WEBHOOK_URL from project-local .env / .env.local (gitignored).

    Single-purpose minimal parser — handles `KEY=value` lines, ignores comments
    and blanks, strips surrounding quotes. Real shell `export` syntax not parsed.
    """
    for path in DOTENV_FILES:
        if not path.exists():
            continue
        try:
            for raw in path.read_text(encoding="utf-8").splitlines():
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                key, _, value = line.partition("=")
                if key.strip() != WEBHOOK_ENV:
                    continue
                v = value.strip()
                if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
                    v = v[1:-1]
                if v:
                    return v
        except OSError:
            continue
    return None


def main() -> int:
    # Env var takes precedence; fall back to project-local .env / .env.local.
    url = os.environ.get(WEBHOOK_ENV) or _load_dotenv()
    if not url:
        print(
            f"error: {WEBHOOK_ENV} not set (env var or .env / .env.local at {ROOT})",
            file=sys.stderr,
        )
        return 2

    if len(sys.argv) > 1:
        message = " ".join(sys.argv[1:])
    else:
        message = sys.stdin.read().strip()

    if not message:
        print("error: empty message", file=sys.stderr)
        return 2

    if len(message) > MAX_LEN:
        message = message[: MAX_LEN - 20] + "\n…(truncated)"

    payload = json.dumps({"content": message}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={
            "Content-Type": "application/json; charset=utf-8",
            "User-Agent": "CandyAnts-Notifier/1.0 (+https://github.com/)",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if 200 <= resp.status < 300:
                print(f"ok ({resp.status})")
                return 0
            print(f"error: HTTP {resp.status}", file=sys.stderr)
            return 1
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"error: HTTP {e.code} — {body}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"error: {e.reason}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
