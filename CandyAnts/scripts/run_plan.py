#!/usr/bin/env python3
"""
auto-solver Phase 1 — 플랜 리플레이 CLI.

플랜(JSON)을 헤드리스(`--fixed-fps`, 결정론)로 실제 게임에 재생하고 무수정 게임 verdict를 보고한다(D4).
PlanReplayHarness 씬을 띄워 SOLVER_RESULT를 파싱한다. spike의 solve_spike.run_plan을 일반화한 단일 진입점.

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
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent      # .../CandyAnts
RUN_TEST = ROOT / "scripts" / "run_test.py"
HARNESS_SCENE = "tests/PlanReplayHarness.tscn"
GOLDEN_DIR = ROOT / "data" / "solutions" / "golden"
SOLUTIONS_DIR = ROOT / "data" / "solutions"


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


def selftest() -> int:
    """골든(Phase 1 손작성 메커니즘) + solve(Phase 2 자동발견 해)를 모두 리플레이해 game verdict와 대조.
    solve.json은 솔버 산출 해의 **CI 회귀 게이트** — 엔진/스킬 변경이 확보된 해(saved 100%)를 조용히
    깨면 여기서 잡힌다(D4). 솔버를 다시 돌릴 필요 없이 확정 플랜만 결정론 리플레이하므로 빠르다."""
    golden = sorted(GOLDEN_DIR.glob("*.plan.json"))
    solves = sorted(SOLUTIONS_DIR.glob("*.solve.json"))
    targets = golden + solves
    if not targets:
        print("[selftest] no golden/solve plans in %s" % SOLUTIONS_DIR.relative_to(ROOT))
        return 1
    print("[selftest] %d golden + %d solve plans" % (len(golden), len(solves)))
    all_ok = True
    for pf in targets:
        spec = json.loads(pf.read_text(encoding="utf-8"))
        expect = spec.get("expect", {})
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
        print("[selftest] PASS - all %d plans (golden+solve) match game verdict" % len(targets))
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
