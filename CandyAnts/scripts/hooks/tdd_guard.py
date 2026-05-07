#!/usr/bin/env python3
"""
TDD Guard — 구현 파일 수정 시 대응 테스트 파일 존재 확인. 없으면 BLOCK.

대상: scripts/{core,ant,skills,world,ui}/*.gd 의 Write/Edit/MultiEdit
검증: tests/ 어딘가에 test_{stem}.gd 가 있어야 함

우회 방법:
  - 환경변수 TDD_GUARD_BYPASS=1
  - 또는 scripts/hooks/.tdd_bypass 파일 존재 시 (Phase 1 셋업 등 초기 단계용)

Exit code:
  0 = 통과 / 우회
  2 = block (Claude에 stderr 메시지 표시)
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

GUARDED_DIRS = {"core", "ant", "skills", "world", "ui"}
PROJECT_ROOT = Path(__file__).resolve().parents[2]
BYPASS_FILE = PROJECT_ROOT / "scripts" / "hooks" / ".tdd_bypass"


def main() -> int:
    if os.environ.get("TDD_GUARD_BYPASS") == "1":
        return 0
    if BYPASS_FILE.exists():
        return 0

    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0  # 파싱 실패 시 통과

    if payload.get("tool_name") not in ("Write", "Edit", "MultiEdit"):
        return 0

    file_path = payload.get("tool_input", {}).get("file_path", "")
    if not file_path:
        return 0

    p = Path(file_path)
    parts = p.parts
    if "scripts" not in parts:
        return 0

    scripts_idx = parts.index("scripts")
    if scripts_idx + 1 >= len(parts):
        return 0

    sub = parts[scripts_idx + 1]
    if sub not in GUARDED_DIRS or p.suffix != ".gd":
        return 0

    if p.stem.startswith("test_"):
        return 0

    test_name = f"test_{p.stem}.gd"
    test_root = PROJECT_ROOT / "tests"
    matches = list(test_root.rglob(test_name)) if test_root.exists() else []

    if not matches:
        sys.stderr.write(
            f"BLOCKED by TDD Guard\n"
            f"  파일: {p.name}\n"
            f"  필요: tests/.../{test_name}\n"
            f"  먼저 테스트를 작성하거나, 우회하려면:\n"
            f"    - 환경변수 TDD_GUARD_BYPASS=1\n"
            f"    - 또는 'touch scripts/hooks/.tdd_bypass'\n"
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
