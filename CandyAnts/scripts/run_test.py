#!/usr/bin/env python3
"""
Headless test runner — Godot 헤드리스 테스트 씬 실행

Usage:
    python scripts/run_test.py <scene>                    # res:// 또는 로컬 경로
    python scripts/run_test.py tests/Stage03HeadlessTest.tscn
    python scripts/run_test.py res://tests/BlockerOverlapTest.tscn
    python scripts/run_test.py --import                   # 에셋/class_name import 1회 (씬 실행 전 부트스트랩)

Environment:
    GODOT_BIN — 강제 지정 (없으면 PATH → 알려진 후보 순으로 탐색)

Fresh clone bootstrap (한 번):
    # 신규 class_name 등록을 위한 project import 1회 실행. 새 atom/스크립트 추가 후에도 동일.
    "$GODOT_BIN" --headless --path . --import
    # 이후 run_test.py 실행 시 새 class_name이 인식됨.

Exit code: 테스트 씬이 get_tree().quit(N)으로 emit하는 N (0=PASS, 1=FAIL).
안전망: --quit-after 18000 (5분 @ 60fps). ⚠ 안전망 발동 시 Godot은 exit 0(=quit(0)=PASS와 동일)으로
종료하므로, 18000프레임을 초과하는 멀티런 테스트는 타임아웃이 PASS로 위장될 수 있다(false-green). 그런
솔버 하니스 실행은 exit-code가 아니라 stdout 마커/SOLVER_RESULT로 판정하는 tools/solver/try_solve.py를
거친다(run_test는 단일 테스트 씬 러너로 유지, 솔버 전용 로직을 여기 넣지 않음).
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 알려진 Godot 4.x 설치 후보 (Windows). 추가/이동되면 여기 갱신.
CANDIDATES: list[Path] = [
    Path("D:/Godot_v4.6.2-stable_win64_console.exe"),  # console = stdout 캡처 가능
    Path("D:/Godot_v4.6.2-stable_win64.exe"),
    Path.home() / "AppData/Local/Programs/Godot/Godot_console.exe",
    Path.home() / "AppData/Local/Programs/Godot/Godot.exe",
    Path("C:/Program Files/Godot/Godot_console.exe"),
    Path("C:/Program Files/Godot/Godot.exe"),
]

DEFAULT_QUIT_AFTER_FRAMES = 18000  # 5분 @ 60fps 안전망 (스테이지 완주 여유)


def find_godot() -> Path:
    env_bin = os.environ.get("GODOT_BIN")
    if env_bin:
        p = Path(env_bin)
        if p.exists():
            return p
        sys.exit(f"[run_test] GODOT_BIN={env_bin} 경로에 파일 없음")

    for name in ("godot", "godot4", "godot_console", "Godot_console"):
        which = shutil.which(name)
        if which:
            return Path(which)

    for c in CANDIDATES:
        if c.exists():
            return c

    sys.exit(
        "[run_test] Godot 바이너리를 찾을 수 없습니다.\n"
        "  - 환경변수 GODOT_BIN을 절대경로로 지정\n"
        "  - 또는 PATH에 godot/godot_console 등록\n"
        f"  - 확인된 후보: {[str(c) for c in CANDIDATES]}"
    )


def normalize_scene(arg: str) -> str:
    if arg.startswith("res://"):
        return arg
    return "res://" + arg.replace("\\", "/")


def run_import(godot: Path) -> int:
    # 에셋(.png 등) + 신규 class_name을 import. gitignore된 *.import / .godot/imported 캐시를
    # 클린 체크아웃/CI에서 재생성한다. verify가 새 리소스를 load하기 전 자가완결 부트스트랩으로 쓴다.
    cmd = [str(godot), "--headless", "--path", str(ROOT), "--import"]
    print(f"[run_test] godot={godot.name} action=import", flush=True)
    return subprocess.run(cmd, cwd=str(ROOT)).returncode


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 64

    if sys.argv[1] == "--import":
        return run_import(find_godot())

    scene = normalize_scene(sys.argv[1])
    extra_args = sys.argv[2:]

    godot = find_godot()
    cmd = [
        str(godot),
        "--headless",
        "--path", str(ROOT),
        "--quit-after", str(DEFAULT_QUIT_AFTER_FRAMES),
        scene,
        *extra_args,
    ]
    # SaveData 격리 — stage_cleared/failed를 발화하는 통합 테스트(Campaign*/GameFlow 등)가 실제
    # user://save.cfg(플레이어 진행)에 쓰지 않도록, 이 실행 전용 throwaway 저장 경로를 환경변수로 전달한다.
    # SaveData._ready가 CANDYANTS_SAVE_PATH를 읽어 그 경로를 사용한다(없으면 user://save.cfg 기본).
    # pid 기반 고유 경로 → 병렬 실행 시에도 충돌 없음. 실행 전후로 .cfg/.bak/.tmp 정리.
    env = os.environ.copy()
    save_path = Path(tempfile.gettempdir()) / f"candyants_test_save_{os.getpid()}.cfg"
    env["CANDYANTS_SAVE_PATH"] = str(save_path)

    def _cleanup_save() -> None:
        for suffix in ("", ".bak", ".tmp"):
            try:
                Path(str(save_path) + suffix).unlink()
            except FileNotFoundError:
                pass

    _cleanup_save()  # 이전 잔여 제거 — 결정적 fresh 시작.
    print(f"[run_test] godot={godot.name} scene={scene} save={save_path.name}", flush=True)
    try:
        proc = subprocess.run(cmd, cwd=str(ROOT), env=env)
        return proc.returncode
    finally:
        _cleanup_save()


if __name__ == "__main__":
    raise SystemExit(main())
