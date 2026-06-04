#!/usr/bin/env python3
"""
Godot 에디터 런처 — 레벨 에디터(CandyAnts Level dock)를 쓰기 위해 이 프로젝트를 에디터로 연다.

Usage:
    python scripts/run_editor.py            # Godot 에디터로 프로젝트 열기
    python scripts/run_editor.py --print    # 사용할 Godot 바이너리만 출력(실행 안 함)

레벨 에디터 위치:
    에디터 하단 패널 `CandyAnts Level`  또는  메뉴 `Project > Tools > CandyAnts Level Tool`.

Godot 탐색 순서 (run_test.py와 동일 + Downloads 등 재귀 폴백):
    GODOT_BIN → PATH(godot/godot_console 등) → 알려진 후보 → 흔한 폴더 재귀 스캔.
    못 찾으면 GODOT_BIN 환경변수를 절대경로로 지정하세요.
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

# run_test.py의 후보 목록 재사용 (단일 SoT).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_test import CANDIDATES, ROOT  # noqa: E402

# 콘솔 빌드를 우선(stdout 캡처). 일반 빌드도 허용.
_PREFER_CONSOLE = ("console", "Godot_console")

# 재귀 폴백으로 훑을 흔한 설치/다운로드 위치 (depth 제한).
_SCAN_DIRS: list[Path] = [
    Path.home() / "Downloads",
    Path.home() / "Desktop",
    Path("D:/"),
    Path("C:/Program Files/Godot"),
    Path.home() / "AppData/Local/Programs/Godot",
]
_SCAN_MAX_DEPTH = 3


def _scan_for_godot() -> Path | None:
    """흔한 폴더에서 Godot*.exe를 재귀로 찾는다. console 빌드를 우선 반환."""
    found: list[Path] = []
    for base in _SCAN_DIRS:
        if not base.exists():
            continue
        for path in base.rglob("Godot*.exe"):
            try:
                depth = len(path.relative_to(base).parts) - 1
            except ValueError:
                continue
            if depth <= _SCAN_MAX_DEPTH and path.is_file():
                found.append(path)
    if not found:
        return None
    found.sort(key=lambda p: (0 if any(tag in p.name for tag in _PREFER_CONSOLE) else 1, len(str(p))))
    return found[0]


def find_godot() -> Path:
    env_bin = os.environ.get("GODOT_BIN")
    if env_bin:
        p = Path(env_bin)
        if p.exists() and p.is_file():
            return p
        sys.exit(f"[run_editor] GODOT_BIN={env_bin} 경로에 파일 없음")

    for name in ("godot", "godot4", "godot_console", "Godot_console"):
        which = shutil.which(name)
        if which:
            return Path(which)

    for c in CANDIDATES:
        if c.exists() and c.is_file():
            return c

    scanned = _scan_for_godot()
    if scanned is not None:
        return scanned

    sys.exit(
        "[run_editor] Godot 바이너리를 찾을 수 없습니다.\n"
        "  - 환경변수 GODOT_BIN을 절대경로로 지정 (예: set GODOT_BIN=C:\\path\\to\\Godot_console.exe)\n"
        "  - 또는 PATH에 godot/godot_console 등록\n"
        f"  - 스캔한 폴더: {[str(d) for d in _SCAN_DIRS if d.exists()]}"
    )


def main() -> int:
    godot = find_godot()
    if "--print" in sys.argv[1:]:
        print(str(godot))
        return 0

    cmd = [str(godot), "--editor", "--path", str(ROOT)]
    print(f"[run_editor] godot={godot.name} → 프로젝트를 에디터로 엽니다…", flush=True)
    print("[run_editor] 레벨 에디터: 하단 패널 'CandyAnts Level' 또는 Project > Tools > CandyAnts Level Tool", flush=True)
    # 에디터는 장시간 GUI이므로 분리 실행하고 런처는 즉시 반환.
    subprocess.Popen(cmd, cwd=str(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
