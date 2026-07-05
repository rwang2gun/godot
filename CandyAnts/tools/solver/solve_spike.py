#!/usr/bin/env python3
"""
auto-solver spike — blocker 전용 탐색 오케스트레이터.

레벨(layout .tres)을 파싱해 blocker 배치 후보를 생성하고, 후보 플랜을 SolverHarness(실제 게임,
결정론 헤드리스)로 돌려 클리어 verdict를 받는다(D4). beam search로 진척(도달 최고점)이 좋은 플랜을
이어붙여 budget(인벤토리 blocker 수)까지 확장한다. 클리어 플랜을 찾으면 출력·저장, 못 찾으면
"현 인벤토리로 클리어 불가(탐색 범위 내)"를 보고한다.

손코딩 CampaignSxx 드라이버를 대체하는 첫 수직 슬라이스. blocker만 지원(S11/S12 인벤토리 한정).

Usage:
    GODOT_BIN=... python tools/solver/solve_spike.py 11
    GODOT_BIN=... python tools/solver/solve_spike.py 12 --beam 3 --workers 6

Env: GODOT_BIN (run_test.py가 사용). 출력: 콘솔 + 발견 시 data/solutions/stageNN.spike.json.
"""
from __future__ import annotations

import argparse
import concurrent.futures as cf
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]   # .../CandyAnts
RUN_TEST = ROOT / "scripts" / "run_test.py"
HARNESS_SCENE = "tests/SolverHarness.tscn"
DEADLINE_FRAMES = 7000   # stage time_limit(보통 6000f) 직후 안전망. 스테이지가 먼저 time_out/clear로 종료.


# ---------- 레이아웃 파싱 ----------

def parse_layout(layout_tres: Path) -> dict:
    text = layout_tres.read_text(encoding="utf-8")
    cell_size = int(re.search(r"cell_size\s*=\s*(\d+)", text).group(1))
    cells: dict[tuple[int, int], str] = {}      # (col,row) -> kind (solid/sand_mound/...)
    hazards: dict[tuple[int, int], str] = {}
    for m in re.finditer(r'"(-?\d+),(-?\d+)"\s*:\s*"(\w+)"', text):
        c, r, kind = int(m.group(1)), int(m.group(2)), m.group(3)
        if kind in ("water", "sticky"):
            hazards[(c, r)] = kind
        else:
            cells[(c, r)] = kind
    cm = re.search(r"candy_cell\s*=\s*Vector2i\((-?\d+),\s*(-?\d+)\)", text)
    candy_cell = (int(cm.group(1)), int(cm.group(2))) if cm else None
    sd = re.search(r"spawn_direction\s*=\s*(-?\d+)", text)
    spawn_direction = int(sd.group(1)) if sd else 1
    return {"cell_size": cell_size, "cells": cells, "hazards": hazards,
            "candy_cell": candy_cell, "spawn_direction": spawn_direction}


def surfaces(layout: dict) -> dict[int, list[int]]:
    """walkable 표면 = solid 셀인데 바로 위 셀이 solid가 아닌 곳. row -> 정렬된 col 목록(>=3개)."""
    cells = layout["cells"]
    by_row: dict[int, list[int]] = {}
    for (c, r), kind in cells.items():
        if kind != "solid":
            continue
        if cells.get((c, r - 1)) == "solid":
            continue   # 위가 막힘 = 표면 아님
        by_row.setdefault(r, []).append(c)
    return {r: sorted(cs) for r, cs in by_row.items() if len(cs) >= 3}


def ladder_cols(layout: dict) -> dict[int, tuple[int, int]]:
    """sand_mound(막대과자 사다리) 열 -> (min_row, max_row)."""
    by_col: dict[int, list[int]] = {}
    for (c, r), kind in layout["cells"].items():
        if kind == "sand_mound":
            by_col.setdefault(c, []).append(r)
    return {c: (min(rs), max(rs)) for c, rs in by_col.items()}


def gen_candidates(layout: dict) -> list[dict]:
    """표면별 관심 x(좌/우 가장자리 + 이 레벨에 닿는 사다리 열)에 blocker 벽 후보 생성.
    벽 위치는 select(min_x/max_x)+cmp로 근사하므로, 진행 방향을 모르니 두 변형 모두 생성 후 dedup."""
    cs = layout["cell_size"]
    surfs = surfaces(layout)
    ladders = ladder_cols(layout)
    cands: list[dict] = []
    seen: set = set()
    for r in sorted(surfs):
        cols = surfs[r]
        left, right = cols[0], cols[-1]
        y_center = r * cs            # 개미 발 ≈ r*cs - 8; band은 레벨 내(±)로 넉넉히
        y_min, y_max = y_center - 40.0, y_center + 24.0
        interesting = {left + 1, right}
        for lc, (lr0, lr1) in ladders.items():
            # 이 표면 행(r)이 사다리 세로 범위에 인접하면(아래·중간) 그 열을 관심 x로
            if lr0 - 1 <= r <= lr1 + 1:
                interesting.add(lc)
        for col in sorted(interesting):
            xc = (col + 0.5) * cs
            for sel, cmp in (("max_x", "ge"), ("min_x", "le")):
                key = (r, round(xc), sel, cmp)
                if key in seen:
                    continue
                seen.add(key)
                cands.append({"sel": sel, "cmp": cmp, "x": xc,
                              "y_min": y_min, "y_max": y_max, "_row": r,
                              "_label": f"r{r}:{sel}{cmp}{col}"})
    return cands


def local_refine(stage_scene: str, budget: int, base_plan: list[dict], layout: dict,
                 workers: int, max_rollouts: int) -> dict | None:
    """beam 최선 플랜 주변 국소 정밀탐색 — 각 액션의 x를 그 표면의 모든 col(±1셀 grid)·양 select로
    스윕(나머지 액션 고정). 거친 랜드마크 격자가 놓친 '마지막 한 칸' 배치를 닫는다. 클리어 시 반환, 아니면 None."""
    cs = layout["cell_size"]
    surfs = surfaces(layout)
    plans: list[list[dict]] = []
    seen = set()
    for i, act in enumerate(base_plan):
        r = act["_row"]
        cols = surfs.get(r, [])
        if not cols:
            continue
        for col in range(cols[0], cols[-1] + 1):
            xc = (col + 0.5) * cs
            for sel, cmp in (("max_x", "ge"), ("min_x", "le")):
                variant = dict(act, sel=sel, cmp=cmp, x=xc, _label=f"r{r}:{sel}{cmp}{col}*")
                new = list(base_plan)
                new[i] = variant
                sig = tuple(sorted(a["_label"].rstrip("*") for a in new))
                if sig in seen:
                    continue
                seen.add(sig)
                plans.append(new)
    plans = plans[:max_rollouts]
    if not plans:
        return None
    print(f"[spike] local-refine: {len(plans)} neighbor plans around best", flush=True)
    best = None
    with cf.ThreadPoolExecutor(max_workers=workers) as ex:
        futs = {ex.submit(run_plan, stage_scene, pl, budget): pl for pl in plans}
        for fut in cf.as_completed(futs):
            pl, res = futs[fut], fut.result()
            if is_clear(res):
                print(f"[spike] CLEAR via local-refine: {[a['_label'] for a in pl]} -> {res}", flush=True)
                return {"plan": pl, "result": res}
            if best is None or score(res) < score(best[1]):
                best = (pl, res)
    if best is not None:
        print(f"[spike] local-refine best (no clear): {[a['_label'] for a in best[0]]} {_fmt(best[1])}", flush=True)
    return None


# ---------- 롤아웃(실제 게임) ----------

def run_plan(stage_scene: str, actions: list[dict], budget: int) -> dict:
    plan = {"stage": stage_scene, "deadline_frames": DEADLINE_FRAMES,
            "blocker_budget": budget,
            "actions": [{k: v for k, v in a.items() if not k.startswith("_")} for a in actions]}
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(plan, f)
        plan_path = f.name
    import os
    env = os.environ.copy()
    env["CANDYANTS_PLAN_PATH"] = plan_path
    env["CANDYANTS_DETERMINISTIC"] = "1"
    try:
        p = subprocess.run([sys.executable, str(RUN_TEST), HARNESS_SCENE, "--fixed-fps", "60"],
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


def is_clear(res: dict) -> bool:
    return bool(res.get("cleared")) and int(res.get("saved", 0)) >= 1


def _fmt(res: dict) -> str:
    return "miny=%.0f picked=%s home_d=%.0f saved=%s" % (
        float(res.get("best_min_y", -1)), res.get("picked"),
        float(res.get("best_carry_home_dist", -1)), res.get("saved"))


def score(res: dict) -> tuple:
    """정렬 키(작을수록 좋음). 왕복(픽업→복귀)을 height보다 우선해 '올라가기만' 편향 교정:
    1) 클리어 우선  2) candy 픽업한 플랜 우선  3) 픽업했으면 home 근접도(작을수록 복귀 완성에 가까움)
    4) 미픽업이면 도달 최고점(작은 y=높이)  5) saved 많을수록  6) blocker 적게."""
    cleared = 0 if is_clear(res) else 1
    miny = float(res.get("best_min_y", 1e20))
    if miny < 0:
        miny = 1e20
    picked = 0 if res.get("picked") else 1
    home_d = float(res.get("best_carry_home_dist", 1e20))
    if home_d < 0:
        home_d = 1e20
    # 픽업 그룹 안에선 home_d로, 미픽업 그룹 안에선 miny로 정렬되도록 결합.
    progress = home_d if picked == 0 else (1e9 + miny)
    return (cleared, picked, progress, -int(res.get("saved", 0)), int(res.get("blockers_used", 99)))


# ---------- beam search ----------

def beam_search(stage_scene: str, budget: int, cands: list[dict], beam_w: int,
                workers: int, max_rollouts: int) -> dict:
    rollouts = [0]

    def eval_plans(plans: list[list[dict]]) -> list[tuple[list[dict], dict]]:
        results: list[tuple[list[dict], dict]] = []
        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            futs = {ex.submit(run_plan, stage_scene, pl, budget): pl for pl in plans}
            for fut in cf.as_completed(futs):
                results.append((futs[fut], fut.result()))
        rollouts[0] += len(plans)
        return results

    # 라운드 1: 단일 blocker 플랜 전수.
    print(f"[spike] round 1: {len(cands)} single-blocker plans (budget={budget})", flush=True)
    scored = eval_plans([[c] for c in cands])
    for pl, res in scored:
        if is_clear(res):
            print(f"[spike] CLEAR at round 1: {[a['_label'] for a in pl]} -> {res}", flush=True)
            return {"plan": pl, "result": res, "rollouts": rollouts[0]}
    scored.sort(key=lambda pr: score(pr[1]))
    beam = scored[:beam_w]
    best = beam[0]
    print(f"[spike] round1 best: {[a['_label'] for a in best[0]]} {_fmt(best[1])}", flush=True)

    depth = 2
    while depth <= budget and rollouts[0] < max_rollouts:
        # beam의 각 부분 플랜에 후보 1개씩 추가(중복 액션 제외).
        next_plans: list[list[dict]] = []
        seen_sig = set()
        for pl, _ in beam:
            used = {a["_label"] for a in pl}
            for c in cands:
                if c["_label"] in used:
                    continue
                new = pl + [c]
                sig = tuple(sorted(a["_label"] for a in new))
                if sig in seen_sig:
                    continue
                seen_sig.add(sig)
                next_plans.append(new)
        if not next_plans:
            break
        print(f"[spike] round {depth}: {len(next_plans)} plans (rollouts so far {rollouts[0]})", flush=True)
        scored = eval_plans(next_plans)
        for pl, res in scored:
            if is_clear(res):
                print(f"[spike] CLEAR at round {depth}: {[a['_label'] for a in pl]} -> {res}", flush=True)
                return {"plan": pl, "result": res, "rollouts": rollouts[0]}
        scored.sort(key=lambda pr: score(pr[1]))
        beam = scored[:beam_w]
        b = beam[0]
        print(f"[spike] round{depth} best: {[a['_label'] for a in b[0]]} {_fmt(b[1])}", flush=True)
        if score(b[1]) < score(best[1]):
            best = b
        depth += 1

    return {"plan": None, "best_plan": best[0], "best_result": best[1], "rollouts": rollouts[0]}


# ---------- main ----------

def stage_inventory_blocker(stage_id: int) -> int:
    tres = (ROOT / "data" / "stages" / f"stage{stage_id:02d}.tres").read_text(encoding="utf-8")
    m = re.search(r'"blocker"\s*:\s*(\d+)', tres)
    return int(m.group(1)) if m else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage_id", type=int)
    ap.add_argument("--beam", type=int, default=3)
    ap.add_argument("--workers", type=int, default=6)
    ap.add_argument("--max-rollouts", type=int, default=400)
    args = ap.parse_args()

    sid = args.stage_id
    stage_scene = f"res://scenes/stages/Stage{sid:02d}.tscn"
    layout_path = ROOT / "data" / "stage_layouts" / f"stage{sid:02d}_layout.tres"
    layout = parse_layout(layout_path)
    budget = stage_inventory_blocker(sid)
    cands = gen_candidates(layout)

    print(f"=== solve_spike stage{sid:02d} ===")
    print(f"  blocker budget={budget}  candy_cell={layout['candy_cell']}  spawn_dir={layout['spawn_direction']}")
    print(f"  surfaces(rows)={sorted(surfaces(layout))}  ladders(cols)={sorted(ladder_cols(layout))}")
    print(f"  candidates={len(cands)}")

    out = beam_search(stage_scene, budget, cands, args.beam, args.workers, args.max_rollouts)

    # beam이 못 닫으면 최선 플랜 주변 국소 정밀탐색으로 '마지막 한 칸' 시도.
    if not out.get("plan") and out.get("best_plan"):
        refined = local_refine(stage_scene, budget, out["best_plan"], layout, args.workers, args.max_rollouts)
        if refined is not None:
            out = {"plan": refined["plan"], "result": refined["result"], "rollouts": out.get("rollouts", 0)}

    if out.get("plan"):
        pl = out["plan"]
        sol = {"stage": stage_scene, "blocker_budget": budget,
               "actions": [{k: v for k, v in a.items() if not k.startswith("_")} for a in pl],
               "labels": [a["_label"] for a in pl], "result": out["result"]}
        sol_dir = ROOT / "data" / "solutions"
        sol_dir.mkdir(exist_ok=True)
        sol_path = sol_dir / f"stage{sid:02d}.spike.json"
        sol_path.write_text(json.dumps(sol, indent=2), encoding="utf-8")
        print(f"\nSOLVED stage{sid:02d}: {sol['labels']}")
        print(f"  saved={out['result'].get('saved')}/{out['result'].get('hp')} frame={out['result'].get('frame')} rollouts={out['rollouts']}")
        print(f"  plan saved -> {sol_path.relative_to(ROOT)}")
        return 0
    else:
        br = out["best_result"]
        print(f"\nNOT SOLVED stage{sid:02d} within search (rollouts={out['rollouts']}).")
        print(f"  best partial: {[a['_label'] for a in out['best_plan']]}")
        print(f"  best_min_y={br.get('best_min_y')} saved={br.get('saved')} reason={br.get('reason')}")
        print(f"  => 현 인벤토리(blocker x{budget})·탐색 범위 내 클리어 플랜 없음. 레벨 설계 재고 또는 탐색 확장 필요.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
