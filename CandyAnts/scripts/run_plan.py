#!/usr/bin/env python3
"""
auto-solver Phase 1 — 플랜 리플레이 CLI.

플랜(JSON)을 헤드리스(`--fixed-fps`, 결정론)로 실제 게임에 재생하고 무수정 게임 verdict를 보고한다(D4).
PlanReplayHarness 씬을 띄워 SOLVER_RESULT를 파싱한다. spike의 solve_spike.run_plan을 일반화.

NOTE: 통합 front-door는 `tools/solver/try_solve.py`(replay/selftest/search/harness-test). 이 모듈의
run_plan_file/selftest 구현은 거기서 import해 위임하므로 동작은 동일하다. 본 CLI는 back-compat로 유지.

Usage:
    GODOT_BIN=... python scripts/run_plan.py <plan.json>          # 단일 플랜 실행 → 결과 JSON 출력
    GODOT_BIN=... python scripts/run_plan.py --selftest           # data/solutions/golden/*.plan.json 골든 검증

--selftest: 골든(Phase 1 손작성 메커니즘, golden/*.plan.json) + solve(Phase 2 자동발견 해,
  solutions/*.solve.json)를 모두 실행해 각 "expect"와 무수정 게임 verdict가 일치하는지 단언한다.
  다중 스킬(ANT 대상 blocker, CELL 대상 SIGN/DEVICE) + 양성/음성 + **자동발견 해의 CI 회귀 게이트**
  (엔진/스킬 변경이 확보된 해를 깨면 여기서 잡힌다, D4). 하나라도 어긋나면 exit 1.

Env: GODOT_BIN (run_test.py가 사용). 항상 CANDYANTS_DETERMINISTIC=1 + --fixed-fps 60로 실행(결정론·가속).
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent      # .../CandyAnts
RUN_TEST = ROOT / "scripts" / "run_test.py"
HARNESS_SCENE = "tests/PlanReplayHarness.tscn"
GOLDEN_DIR = ROOT / "data" / "solutions" / "golden"
SOLUTIONS_DIR = ROOT / "data" / "solutions"
# Phase 2 자동발견 해의 **최소 기대 집합** — 이 중 하나라도 solve.json이 없으면 게이트 FAIL(fail-closed,
# codex Phase 2 리뷰 R1-HIGH). golden만으로 통과하거나 solve 파일 실수 삭제가 조용히 지나가는 fail-open
# 차단. 새 해(S15+) 추가 시 여기에 등재 — 그래야 회귀 게이트가 그 해도 강제한다.
EXPECTED_SOLVE_STAGES = (2, 3, 4, 11, 12, 13, 14)


def run_plan_file(plan_path: Path) -> dict:
    """플랜 파일을 헤드리스로 실행하고 SOLVER_RESULT dict를 반환."""
    env = os.environ.copy()
    env["CANDYANTS_PLAN_PATH"] = str(plan_path)
    env["CANDYANTS_DETERMINISTIC"] = "1"
    p = subprocess.run(
        [sys.executable, str(RUN_TEST), HARNESS_SCENE, "--fixed-fps", "60"],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        cwd=str(ROOT), env=env,
    )
    for line in (p.stdout or "").splitlines():
        if line.startswith("SOLVER_RESULT "):
            try:
                return json.loads(line[len("SOLVER_RESULT "):])
            except json.JSONDecodeError:
                pass
    return {"error": "no SOLVER_RESULT", "stdout_tail": (p.stdout or "")[-600:]}


def check_expect(result: dict, expect: dict) -> list[str]:
    """expect의 각 키를 result와 대조. 불일치 메시지 목록(빈 목록 = 통과)."""
    fails: list[str] = []
    if "error" in result:
        return ["harness error: %s" % result.get("error")]
    if "cleared" in expect and bool(result.get("cleared")) != bool(expect["cleared"]):
        fails.append("cleared: got %s want %s" % (result.get("cleared"), expect["cleared"]))
    if "saved" in expect and int(result.get("saved", -999)) != int(expect["saved"]):
        fails.append("saved: got %s want %s" % (result.get("saved"), expect["saved"]))
    if "min_saved" in expect and int(result.get("saved", -999)) < int(expect["min_saved"]):
        fails.append("saved: got %s want >=%s" % (result.get("saved"), expect["min_saved"]))
    if "actions_fired" in expect and int(result.get("actions_fired", -999)) != int(expect["actions_fired"]):
        fails.append("actions_fired: got %s want %s" % (result.get("actions_fired"), expect["actions_fired"]))
    if "reason" in expect and str(result.get("reason", "")) != str(expect["reason"]):
        fails.append("reason: got %r want %r" % (result.get("reason"), expect["reason"]))
    # effect-level 불변식 — 설치형(SIGN/DEVICE)이 "실제로 효과를 냈는지"를 핀(codex R1 MED-3).
    # 단순 actions_fired만으론 잘못 설치/미발동도 PASS될 수 있어, 무수정 게임이 관측한 효과를 단언한다.
    if "picked" in expect and bool(result.get("picked")) != bool(expect["picked"]):
        fails.append("picked: got %s want %s" % (result.get("picked"), expect["picked"]))
    if "max_best_min_y" in expect:
        bmy = float(result.get("best_min_y", 1e20))
        # best_min_y < 0 = 미측정(개미 없음) 센티넬 → 효과 없음으로 간주(FAIL).
        if bmy < 0 or bmy > float(expect["max_best_min_y"]):
            fails.append("best_min_y: got %s want measured & <= %s (설치 스킬 효과 미발생?)" % (
                result.get("best_min_y"), expect["max_best_min_y"]))
    return fails


def _solve_stage_id(path: Path) -> int | None:
    """`stageNN.solve.json` 파일명에서 stage id 추출(아니면 None)."""
    m = re.match(r"stage(\d+)\.solve\.json$", path.name)
    return int(m.group(1)) if m else None


def _solve_expect_invalid(expect: dict) -> str:
    """solve fixture의 expect가 **강한 계약**(cleared:true + saved 정수≥1)을 갖는지 검사. 위반 사유 문자열
    (없으면 ""). `check_expect`는 빈 expect를 통과시키므로, 자동발견 해엔 이 계약을 사전 강제해 verdict-only
    fail-open(codex Phase 2 R1-HIGH)을 막는다. bool은 int 하위형이라 saved=True 같은 위장도 거부."""
    if not isinstance(expect, dict) or not expect:
        return "expect 없음/비어있음"
    if expect.get("cleared") is not True:
        return "cleared != true (got %r)" % expect.get("cleared")
    saved = expect.get("saved")
    if isinstance(saved, bool) or not isinstance(saved, int) or saved < 1:
        return "saved 정수≥1 아님 (got %r)" % saved
    return ""


def _selfcheck_schema() -> bool:
    """스키마 검출기(`_solve_expect_invalid`)의 음성/양성 케이스 자가검증 — fail-open 회귀 방지(codex
    Phase 2 R1 next-step '음성 케이스 추가'). 검출기가 약해지면 selftest 자체가 먼저 FAIL한다."""
    cases = [
        ({}, True), ({"saved": 5}, True), ({"cleared": True}, True),
        ({"cleared": False, "saved": 5}, True), ({"cleared": True, "saved": 0}, True),
        ({"cleared": True, "saved": True}, True), ({"cleared": True, "saved": 5}, False),
    ]
    for expect, should_reject in cases:
        if bool(_solve_expect_invalid(expect)) != should_reject:
            print("[selftest] SCHEMA SELFCHECK FAIL: %r expected reject=%s" % (expect, should_reject))
            return False
    return True


def selftest() -> int:
    """골든(Phase 1 손작성 메커니즘) + solve(Phase 2 자동발견 해)를 모두 리플레이해 game verdict와 대조.
    solve.json은 솔버 산출 해의 **CI 회귀 게이트** — 엔진/스킬 변경이 확보된 해(saved 100%)를 조용히
    깨면 여기서 잡힌다(D4). 솔버를 다시 돌릴 필요 없이 확정 플랜만 결정론 리플레이하므로 빠르다.
    **fail-closed**(codex Phase 2 R1-HIGH): ① 기대 solve 집합 `EXPECTED_SOLVE_STAGES`가 모두 존재해야
    하고(누락 시 즉시 FAIL — golden만으로 통과하던 fail-open 차단), ② 각 solve의 expect는 cleared:true +
    saved 정수≥1을 가져야 한다(빈/약한 expect verdict-only 통과 차단)."""
    if not _selfcheck_schema():
        return 1
    golden = sorted(GOLDEN_DIR.glob("*.plan.json"))
    solves = sorted(SOLUTIONS_DIR.glob("*.solve.json"))
    # fail-closed ①: 기대 solve 집합 누락 검출(solve 파일 실수 삭제 / golden-only 통과 방지).
    present = {sid for sid in (_solve_stage_id(p) for p in solves) if sid is not None}
    missing = [s for s in EXPECTED_SOLVE_STAGES if s not in present]
    if missing:
        print("[selftest] FAIL - 기대 solve 누락: %s (존재: %s)" % (
            ["stage%02d" % s for s in missing], sorted(present)))
        return 1
    targets = golden + solves
    if not targets:
        print("[selftest] no golden/solve plans in %s" % SOLUTIONS_DIR.relative_to(ROOT))
        return 1
    print("[selftest] %d golden + %d solve plans (기대 solve stage %s 모두 존재)" % (
        len(golden), len(solves), list(EXPECTED_SOLVE_STAGES)))
    solves_set = set(solves)
    all_ok = True
    for pf in targets:
        spec = json.loads(pf.read_text(encoding="utf-8"))
        expect = spec.get("expect", {})
        # fail-closed ②: solutions/*.solve.json 으로 glob된 **모든** 파일에 강한 expect 계약을 harness 실행
        # 전 강제(파일명이 stageNN 형식이 아니어도 — unknown solve fixture가 빈/약한 expect로 verdict-only
        # 통과 못 하게). 판정을 _solve_stage_id가 아니라 glob 멤버십으로 한다(self-review: 정규식 미스 시 스킵
        # = 잔존 fail-open). golden(.plan.json)은 자체 expect 스키마라 대상 외.
        if pf in solves_set:
            bad = _solve_expect_invalid(expect)
            if bad:
                print("  [FAIL] %s -> 부적격 solve expect: %s" % (pf.name, bad))
                all_ok = False
                continue
        result = run_plan_file(pf)
        fails = check_expect(result, expect)
        tag = "PASS" if not fails else "FAIL"
        print("  [%s] %s -> cleared=%s saved=%s actions_fired=%s reason=%s frame=%s" % (
            tag, pf.name, result.get("cleared"), result.get("saved"),
            result.get("actions_fired"), result.get("reason"), result.get("frame")))
        for f in fails:
            print("        - %s" % f)
            all_ok = False
    if all_ok:
        print("[selftest] PASS - all %d plans (golden+solve, fail-closed) match game verdict" % len(targets))
        return 0
    print("[selftest] FAIL - verdict mismatch")
    return 1


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 64
    if args[0] == "--selftest":
        return selftest()
    plan_path = Path(args[0])
    if not plan_path.is_absolute():
        plan_path = (Path.cwd() / plan_path).resolve()
    if not plan_path.exists():
        print("[run_plan] plan file not found: %s" % plan_path)
        return 1
    result = run_plan_file(plan_path)
    print(json.dumps(result, indent=2))
    return 0 if (result.get("cleared") and int(result.get("saved", 0)) >= 1) else 1


if __name__ == "__main__":
    raise SystemExit(main())
