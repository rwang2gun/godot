#!/usr/bin/env python3
"""
auto-solver Phase 2 — 예측 기반 탐색 솔버 (closed-loop).

blind generate-and-test(끝점 점수만 보고 후보를 수백 개 던짐)를 폐기하고, **예측 기반 닫힌 루프**로 푼다:
  1) 베이스라인 관측: 무개입 플랜을 엔진으로 1회 돌려 개미 궤적(트레이스)을 *관측*한다(D10 — 엔진=진실).
  2) 진단: model.diagnose가 궤적에서 실패를 읽는다(물 진입 지점·candy 근접·픽업/저장 격차).
  3) 개입 제안: model.propose가 스킬 메타 routing(D11)으로 "어디에·언제" 다음 개입을 제안한다.
  4) 검증: 후보를 엔진으로 돌려(롤아웃) 진척하면 채택, 그 새 궤적으로 2)로 — 100%까지 반복.

성공 = saved 100%(D: 정합성). **롤아웃 상한 = 10/스테이지(사용자)**: 베이스라인 + 후보 검증을 합쳐 10회
안에 100% 미달이면 멈추고 사용자 재도전 승인을 받는다(무한 그라인드 금지). 예측이 제대로면 소수로 푼다.

Usage:
    GODOT_BIN=... python tools/solver/solve.py 11
    GODOT_BIN=... python tools/solver/solve.py 14 --max-rollouts 10
Exit: 0=100% 해결 / 2=체크포인트(상한 도달, 사용자 승인 필요) / 1=에러.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import model

ROOT = Path(__file__).resolve().parents[2]
RUN_TEST = ROOT / "scripts" / "run_test.py"
PLAN_HARNESS = "tests/PlanReplayHarness.tscn"
META_DUMP = "tests/SolverMetaDump.tscn"


# ---------- D7 능력/메타 덤프 ----------

def dump_capabilities() -> dict:
    p = subprocess.run([sys.executable, str(RUN_TEST), META_DUMP],
                       capture_output=True, text=True, encoding="utf-8", errors="replace",
                       cwd=str(ROOT), env=os.environ.copy())
    for line in (p.stdout or "").splitlines():
        if line.startswith("SOLVER_CAPS "):
            return json.loads(line[len("SOLVER_CAPS "):])
    raise RuntimeError("SolverMetaDump no SOLVER_CAPS:\n" + (p.stdout or "")[-600:])


# ---------- 엔진 롤아웃 (PlanReplayHarness, D4 verdict) ----------

def run_plan(stage_scene: str, actions: list[dict], deadline: int, trace: bool = True) -> dict:
    plan = {"stage": stage_scene, "deadline_frames": deadline, "trace": trace, "actions": actions}
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(plan, f)
        plan_path = f.name
    env = os.environ.copy()
    env["CANDYANTS_PLAN_PATH"] = plan_path
    env["CANDYANTS_DETERMINISTIC"] = "1"
    try:
        p = subprocess.run([sys.executable, str(RUN_TEST), PLAN_HARNESS, "--fixed-fps", "60"],
                           capture_output=True, text=True, encoding="utf-8", errors="replace",
                           cwd=str(ROOT), env=env)
    finally:
        try:
            Path(plan_path).unlink()
        except OSError:
            pass
    for line in (p.stdout or "").splitlines():
        if line.startswith("SOLVER_RESULT "):
            try:
                return json.loads(line[len("SOLVER_RESULT "):])
            except json.JSONDecodeError:
                pass
    return {"error": "no SOLVER_RESULT", "stdout_tail": (p.stdout or "")[-400:]}


def is_full_clear(res: dict, hp: int) -> bool:
    return bool(res.get("cleared")) and int(res.get("saved", 0)) >= hp


def score(res: dict, layout: dict) -> tuple:
    """작을수록 좋음: saved 많음 > **리타이어 적음** > picked 많음 > 갇힘 적음 > home 근접 > 도달 최고점.
    **리타이어 최소가 picked보다 우선**(사용자 최우선 규칙): candy에서 멀어지더라도 전원 생존을 먼저
    확보해야 그 살아있는 상태에서 경로를 만들 수 있다(예: S14 치명 낙하 직전 blocker 반전 = 생존 발판)."""
    saved = int(res.get("saved", 0))
    picked = int(res.get("picked_total", 0))
    retired = model.count_retired(res.get("trace", {}), layout)["total"]
    # 루프(블로커 충돌) 감지는 **saved==0일 때만 보정용**으로 참고한다(사용자 규칙): 집까지 도달한
    # 개미가 하나라도 있으면(saved>0) 블로커 충돌 횟수는 무시 — 그 가둠은 곧 풀릴(예: climber로) 정상
    # 과정일 수 있어 오판 방지. saved==0인데 carrying이 갇혔으면 = 잘못 놓인 블로커 → 그 변형을 기피.
    carry_tr = 0
    if saved == 0:
        carry_tr, _tot = model.count_trapped(res.get("trace", {}))
    home_d = float(res.get("best_carry_home_dist", 1e20))
    if home_d < 0:
        home_d = 1e20
    miny = float(res.get("best_min_y", 1e20))
    if miny < 0:
        miny = 1e20
    return (-saved, retired, -picked, carry_tr, home_d, miny)


def _fmt(res: dict, hp: int) -> str:
    return "saved=%s/%s reached=%s reason=%s frame=%s" % (
        res.get("saved"), hp, res.get("picked_total"), res.get("reason"), res.get("frame"))


# ---------- 스테이지 메타 ----------

def stage_meta(stage_id: int) -> dict:
    tres = (ROOT / "data" / "stages" / f"stage{stage_id:02d}.tres").read_text(encoding="utf-8")
    inv: dict[str, int] = {}
    b = re.search(r"skill_inventory\s*=\s*\{(.*?)\}", tres, re.S)
    if b:
        for m in re.finditer(r'"(\w+)"\s*:\s*(\d+)', b.group(1)):
            inv[m.group(1)] = int(m.group(2))
    notes: dict[str, str] = {}
    nb = re.search(r"skill_notes\s*=\s*\{(.*?)\}", tres, re.S)
    if nb:
        for m in re.finditer(r'"(\w+)"\s*:\s*"([^"]*)"', nb.group(1)):
            notes[m.group(1)] = m.group(2)
    def _int(name, dflt):
        m = re.search(name + r"\s*=\s*([\d.]+)", tres)
        return type(dflt)(float(m.group(1))) if m else dflt
    return {"inventory": inv, "notes": notes, "candy_hp": _int("candy_hp", 10),
            "time_limit_seconds": _int("time_limit_seconds", 100.0), "total_ants": _int("total_ants", 0)}


# ---------- 닫힌 루프 ----------

def solve(stage_id: int, max_rollouts: int) -> int:
    stage_scene = f"res://scenes/stages/Stage{stage_id:02d}.tscn"
    layout = model.parse_layout(ROOT / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres")
    meta = stage_meta(stage_id)
    inv, notes, hp = meta["inventory"], meta["notes"], int(meta["candy_hp"])
    deadline = int(round(meta["time_limit_seconds"] * 60)) + 1500
    caps = dump_capabilities()
    metas = caps["skills"]

    print(f"=== solve stage{stage_id:02d} (예측 closed-loop) ===")
    print(f"  목표(candy hp)={hp}  도구(inventory)={inv}  notes={notes or '없음'}")
    print(f"  candy={layout['candy']} home={layout['home']} cap={max_rollouts} rollouts")

    rollouts = 0
    plan: list[dict] = []
    tried: set = set()

    # ① 베이스라인 관측.
    best = run_plan(stage_scene, plan, deadline, trace=True)
    rollouts += 1
    if "error" in best:
        print("  [에러] 베이스라인 롤아웃 실패:", best.get("error"))
        return 1
    print(f"  baseline(무개입): {_fmt(best, hp)}")
    if is_full_clear(best, hp):
        return _save(stage_id, stage_scene, deadline, inv, plan, best, rollouts, hp, layout, meta["total_ants"])

    # ②~④ 관측 → 진단 → 개입(라운드별 후보 평가 후 **최선** 채택) → 재관측 (상한까지).
    while rollouts < max_rollouts:
        diag = model.diagnose(best.get("trace", {}), layout, hp)
        cands = model.propose(layout, diag, inv, metas, notes, exclude=tried,
                              max_n=min(max_rollouts - rollouts, 6))   # 라운드당 후보 cap(롤아웃 절약)
        if not cands:
            print("  [정지] 제안할 개입 후보 없음(진단으로 더 둘 곳 없음).")
            break
        evaluated: list = []
        for cand in cands:
            if rollouts >= max_rollouts:
                break
            tried.add(cand["label"])
            res = run_plan(stage_scene, plan + [cand["action"]], deadline, trace=True)
            rollouts += 1
            ct, tt = model.count_trapped(res.get("trace", {}))
            print(f"  롤아웃 {rollouts}: +{cand['label']} → {_fmt(res, hp)} trapped(carry/all)={ct}/{tt}")
            if "error" in res:
                continue
            if is_full_clear(res, hp):
                plan = plan + [cand["action"]]
                return _save(stage_id, stage_scene, deadline, inv, plan, res, rollouts, hp, layout, meta["total_ants"])
            evaluated.append((cand, res))
        if not evaluated:
            break
        cand, res = min(evaluated, key=lambda cr: score(cr[1], layout))   # 라운드 최선
        if score(res, layout) < score(best, layout):
            plan = plan + [cand["action"]]
            best = res
            print(f"    채택(최선): +{cand['label']} → plan={[a.get('skill') for a in plan]}")
        else:
            print("  [정지] 이번 라운드 후보가 진척을 못 냄.")
            break

    # 상한 도달 또는 정체 — 100% 미달 → 체크포인트. 최고 기록 시도의 리타이어 개미·사용 도구 수도 보고.
    saved = int(best.get("saved", 0))
    rt = model.count_retired(best.get("trace", {}), layout)
    tools = len(plan)
    kind = "부분 성공" if saved > 0 else "실패"
    print(f"\nCHECKPOINT stage{stage_id:02d}: {kind} (saved={saved}/{hp}, rollouts={rollouts}/{max_rollouts}).")
    print(f"  최고 기록: {_fmt(best, hp)} | 리타이어={rt['total']}/{meta['total_ants']}"
          f"(낙하 {rt['fall']}, 물 {rt['water']}) | 사용 도구={tools}")
    print(f"  best plan: {[a.get('skill') for a in plan]}")
    print(f"  => 10 롤아웃 내 100% 미달성. 재도전(상한 상향) 여부를 사용자 승인 필요.")
    return 2


def _save(stage_id, stage_scene, deadline, inv, plan, res, rollouts, hp, layout, total_ants) -> int:
    rt = model.count_retired(res.get("trace", {}), layout)
    tools = len(plan)
    sol = {"stage": stage_scene, "deadline_frames": deadline, "inventory": inv,
           "expect": {"cleared": True, "saved": int(res.get("saved", 0))},
           "search_meta": {"rollouts": rollouts, "tool": "solve.py", "phase": 2, "method": "predictive",
                           "retired_ants": rt, "total_ants": total_ants, "tools_used": tools},
           "actions": plan, "result": {k: v for k, v in res.items() if k != "trace"}}
    sol_dir = ROOT / "data" / "solutions"
    sol_dir.mkdir(exist_ok=True)
    sol_path = sol_dir / f"stage{stage_id:02d}.solve.json"
    sol_path.write_text(json.dumps(sol, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nSOLVED(100%) stage{stage_id:02d}: saved={res.get('saved')}/{hp} | "
          f"리타이어={rt['total']}/{total_ants}(낙하 {rt['fall']}, 물 {rt['water']}) | "
          f"사용 도구={tools} | rollouts={rollouts}")
    print(f"  skills={[a.get('skill') for a in plan]}")
    print(f"  plan saved -> {sol_path.relative_to(ROOT)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_id", type=int)
    ap.add_argument("--max-rollouts", type=int, default=10, help="롤아웃 상한(기본 10, 사용자 정책).")
    args = ap.parse_args()
    return solve(args.stage_id, args.max_rollouts)


if __name__ == "__main__":
    raise SystemExit(main())
