#!/usr/bin/env python3
"""RL 학습·검증 쉬운 실행 런처 — train.py의 긴 플래그를 감싼 얇은 wrapper.

CandyAnts 폴더 어디서든:
    python tools/solver/rl/rl.py 12          # stage 12 학습 (1 seed, 표준 설정)
    python tools/solver/rl/rl.py 12 -s 3     # 3 seed(0,1,2) pinned
    python tools/solver/rl/rl.py 12 --smoke  # 빠른 스모크(600s, 미저장)
    python tools/solver/rl/rl.py --verify 11 # 기존 해 검증(verify-r2)
    python tools/solver/rl/rl.py --all        # 1~25 순차 학습(각 --smoke 아님)
    python tools/solver/rl/rl.py --list       # 스테이지별 해/기록 현황

자동 처리:
  - PYTHONUTF8=1 (Windows 콘솔 한글 깨짐 방지)
  - .godot 없으면 자동 재임포트(SkillRegistry=<null> 실패 예방)
  - godot 바이너리 자동 탐색(run_test.find_godot)
  - 해 발견 시 data/solutions/found/ 자동 기록(train.py _record_found)

표준 학습 설정: --envs 4 --max-episodes 20000 --max-wall 1800 --shaping trace
                --train-deadline 4500 --sil  (train.py docstring의 R1-스윕과 동일)
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent            # tools/solver/rl
ROOT = HERE.parents[2]                             # .../CandyAnts
TRAIN = HERE / "train.py"
FOUND_DIR = ROOT / "data" / "solutions" / "found"
SOLUTIONS = ROOT / "data" / "solutions"

# 표준 학습 플래그(값만 — stage/seeds는 호출부에서 주입)
STD = ["--envs", "4", "--max-episodes", "20000", "--max-wall", "1800",
       "--shaping", "trace", "--train-deadline", "4500", "--sil"]


def _find_godot() -> str | None:
    sys.path.insert(0, str(ROOT / "scripts"))
    try:
        from run_test import find_godot          # type: ignore
        return str(find_godot())
    except Exception:
        return None


def _ensure_godot_import() -> None:
    """.godot(임포트/클래스 캐시)가 없으면 재생성 — 없으면 헤드리스가 SkillRegistry=<null>로 실패."""
    if (ROOT / ".godot").is_dir():
        return
    godot = _find_godot()
    if not godot:
        print("[rl] 경고: godot 바이너리를 못 찾음 — GODOT_BIN 지정 또는 run_test.py CANDIDATES 갱신 필요")
        return
    print("[rl] .godot 없음 → 재임포트(최초 1회, 30~60s)…")
    subprocess.run([godot, "--headless", "--import", "--path", str(ROOT)],
                   cwd=str(ROOT))


def _env() -> dict:
    e = os.environ.copy()
    e["PYTHONUTF8"] = "1"
    return e


def _run_train(extra: list[str]) -> int:
    _ensure_godot_import()
    cmd = [sys.executable, str(TRAIN), *extra]
    print("[rl] $", " ".join(cmd[1:]))
    return subprocess.run(cmd, cwd=str(ROOT), env=_env()).returncode


def _seeds_arg(n_or_list: str) -> str:
    """'3' → '0,1,2', '1' → '0', 콤마 포함 문자열은 그대로."""
    if "," in n_or_list:
        return n_or_list
    n = int(n_or_list)
    return ",".join(str(i) for i in range(n))


def cmd_list() -> int:
    print("stage | found(RL발견) | rl*.json | solve.json")
    print("------+--------------+----------+-----------")
    for s in range(1, 26):
        found = sorted(FOUND_DIR.glob(f"stage{s:02d}_seed*.found.json")) if FOUND_DIR.is_dir() else []
        rl = sorted(SOLUTIONS.glob(f"stage{s:02d}.rl*.json"))
        solve = (SOLUTIONS / f"stage{s:02d}.solve.json").exists()
        fmark = f"{len(found)}건" if found else "-"
        rlmark = ",".join(p.name.split(".")[1] for p in rl) if rl else "-"
        smark = "O" if solve else "-"
        print(f"  {s:2d}  | {fmark:>12} | {rlmark:>8} | {smark:^9}")
    if FOUND_DIR.is_dir() and (FOUND_DIR / "log.jsonl").exists():
        n = sum(1 for _ in open(FOUND_DIR / "log.jsonl", encoding="utf-8"))
        print(f"\nfound/log.jsonl: 누적 {n}건 발견 기록")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="RL 학습·검증 쉬운 실행 런처",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="예: python tools/solver/rl/rl.py 12 -s 3   |   --verify 11   |   --list")
    ap.add_argument("stage", nargs="?", type=int, help="학습할 스테이지 번호(1~25)")
    ap.add_argument("-s", "--seeds", default="1",
                    help="seed 개수(1→'0', 3→'0,1,2') 또는 '0,1,2' 직접 (기본 1)")
    ap.add_argument("--smoke", action="store_true",
                    help="빠른 스모크: max-wall 600s + 미저장(게이트 산출물 안 건드림)")
    ap.add_argument("--wall", type=int, help="max-wall(초) 덮어쓰기")
    ap.add_argument("--verify", type=int, metavar="N", help="stage N 기존 해 검증(verify-r2)")
    ap.add_argument("--all", action="store_true", help="1~25 순차 학습")
    ap.add_argument("--list", action="store_true", help="스테이지별 해/기록 현황")
    ap.add_argument("rest", nargs="*", help="train.py로 그대로 전달할 추가 플래그")
    args = ap.parse_args()

    if args.list:
        return cmd_list()

    if args.verify is not None:
        return _run_train(["--verify-r2", "--stage", str(args.verify), *args.rest])

    if args.all:
        rc = 0
        for s in range(1, 26):
            print(f"\n===== stage {s} 학습 =====")
            extra = ["--stage", str(s), "--seeds", "0", *STD, *args.rest]
            r = _run_train(extra)
            rc = rc or r
        print("\n[rl] --all 완료. 결과: data/solutions/found/log.jsonl")
        return rc

    if args.stage is None:
        ap.print_help()
        return 2

    extra = ["--stage", str(args.stage), "--seeds", _seeds_arg(args.seeds), *STD]
    if args.wall:
        extra = _replace_flag(extra, "--max-wall", str(args.wall))
    if args.smoke:
        extra = _replace_flag(extra, "--max-wall", "600") + ["--no-save"]
    extra += args.rest
    return _run_train(extra)


def _replace_flag(argv: list[str], flag: str, val: str) -> list[str]:
    out = list(argv)
    if flag in out:
        out[out.index(flag) + 1] = val
    else:
        out += [flag, val]
    return out


if __name__ == "__main__":
    raise SystemExit(main())
