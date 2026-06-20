#!/usr/bin/env python3
"""
auto-solver — 스테이지 풀이/실행 통합 front-door.

`run_test.py`는 순수 테스트 씬 러너로 두고(기능 중심), "스테이지를 결정론 하니스로 실행해 무수정 게임
verdict(D4)를 얻는" 모든 솔버 경로를 여기로 모은다. verdict는 **항상 stdout의 SOLVER_RESULT(또는 테스트
PASS 마커)를 파싱**해 판정하므로, run_test의 `--quit-after` 안전망이 exit 0(=PASS와 동일)으로 끝나
멀티런 테스트의 타임아웃을 PASS로 위장하는 false-green이 **구조적으로 불가능**하다.

Subcommands:
    replay <plan.json>                  단일 플랜 결정론 리플레이 → 결과 JSON (run_plan.run_plan_file)
    selftest                            골든 + solve.json 회귀 게이트 (run_plan.selftest)
    search <stage_id> [--max-rollouts N]  닫힌-루프 탐색 (solve.solve)
    harness-test                        PlanRunner 불변식 회귀(PlanReplayHarnessTest)를 마커-파싱으로 신뢰 실행

replay/selftest/search는 기존 진입점(`scripts/run_plan.py`, `tools/solver/solve.py`)의 구현을 그대로
import해 위임한다(동작·결정론 불변). harness-test만 신규다.

Env: GODOT_BIN (run_test.py가 사용).
    CANDYANTS_HARNESS_QUIT_AFTER  harness-test의 --quit-after 프레임 budget(기본 120000). 가드 검증용 축소 가능.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

# 콘솔 코드페이지(cp949 등)와 무관하게 한글·기호(— ⚠ 등) print/write가 죽지 않도록 UTF-8 강제(Windows
# UnicodeEncodeError 방지, analyze.py와 동일). 게이트 명령이 인코딩 크래시로 끊겨 false-fail 나는 것 차단.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

HERE = Path(__file__).resolve().parent          # tools/solver
ROOT = HERE.parents[1]                            # .../CandyAnts
RUN_TEST = ROOT / "scripts" / "run_test.py"

# 기존 reliable 진입점을 그 아래로 정리(import-dispatch). 동작은 불변 — 게이트로 보호된 작동 솔버를 깨지 않음.
sys.path.insert(0, str(ROOT / "scripts"))         # run_plan.py
sys.path.insert(0, str(HERE))                     # solve.py, model.py
import run_plan                                    # noqa: E402  (scripts/run_plan.py)
import solve                                       # noqa: E402  (tools/solver/solve.py)

# ---------- harness-test (신규): PlanReplayHarnessTest를 exit-code가 아니라 PASS 마커로 판정 ----------
HARNESS_TEST_SCENE = "tests/PlanReplayHarnessTest.tscn"
HARNESS_TEST_PASS = "[PlanReplayHarnessTest] PASS"
HARNESS_TEST_FAIL = "[PlanReplayHarnessTest] FAIL"
DEFAULT_HARNESS_QUIT_AFTER = 120000               # 멀티런(>18000f 필요) 완주 여유. run_test 기본(18000)은 부족.


def harness_test() -> int:
    """PlanReplayHarnessTest(멀티런 PlanRunner 불변식 회귀)를 **신뢰 실행**한다.

    이 테스트는 한 씬에서 ~10개의 in-process 리플레이를 순차 수행해 18000프레임(run_test 기본 budget)을
    초과한다. run_test의 `--quit-after` 안전망이 먼저 발동하면 Godot이 exit 0(=`quit(0)`=PASS와 동일)으로
    종료 → 게이트가 "통과"로 오인(타임아웃 false-green). 여기선:
      1. `--fixed-fps 60` + 넉넉한 `--quit-after`(기본 120000)로 ~8s 완주(안전망 회피),
      2. **exit-code가 아니라 테스트가 직접 찍는 PASS 마커**를 파싱해 판정(마커 없음/FAIL 마커 = FAIL).
    """
    budget = os.environ.get("CANDYANTS_HARNESS_QUIT_AFTER", str(DEFAULT_HARNESS_QUIT_AFTER))
    env = os.environ.copy()
    env["CANDYANTS_DETERMINISTIC"] = "1"          # 테스트 내부에서도 강제하나 명시(결정론·프레임 일관)
    p = subprocess.run(
        [sys.executable, str(RUN_TEST), HARNESS_TEST_SCENE, "--fixed-fps", "60", "--quit-after", budget],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(ROOT), env=env,
    )
    out = p.stdout or ""
    sys.stdout.write(out)                          # 라이브 스트림은 잃지만 게이트엔 무해(완주 후 일괄 출력)
    if p.stderr:
        sys.stderr.write(p.stderr)
    sys.stdout.flush()
    if HARNESS_TEST_FAIL in out:
        print("[try_solve] harness-test FAIL — 테스트가 FAIL 마커 보고(불변식 회귀)", flush=True)
        return 1
    if HARNESS_TEST_PASS not in out:
        print("[try_solve] harness-test FAIL — PASS 마커 없음(--quit-after 안전망에 잘림? exit=%d, budget=%s). "
              "exit 0이어도 마커 없으면 신뢰 안 함 — 타임아웃 false-green 차단." % (p.returncode, budget), flush=True)
        return 1
    if p.returncode != 0:
        # 마커는 찍혔으나 이후 비정상 종료(teardown 크래시·엔진/래퍼 오류). 마커가 있다고 nonzero를 삼키면
        # *새로운* fail-open이 된다(codex R2). 타임아웃은 "exit 0 + 마커 없음"이라 위 분기로 잡히고, 여기선
        # "마커 + nonzero"를 잡는다 — **PASS = 마커 AND exit 0 둘 다** 요구.
        print("[try_solve] harness-test FAIL — PASS 마커는 있으나 exit=%d (마커 출력 후 비정상 종료). "
              "마커+exit0 둘 다 요구." % p.returncode, flush=True)
        return 1
    print("[try_solve] harness-test PASS — PASS 마커 + exit 0 확인(budget=%s)" % budget, flush=True)
    return 0


# ---------- replay / selftest / search: 기존 구현 위임 ----------
def replay(plan_arg: str) -> int:
    plan_path = Path(plan_arg)
    if not plan_path.is_absolute():
        plan_path = (Path.cwd() / plan_path).resolve()
    if not plan_path.exists():
        print("[try_solve] plan file not found: %s" % plan_path)
        return 1
    result = run_plan.run_plan_file(plan_path)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if (result.get("cleared") and int(result.get("saved", 0)) >= 1) else 1


def main() -> int:
    ap = argparse.ArgumentParser(prog="try_solve", description="auto-solver 스테이지 풀이/실행 front-door")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p_replay = sub.add_parser("replay", help="단일 플랜 결정론 리플레이 → 결과 JSON")
    p_replay.add_argument("plan", help="플랜 JSON 경로")

    sub.add_parser("selftest", help="골든 + solve.json 회귀 게이트")

    p_search = sub.add_parser("search", help="닫힌-루프 탐색(solve)")
    p_search.add_argument("stage_id", type=int)
    p_search.add_argument("--max-rollouts", type=int, default=10, help="롤아웃 상한(기본 10).")

    sub.add_parser("harness-test", help="PlanReplayHarnessTest를 마커-파싱으로 신뢰 실행")

    args = ap.parse_args()
    if args.cmd == "replay":
        return replay(args.plan)
    if args.cmd == "selftest":
        return run_plan.selftest()
    if args.cmd == "search":
        return solve.solve(args.stage_id, args.max_rollouts)
    if args.cmd == "harness-test":
        return harness_test()
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
