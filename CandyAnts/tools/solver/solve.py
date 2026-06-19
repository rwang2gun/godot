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
    """작을수록 좋음: saved 많음 > **리타이어 적음** > picked 많음 > 갇힘 적음 > **목표 접근**.
    **리타이어 최소가 picked보다 우선**(사용자 최우선 규칙): candy에서 멀어지더라도 전원 생존을 먼저
    확보해야 그 살아있는 상태에서 경로를 만들 수 있다(예: S14 치명 낙하 직전 blocker 반전 = 생존 발판).
    **목표 접근 = best_goal_dist**(픽업 전=candy, 픽업 후=home 셀 맨해튼) — best_min_y(항상 위로 보상)를
    대체해 candy가 아래(S14)면 하강을 보상한다.
    **전원 픽업 디딤돌 예외(2026-06-19, 사용자 통찰)**: remaining_hp==0(전 사탕 픽업)이면 picked를
    retired보다 우선한다. 전원 픽업은 '귀로만 남은' 강한 디딤돌인데(사탕과 충돌=방향전환 → 다음은 집으로
    가는 장애물을 climber로 대응), 그 상태의 잔존 retired(climber 미부여로 귀환 못해 사망)를 retired-우선
    으로 매기면 0픽업0사망(blocker 1개)에 기각돼 **climber를 얹을 trace에 도달조차 못 한다**(S14 정체
    근본 원인). 전원 픽업 전까지는 종전대로 retired 우선(생존 발판 먼저)."""
    saved = int(res.get("saved", 0))
    picked = int(res.get("picked_total", 0))
    retired = model.count_retired(res.get("trace", {}), layout)["total"]
    # 루프(블로커 충돌) 감지는 **saved==0일 때만 보정용**으로 참고한다(사용자 규칙): 집까지 도달한
    # 개미가 하나라도 있으면(saved>0) 블로커 충돌 횟수는 무시 — 그 가둠은 곧 풀릴(예: climber로) 정상
    # 과정일 수 있어 오판 방지. saved==0인데 carrying이 갇혔으면 = 잘못 놓인 블로커 → 그 변형을 기피.
    carry_tr = 0
    if saved == 0:
        carry_tr, _tot = model.count_trapped(res.get("trace", {}))
    goal_d = model.best_goal_dist(res.get("trace", {}), layout)
    if int(res.get("remaining_hp", -1)) == 0:        # 전원 픽업 = 귀로만 남은 디딤돌 → picked 우선(위 통찰)
        return (-saved, -picked, retired, carry_tr, goal_d)
    return (-saved, retired, -picked, carry_tr, goal_d)


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

    def rollout(p: list[dict]) -> dict:
        nonlocal rollouts
        rollouts += 1
        return run_plan(stage_scene, p, deadline, trace=True)

    plan: list[dict] = []
    tried: set = set()

    # ① 베이스라인 관측.
    best = rollout(plan)
    if "error" in best:
        print("  [에러] 베이스라인 롤아웃 실패:", best.get("error"))
        return 1
    print(f"  baseline(무개입): {_fmt(best, hp)}")
    if is_full_clear(best, hp):
        return _save(stage_id, stage_scene, deadline, inv, plan, best, rollouts, hp, layout, meta["total_ants"])

    class _Clear(Exception):
        def __init__(self, p, r):
            self.plan, self.res = p, r

    def eval_cands(base: list[dict], cands: list, tag: str) -> list:
        """후보들을 base 플랜 위에 롤아웃. full clear면 _Clear로 즉시 탈출. 반환 (cand,res) 리스트.
        이미 base에 든 액션은 건너뛴다 — carry 후보는 exclude 면제(plan 누적 재평가)라, 채택돼 base에
        들어간 carry n이 다시 후보로 와도 중복 롤аут하지 않게 막는다(연쇄만 진행)."""
        out: list = []
        for cand in cands:
            if rollouts >= max_rollouts:
                break
            if cand["action"] in base:        # 이미 채택된 액션 — 중복 롤아웃 방지
                continue
            tried.add(cand["label"])
            res = rollout(base + [cand["action"]])
            ct, tt = model.count_trapped(res.get("trace", {}))
            print(f"  롤아웃 {rollouts}{tag}: +{cand['label']} → {_fmt(res, hp)} trapped(carry/all)={ct}/{tt}")
            if "error" in res:
                continue
            if is_full_clear(res, hp):
                raise _Clear(base + [cand["action"]], res)
            out.append((cand, res))
        return out

    # ②~④ 관측 → 진단 → 개입(라운드별 후보 평가 후 **최선** 채택) → 재관측 (상한까지).
    # 1-스텝이 정체하면 **2-스텝 lookahead**(사용자: S13/S14는 단일 개입이 일시적으로 악화[물 익사↑]된 뒤
    # 두 번째 개입으로 닫히므로 그리디로는 못 넘음 — 유망 first-step에서 재진단→second 평가).
    try:
        while rollouts < max_rollouts:
            diag = model.diagnose(best.get("trace", {}), layout, hp)
            cands = model.propose(layout, diag, inv, metas, notes, exclude=tried,
                                  max_n=min(max_rollouts - rollouts, 6))
            if not cands:
                print("  [정지] 제안할 개입 후보 없음(진단으로 더 둘 곳 없음).")
                break
            evaluated = eval_cands(plan, cands, "")
            if not evaluated:
                break
            cand, res = min(evaluated, key=lambda cr: score(cr[1], layout))
            if score(res, layout) < score(best, layout):
                plan = plan + [cand["action"]]
                best = res
                print(f"    채택(최선): +{cand['label']} → plan={[a.get('skill') for a in plan]}")
                continue
            # 1-스텝 정체 → 2-스텝 lookahead. **유망 first-step = goal_dist 최근접**(retired-우선 score가
            # 아니라!) — candy 근처까지 갔다가 익사한 스텝이 핵심 디딤돌이다(두 번째 스텝이 그 죽음을 고침).
            # retired-우선으로 뽑으면 안전하지만 막다른 top-trap에서 헛 lookahead한다(사용자 통찰 정합).
            print("  [1-스텝 정체] 2-스텝 lookahead 시도(frontier=goal_dist 최근접)")
            frontier = sorted(evaluated, key=lambda cr: model.best_goal_dist(cr[1].get("trace", {}), layout))[:2]
            combo = None
            for c1, res1 in frontier:
                if rollouts >= max_rollouts:
                    break
                diag1 = model.diagnose(res1.get("trace", {}), layout, hp)
                cands2 = model.propose(layout, diag1, inv, metas, notes, exclude=tried,
                                      max_n=min(max_rollouts - rollouts, 4))
                ev2 = eval_cands(plan + [c1["action"]], cands2, "(LA2)")
                for c2, res2 in ev2:
                    if score(res2, layout) < score(best, layout) and (
                            combo is None or score(res2, layout) < score(combo[2], layout)):
                        combo = (c1, c2, res2)
            if combo is not None:
                c1, c2, res2 = combo
                plan = plan + [c1["action"], c2["action"]]
                best = res2
                print(f"    채택(LA2): +{c1['label']}+{c2['label']} → plan={[a.get('skill') for a in plan]}")
                continue
            print("  [정지] 1-스텝·2-스텝 모두 진척을 못 냄.")
            break
    except _Clear as c:
        return _save(stage_id, stage_scene, deadline, inv, c.plan, c.res, rollouts, hp, layout, meta["total_ants"])

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
