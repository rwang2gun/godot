#!/usr/bin/env python3
"""Phase 9 complete gate — verify assets/fonts/LICENSE.txt exists with required keywords."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REQUIRED = ["Jua", "Gaegu", "Open Font License"]
license_path = ROOT / "assets" / "fonts" / "LICENSE.txt"

if not license_path.exists():
    print(f"FAIL: {license_path} missing", file=sys.stderr)
    sys.exit(1)

content = license_path.read_text(encoding="utf-8")
missing = [k for k in REQUIRED if k not in content]
if missing:
    print(f"FAIL: missing keywords: {missing}", file=sys.stderr)
    sys.exit(1)

print("OK: LICENSE.txt has all required keywords")
