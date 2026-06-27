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
LA2_RESERVE = 8   # codex impl R5: 메인 평가 단계(D2 보호로 후보 수가 per-round cap을 초과할 수 있음)가 2-step
                  # lookahead(LA2) budget을 잠식하지 않게 떼어두는 롤아웃 예약(LA2 = frontier 2개 × cands ≤4 = 8).
                  # 보호 미발동(up_cell 없음 → cands ≤ max_n)이면 메인 단계가 이 상한에 안 닿아 inert(byte-identical).
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

def _action_sig(action: dict) -> str:
    """액션의 정규 시그니처(키 정렬 JSON). 다양-해 forbid 집합 매칭용 — try_solve.diverse_report의 plan
    시그니처와 **동일 직렬화**(json.dumps sort_keys=True)를 써야 정확히 일치한다."""
    return json.dumps(action, sort_keys=True)


def _merge_seeded(seeded: list, cands: list) -> list:
    """시드 후보를 propose 후보 풀에 머지 후 _w로 재정렬. action 동일 후보는 시드(보너스+source-tag)로
    치환(byte-identical action 보장 → OFF/ON 차이는 _w·source뿐, plan R1 HIGH-1 측정 계약).
    cands의 source 기본값은 'fallback'(seed_fn 미주입 시 전부 fallback으로 남음)."""
    by_label = {c["label"]: dict(c) for c in cands}
    for c in by_label.values():
        c.setdefault("source", "fallback")
    for s in seeded:
        by_label[s["label"]] = s            # 동일 label은 시드로 치환(보너스+source)
    out = list(by_label.values())
    out.sort(key=lambda c: -c["_w"])
    return out


def solve(stage_id: int, max_rollouts: int, seed_fn=None, stats: dict | None = None,
          save: bool = True, vault_fn=None, inv_override: dict | None = None,
          forbid=None) -> int:
    """닫힌-루프 탐색.
    ⛔ seed_fn·vault_fn = ARCHIVED (Phase 4 강제 종료 — ARCHIVE.md). 속도-전이(boost/pruning)는 falsify됐고
    기본 None이라 게이트에 inert(byte-identical). 보존하나 신규 경로에서 재활성 금지. stats dict 주입 시
    provenance/롤아웃 계측을 채운다(archived transfer-bench A/B·귀속 판정용, plan R1·R2)."""
    stage_scene = f"res://scenes/stages/Stage{stage_id:02d}.tscn"
    layout = model.parse_layout(ROOT / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres")
    meta = stage_meta(stage_id)
    inv, notes, hp = meta["inventory"], meta["notes"], int(meta["candy_hp"])
    if inv_override is not None:
        inv = {k: v for k, v in inv_override.items() if v > 0}   # 다양-해 탐색: 인벤토리 변형(수량/종류)
    # 다양-해 탐색: forbid된 액션 배제. **callable**(술어 `(action, base_plan)->bool`)이면 plan-level
    # solution-class forbid(Phase 5b diverse.py — base+[action]이 이미 발견된 class를 *정확히 완성*할 때만
    # 배제 = distinct class는 절대 억제 안 함, codex R2-HIGH), 아니면 시그니처 iterable(Item 1, 액션 dict/
    # 문자열). None이면 무영향(게이트 byte-identical).
    forbid_pred = forbid if callable(forbid) else None
    forbidden = (set() if forbid_pred is not None else
                 {(_action_sig(a) if isinstance(a, dict) else a) for a in forbid} if forbid else set())
    deadline = int(round(meta["time_limit_seconds"] * 60)) + 1500
    caps = dump_capabilities()
    metas = caps["skills"]

    print(f"=== solve stage{stage_id:02d} (예측 closed-loop{', SEEDED' if seed_fn else ''}) ===")
    print(f"  목표(candy hp)={hp}  도구(inventory)={inv}  notes={notes or '없음'}")
    print(f"  candy={layout['candy']} home={layout['home']} cap={max_rollouts} rollouts")

    rollouts = 0
    # provenance 계측(plan R1 HIGH-1·R2 HIGH-1): 후보 출처별 시도/성공 + 결정적(클리어) 액션 출처.
    prov = {"seeded_attempts": 0, "seeded_successes": 0, "fallback_attempts": 0,
            "fallback_successes": 0, "decisive_origin": None, "plan_sources": [],
            "vault_pruned": 0, "final_plan": None,
            # 반사실 귀속(re-review R1 HIGH-2): OFF가 롤아웃한 (action,cleared) 기록 + ON이 prune한 (base,action).
            # 벤치가 "prune된 후보가 OFF에서 미클리어였나"로 pruning 정당성을 반사실 검증.
            "tried_log": [], "pruned_log": []}

    def rollout(p: list[dict]) -> dict:
        nonlocal rollouts
        rollouts += 1
        return run_plan(stage_scene, p, deadline, trace=True)

    plan: list[dict] = []
    plan_sources: list[str] = []          # plan과 평행 — 채택 액션의 source-tag
    tried: set = set()

    # ① 베이스라인 관측.
    best = rollout(plan)
    if "error" in best:
        print("  [에러] 베이스라인 롤아웃 실패:", best.get("error"))
        return 1
    print(f"  baseline(무개입): {_fmt(best, hp)}")
    if is_full_clear(best, hp):
        prov["final_plan"] = list(plan)      # 빈 플랜([])도 유효한 '무도구' 해 — diverse가 정직 보고하게 기록
        if stats is not None:
            stats.update(prov, rollouts=rollouts, cleared=True)
        return _save(stage_id, stage_scene, deadline, inv, plan, best, rollouts, hp, layout, meta["total_ants"], save=save)

    class _Clear(Exception):
        def __init__(self, p, r, srcs, decisive):
            self.plan, self.res, self.srcs, self.decisive = p, r, srcs, decisive

    def _propose(d, cap, base, src_res, use_vault=True):
        """propose + (seed_fn 있으면) 시드 머지 + (vault_fn 있고 use_vault면) 볼트 pruning. source-tag 부여.
        use_vault=False면 pruning 미적용(fail-open 재propose용). base = 현재 누적 plan(pruned_log 반사실 기준).
        src_res = diagnosis d를 만든 결과(트레이스) — retired/trapped를 **그 트레이스에서** 계산(R2 MEDIUM:
        LA2는 best가 아닌 res1 trace로 진단하므로 신호도 같은 trace에서 와야 위기가 올바르게 발화)."""
        # early 체인 게이트(model.propose `_has_early_arm`)는 **확정 plan**(closure)으로 판정 — speculative
        # base(LA2의 base2=plan+[c1])가 아니라. base2로 판정하면 LA2가 climber@early를 c1로 깔 때 early_armed가
        # 조기 발화해 boost가 2nd-step의 bridge(gap2 다리)를 max_n 밖으로 밀어내 **다중스킬 조합(climber+bridge)
        # 발견을 깨뜨린다**(stage20 실측: saved 1→0). 확정 plan에 early 무장이 든 뒤(=조합 발견 후)에만 체인
        # boost가 켜진다. forbid_pred(diverse)의 plan-aware base는 종전대로 base를 쓴다(아래 별도 인자).
        # ③ cell-up 같은-col 회피(T1)는 **speculative base**(LA2의 base2=plan+[c1] 포함)를 봐야 한다(plan-review
        # R3-H1) — early-chain closure(plan, 확정)와 직교한 별도 인자 cellup_base=base로 전달. 확정 plan만 보면
        # LA2 2nd-step이 같은-col 재스택(1/5 poison)을 제안할 수 있어 cellup_base에 base(speculative)를 넘긴다.
        cands = model.propose(layout, d, inv, metas, notes, exclude=tried, max_n=cap, plan=plan, cellup_base=base)
        if seed_fn:
            cands = _merge_seeded(seed_fn(layout, d, inv, metas), cands)[:cap]
        else:
            for c in cands:
                c.setdefault("source", "fallback")
        if forbidden:
            # 다양-해 탐색(Item 1): 이미 발견·보고된 해의 액션을 절대 배제(hard-filter) → 같은 인벤토리로
            # *다른* 배치/전략을 강제. exclude(tried)와 달리 ceiling/carry **면제도 무시**하는 절대 필터라
            # 모든 _propose 경로(main/sibling/LA2)에서 일관 적용된다. 후보가 0이 되면 솔버는 정직하게
            # 정지(= 더 이상 구별되는 해 없음) — 완전성 주장 아님(의도적 배제, 다양-해 보고 맥락).
            cands = [c for c in cands if _action_sig(c["action"]) not in forbidden]
        if forbid_pred is not None:
            # plan-level class forbid(diverse.py): `base+[action]`이 이미 발견된 solution-class를 *정확히
            # 완성*할 때만 배제(codex R2-HIGH — 슬롯 1개 공유하는 distinct class는 억제 안 함). base=현재 누적
            # plan을 넘겨 plan-aware. 모든 경로(main/sibling/LA2)에 일관 적용. 후보 0 → 정직 정지.
            cands = [c for c in cands if not forbid_pred(c["action"], base)]
        if vault_fn and use_vault:
            # 볼트가 위기→링크 도구/요소(retired/trapped 포함)로 형제 후보를 prune(de-risk 레버).
            tr = src_res.get("trace", {})
            retired = model.count_retired(tr, layout)
            ct, tt = model.count_trapped(tr)
            cands, pruned, pruned_acts = vault_fn(d, cands, retired, {"carry": ct, "total": tt})
            prov["vault_pruned"] += pruned
            for a in pruned_acts:
                prov["pruned_log"].append({"base": list(base), "action": a})
        return cands

    def eval_cands(base: list[dict], base_srcs: list[str], cands: list, tag: str, cap: int | None = None) -> list:
        """후보들을 base 플랜 위에 롤아웃. full clear면 _Clear로 즉시 탈출. 반환 (cand,res) 리스트.
        이미 base에 든 액션은 건너뛴다 — carry 후보는 exclude 면제(plan 누적 재평가)라, 채택돼 base에
        들어간 carry n이 다시 후보로 와도 중복 롤аут하지 않게 막는다(연쇄만 진행)."""
        # cap(codex impl R5): 이 호출이 도달 가능한 전역 rollouts 상한. main eval은 LA2 reserve를 남기도록
        # max_rollouts-LA2_RESERVE를 받고, baseline/LA2는 None(=max_rollouts). D2 보호가 후보를 per-round cap
        # 초과로 늘려도 main eval이 2-step lookahead(LA2) budget을 잠식하지 못하게(per-round cap contract 복원).
        limit = max_rollouts if cap is None else min(cap, max_rollouts)
        out: list = []
        for cand in cands:
            if rollouts >= limit:
                break
            if cand["action"] in base:        # 이미 채택된 액션 — 중복 롤아웃 방지
                continue
            tried.add(cand["label"])
            src = cand.get("source", "fallback")
            if src.startswith("seeded:"):
                prov["seeded_attempts"] += 1
            else:
                prov["fallback_attempts"] += 1
            res = rollout(base + [cand["action"]])
            ct, tt = model.count_trapped(res.get("trace", {}))
            print(f"  롤아웃 {rollouts}{tag}: +{cand['label']} [{src}] → {_fmt(res, hp)} trapped(carry/all)={ct}/{tt}")
            cleared_here = ("error" not in res) and is_full_clear(res, hp)
            prov["tried_log"].append({"base": list(base), "action": cand["action"], "cleared": bool(cleared_here)})
            if "error" in res:
                continue
            if is_full_clear(res, hp):
                if src.startswith("seeded:"):
                    prov["seeded_successes"] += 1
                else:
                    prov["fallback_successes"] += 1
                raise _Clear(base + [cand["action"]], res, base_srcs + [src], src)
            out.append((cand, res))
        return out

    # ②~④ 관측 → 진단 → 개입(라운드별 후보 평가 후 **최선** 채택) → 재관측 (상한까지).
    # 1-스텝이 정체하면 **2-스텝 lookahead**(사용자: S13/S14는 단일 개입이 일시적으로 악화[물 익사↑]된 뒤
    # 두 번째 개입으로 닫히므로 그리디로는 못 넘음 — 유망 first-step에서 재진단→second 평가).
    try:
        while rollouts < max_rollouts:
            diag = model.diagnose(best.get("trace", {}), layout, hp)
            cands = _propose(diag, min(max_rollouts - rollouts, 6), plan, best)
            # LA2 reserve(codex impl R5): 메인 평가가 LA2 budget을 잠식하지 않게 상한. 보호 미발동(up_cell 없음,
            # cands ≤ max_n)이면 메인 평가가 이 상한에 안 닿아 byte-identical(cap ≫ 6이면 무영향). 최소 1개는 보장.
            main_cap = max(rollouts + 1, max_rollouts - LA2_RESERVE)
            evaluated = eval_cands(plan, plan_sources, cands, "", cap=main_cap) if cands else []
            # 완전성 보장(re-review R3 HIGH): vault-preferred 집합을 **먼저** 평가한다 — 그 안에서 full-clear가
            # 나면 eval_cands가 즉시 _Clear로 단축(이게 유일한 절약: 클리어 라운드 early-exit). 하지만 개선 채택·
            # 정체 판단 *전에* prune된 형제(off>=1)까지 **반드시** 평가해 ON이 OFF와 동일 후보 풀에서 결정하게
            # 한다 → ON ⊇ OFF(완전성). pruning은 더 이상 후보를 영구 삭제하지 않고 "평가 순서 우선"으로만 작동.
            if vault_fn:
                cands_sib = _propose(diag, min(max_rollouts - rollouts, 6), plan, best, use_vault=False)
                if cands_sib:
                    # codex impl R6 [MEDIUM]: 메인 단계의 완전성 pass도 **같은 main_cap** 적용 — 안 그러면 sibling
                    # 평가가 LA2 reserve를 잠식해 R5 cap contract 회귀(vault_fn은 ARCHIVED·항상 None이라 dead path지만
                    # 일관성·정확성 위해 동일 상한 적용). LA2 단계의 (LA2-complete)는 이미 reserve를 쓰는 단계라 무관.
                    evaluated = evaluated + eval_cands(plan, plan_sources, cands_sib, "(complete)", cap=main_cap)
            if not evaluated:
                print("  [정지] 제안할 개입 후보 없음(진단으로 더 둘 곳 없음).")
                break
            cand, res = min(evaluated, key=lambda cr: score(cr[1], layout))
            if score(res, layout) < score(best, layout):
                plan = plan + [cand["action"]]
                plan_sources = plan_sources + [cand.get("source", "fallback")]
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
                base2 = plan + [c1["action"]]
                srcs2 = plan_sources + [c1.get("source", "fallback")]
                cands2 = _propose(diag1, min(max_rollouts - rollouts, 4), base2, res1)
                ev2 = eval_cands(base2, srcs2, cands2, "(LA2)") if cands2 else []
                # 완전성(R3 HIGH): LA2 second-step도 prune된 형제 복원·평가 → second-step 풀도 ON ⊇ OFF.
                if vault_fn:
                    cands2_sib = _propose(diag1, min(max_rollouts - rollouts, 4), base2, res1, use_vault=False)
                    if cands2_sib:
                        ev2 = ev2 + eval_cands(base2, srcs2, cands2_sib, "(LA2-complete)")
                for c2, res2 in ev2:
                    if score(res2, layout) < score(best, layout) and (
                            combo is None or score(res2, layout) < score(combo[2], layout)):
                        combo = (c1, c2, res2)
            if combo is not None:
                c1, c2, res2 = combo
                plan = plan + [c1["action"], c2["action"]]
                plan_sources = plan_sources + [c1.get("source", "fallback"), c2.get("source", "fallback")]
                best = res2
                print(f"    채택(LA2): +{c1['label']}+{c2['label']} → plan={[a.get('skill') for a in plan]}")
                continue
            print("  [정지] 1-스텝·2-스텝 모두 진척을 못 냄.")
            break
    except _Clear as c:
        prov["decisive_origin"] = c.decisive
        prov["plan_sources"] = c.srcs
        prov["final_plan"] = c.plan
        if stats is not None:
            stats.update(prov, rollouts=rollouts, cleared=True)
        return _save(stage_id, stage_scene, deadline, inv, c.plan, c.res, rollouts, hp, layout, meta["total_ants"], save=save)

    # 상한 도달 또는 정체 — 100% 미달 → 체크포인트. 최고 기록 시도의 리타이어 개미·사용 도구 수도 보고.
    prov["plan_sources"] = plan_sources
    prov["final_plan"] = plan
    if stats is not None:
        stats.update(prov, rollouts=rollouts, cleared=False)
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


def _save(stage_id, stage_scene, deadline, inv, plan, res, rollouts, hp, layout, total_ants, save=True) -> int:
    rt = model.count_retired(res.get("trace", {}), layout)
    tools = len(plan)
    if not save:
        # 벤치(read-only A/B): 기존 게이트 산출물 stageNN.solve.json을 덮어쓰지 않는다.
        print(f"\nSOLVED(100%, no-save) stage{stage_id:02d}: saved={res.get('saved')}/{hp} | "
              f"사용 도구={tools} | rollouts={rollouts} | skills={[a.get('skill') for a in plan]}")
        return 0
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
