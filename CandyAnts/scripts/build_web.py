#!/usr/bin/env python3
"""
Web 빌드 — Godot "Web" 프리셋 export + itch.io 업로드용 zip 생성을 한 번에.

Usage:
    python scripts/build_web.py            # export-release → build/web/, 이어서 zip 생성
    python scripts/build_web.py --debug    # export-debug (디버그 템플릿)

Environment:
    GODOT_BIN — 강제 지정 (없으면 run_test.find_godot 탐색 로직 재사용)

산출물:
    build/web/index.html (+ .js/.pck/.wasm 등)  — Godot export 원본
    build/web/CandyAnts-web.zip                  — itch.io 업로드용 (index.html이 zip 루트)

zip에는 *.import 사이드카와 zip 자기 자신을 제외한 build/web/ 의 모든 파일을 담는다.
itch.io는 아카이브 루트의 index.html을 자동 인식하므로 폴더가 아닌 파일들을 루트에 넣는다.
"""
from __future__ import annotations

import subprocess
import sys
import zipfile
from pathlib import Path

# run_test의 godot 탐색·ROOT를 단일 SoT로 재사용 (후보 경로 중복 정의 방지).
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_test import ROOT, find_godot  # noqa: E402

PRESET = "Web"
OUT_DIR = ROOT / "build" / "web"
OUT_HTML = OUT_DIR / "index.html"
ZIP_PATH = OUT_DIR / "CandyAnts-web.zip"


def export(debug: bool) -> int:
    godot = find_godot()
    flag = "--export-debug" if debug else "--export-release"
    cmd = [str(godot), "--headless", "--path", str(ROOT), flag, PRESET, str(OUT_HTML)]
    print(f"[build_web] godot={godot.name} {flag} preset={PRESET!r} -> {OUT_HTML}", flush=True)
    return subprocess.run(cmd, cwd=str(ROOT)).returncode


def make_zip() -> None:
    if not OUT_HTML.exists():
        sys.exit(f"[build_web] export 산출물 없음: {OUT_HTML}")

    # *.import 사이드카와 기존 zip 제외. 파일을 zip 루트에 평면 배치.
    files = sorted(
        p for p in OUT_DIR.iterdir()
        if p.is_file() and p.suffix != ".import" and p != ZIP_PATH
    )
    if ZIP_PATH.exists():
        ZIP_PATH.unlink()  # 결정적 재생성 (스테일 잔여 방지).

    with zipfile.ZipFile(ZIP_PATH, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in files:
            zf.write(f, arcname=f.name)

    size_mb = ZIP_PATH.stat().st_size / (1024 * 1024)
    print(f"[build_web] zip 생성: {ZIP_PATH} ({size_mb:.1f} MB, {len(files)}개 파일)", flush=True)


def main() -> int:
    debug = "--debug" in sys.argv[1:]
    rc = export(debug)
    if rc != 0:
        print(f"[build_web] export 실패 (rc={rc}) — zip 생략", flush=True)
        return rc
    make_zip()
    print("[build_web] DONE", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
