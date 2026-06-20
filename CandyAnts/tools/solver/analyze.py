#!/usr/bin/env python3
"""
auto-solver Phase 3a — 최소화 + 반응-윈도우 측정 (analyze.py).

발견된 해(`data/solutions/stageNN.solve.json`)를 입력으로 **순수 오케스트레이터**로 동작한다(엔진=진실 D4,
게임 verdict만 신뢰). 산출 = `data/solutions/stageNN.analysis.json`.

  (A) 최소화 = deletion-minimal(1-minimal): 액션을 고정 순서로 하나씩 제거 → 여전히 full clear면 잉여
      (확정 시 candidate에서 빼고 진행 = 1-minimal 보장), 깨지면 필수. 산출 = 1-minimal 플랜 + 잉여 목록.
      `--prove-cardinality`(opt-in·기본 off·verify 미포함) 시 부분집합 브루트포스로 cardinality-minimal 증명.
  (B) 윈도우 측정 = spawn_index 고정 + at_frame_exact 스윕(시간 1급) + ant_reaches_x x-스윕(위치 보조).
      baseline(1-minimal)을 report_fired+trace로 1회 돌려 각 필수 액션의 (spawn_index*, f*)·대상을 깨끗이
      획득(가산① — stdout regex 불요). 거친 격자 bracket + 경계 binary 정밀 + 비연속(gap) 검출. 스윕 예산
      cap 초과 시 incomplete:true(하한만) 정직 보고.
  (C) T_human 분류 = provisional: 시간 윈도우 폭(초)을 capabilities.tres 티어와 비교(미보정 기본값 →
      tier_source="default_uncalibrated", 기계전용 임계 미만 = provisional_machine_only_flag).
  (D) 리포트 = analysis.json(아래 스키마) + 콘솔 요약.
  (E) 게이트 = `analyze.py --verify`: 저장된 analysis.json을 싸게 재검증 — coverage 선검증(index/label
      1:1, incomplete 필수 액션 0) + 액션별 interval 내부=clear / 양 끝 밖=fail / gap 내부=fail 리플레이 +
      1-minimal 자체 클리어(D4). incomplete:true 필수 액션 있으면 FAIL(미완 측정을 통과로 위장 금지).

Usage:
    GODOT_BIN=... python tools/solver/analyze.py 11                 # stage11 측정 → analysis.json
    GODOT_BIN=... python tools/solver/analyze.py --all              # 모든 발견 해(solve.json) 측정
    GODOT_BIN=... python tools/solver/analyze.py 14 --prove-cardinality --workers 6
    GODOT_BIN=... python tools/solver/analyze.py --verify           # 모든 analysis.json 게이트 재검증
    GODOT_BIN=... python tools/solver/analyze.py --verify 11        # stage11만 재검증
    (선택) --labels "11,13,12,14"  # 사용자 난이도 순위(쉬움→어려움) pre-register → Spearman 대조(게이트 아님)

Exit: 0=성공(측정/검증) / 1=에러 또는 verify FAIL.
"""
from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import threading
from concurrent.futures import ThreadPoolExecutor
from itertools import combinations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUN_TEST = ROOT / "scripts" / "run_test.py"
PLAN_HARNESS = "tests/PlanReplayHarness.tscn"
SOLUTIONS_DIR = ROOT / "data" / "solutions"
CAPS_TRES = ROOT / "data" / "solver" / "capabilities.tres"
PHYS_FPS = 60

# 측정 기본 파라미터. 윈도우는 보통 f* 주변 연속 구간 → 기하 확장으로 도메인을 적응적으로 잡고 경계만 정밀.
TIME_CAP = 80          # 시간 윈도우 액션당 롤아웃 상한(초과 시 incomplete)
POS_CAP = 60           # 위치 윈도우 액션당 상한
GAP_PROBES = 8         # [lo,hi] 내부 비연속(gap) 검출 샘플 수
PROBE_OFFSETS = [16, 32, 64, 128, 256, 512, 1024, 2048]   # 도메인 기하 확장 step(시간)
POS_PROBE_OFFSETS = [12, 24, 48, 96, 192, 384, 768]       # 위치(px) 기하 확장 step
MINIMIZE_SUBSET_CAP = 8   # cardinality 증명 허용 최대 액션 수


# ============================================================ 엔진 롤아웃 (D4 verdict)

class Rollouter:
    """PlanReplayHarness 헤드리스 롤아웃 실행기. 각 롤아웃 = 독립 subprocess(PlanRunner의 static
    단일-활성-런 가드는 프로세스-전역이라 subprocess가 병렬 안전; run_test.py가 pid별 save 경로 격리).
    배치(batch_exec)는 ThreadPoolExecutor로 병렬화 — 도메인 거친 격자·최소화 trial 등 독립 롤아웃 가속."""

    def __init__(self, stage: str, deadline: int, required_saved: int, workers: int):
        self.stage = stage
        self.deadline = deadline
        self.required = required_saved
        self.workers = max(1, workers)
        self.count = 0
        self._lock = threading.Lock()

    def exec_one(self, actions: list[dict], trace: bool = False, report_fired: bool = False) -> dict:
        plan: dict = {"stage": self.stage, "deadline_frames": self.deadline, "actions": actions}
        if trace:
            plan["trace"] = True
        if report_fired:
            plan["report_fired"] = True
        res = self._run(plan)
        if "error" in res:        # 일시 오류(드문 stdout 누락) 1회 재시도 — 거짓 경계 방지.
            res = self._run(plan)
        with self._lock:
            self.count += 1
        return res

    def _run(self, plan: dict) -> dict:
        with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
            json.dump(plan, f)
            plan_path = f.name
        env = os.environ.copy()
        env["CANDYANTS_PLAN_PATH"] = plan_path
        env["CANDYANTS_DETERMINISTIC"] = "1"
        try:
            p = subprocess.run(
                [sys.executable, str(RUN_TEST), PLAN_HARNESS, "--fixed-fps", "60"],
                capture_output=True, text=True, encoding="utf-8", errors="replace",
                cwd=str(ROOT), env=env,
            )
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

    def clears(self, actions: list[dict]) -> bool:
        return is_full_clear(self.exec_one(actions), self.required)

    def batch_clears(self, plans: list[list[dict]]) -> list[bool]:
        if not plans:
            return []
        with ThreadPoolExecutor(max_workers=self.workers) as ex:
            results = list(ex.map(self.exec_one, plans))
        return [is_full_clear(r, self.required) for r in results]


def is_full_clear(res: dict, required_saved: int) -> bool:
    """solve.py와 동일 잣대 — cleared & saved >= 목표 hp. error/미발화는 비클리어."""
    return bool(res.get("cleared")) and int(res.get("saved", 0)) >= required_saved


# ============================================================ 능력 명세 (T_human)

def load_caps() -> dict:
    txt = CAPS_TRES.read_text(encoding="utf-8")
    def g(name: str, dflt: float) -> float:
        m = re.search(name + r"\s*=\s*([\d.]+)", txt)
        return float(m.group(1)) if m else dflt
    return {
        "comfortable_s": g("t_human_comfortable_s", 0.30),
        "hard_s": g("t_human_hard_s", 0.15),
        "machine_only_s": g("t_human_machine_only_s", 0.10),
        "tier_source": "default_uncalibrated",
    }


def classify_tier(width_s: float, caps: dict) -> tuple[str, list[str]]:
    """시간 윈도우 폭 → 티어 + provisional 플래그. machine_only 임계 미만 = 기계전용 의심(확정 아님)."""
    flags: list[str] = []
    if width_s >= caps["comfortable_s"]:
        tier = "comfortable"
    elif width_s >= caps["hard_s"]:
        tier = "hard"
    elif width_s >= caps["machine_only_s"]:
        tier = "tight"
    else:
        tier = "machine_only"
    if width_s < caps["machine_only_s"]:
        flags.append("provisional_machine_only_flag")
    return tier, flags


# ============================================================ 플랜 재구성 (측정·검증 공유)

def sweep_time_plan(minimal: list[dict], idx: int, sweep_target: dict, frame: int) -> list[dict]:
    """1-minimal 플랜에서 액션 idx만 spawn_index 고정 + at_frame_exact{frame}로 치환. 나머지 액션은
    baseline 그대로(원본 트리거) — "그 액션 단독 여유" 측정(plan §스윕 가정 ①). 측정·검증이 동일 함수를
    써 결정론 리플레이가 byte-identical(같은 plan → 같은 verdict)."""
    plan = [dict(a) for a in minimal]
    plan[idx] = {
        "skill": minimal[idx]["skill"],
        "target": dict(sweep_target),
        "trigger": {"type": "at_frame_exact", "frame": int(frame)},
    }
    return plan


def sweep_pos_plan(minimal: list[dict], idx: int, x: float) -> list[dict]:
    """위치 윈도우 — 액션 idx의 원본 ant_reaches_x 트리거의 x만 스윕(select/cmp 보존). 나머지 baseline."""
    plan = [dict(a) for a in minimal]
    orig = minimal[idx]
    trig = dict(orig.get("trigger", {}))
    trig["x"] = float(x)
    plan[idx] = {"skill": orig["skill"], "target": orig.get("target", {}), "trigger": trig}
    return plan


def make_sweep_target(orig_target: dict, spawn_index: int) -> dict:
    """원본 ant target → spawn_index 고정 스윕 target. **state만 보존**(없으면 "any"): 기본 "walker"면
    스윕 프레임에 carrying 개미가 미선택돼 S13류가 깨짐(R2-H2). y_min/y_max/dir은 **드롭** — 그건 원본의
    *공간 선택 수단*인데, spawn_index로 그 개미를 직접 핀하므로 보존하면 스윕 프레임에 개미가 밴드 밖이라
    잘못 배제된다(_select_ant가 y-band를 spawn_index 매칭 전에 거르기 때문). 즉 select 차원만 교체."""
    state = orig_target.get("state")
    return {
        "mode": "ant",
        "select": "spawn_index",
        "spawn_index": int(spawn_index),
        "state": state if state else "any",
    }


# ============================================================ (A) 최소화

def minimize(roll: Rollouter, actions: list[dict]) -> tuple[list[dict], list[dict]]:
    """deletion-minimal(1-minimal). 고정 순서로 각 액션 제거 시도 → 여전히 클리어면 잉여(즉시 candidate
    에서 제거하고 진행 — 대체가능 A/B 동시 오분류 회피), 깨지면 필수. 반환 (1-minimal, redundant)."""
    working = list(actions)
    redundant: list[dict] = []
    print("[analyze] (A) 최소화 (deletion-minimal, %d 액션)" % len(actions))
    for orig_i, act in enumerate(actions):
        if not any(a is act for a in working):    # 이미 제거됨(identity; 동등-중복 dict 방어)
            continue
        trial = [a for a in working if a is not act]
        ok = roll.clears(trial)
        label = "%s#%d" % (str(act.get("skill", "?")), orig_i)
        if ok:
            working = trial
            redundant.append({"orig_index": orig_i, "label": label, "skill": act.get("skill")})
            print("    - %s 제거 → 여전히 클리어 = 잉여(드롭)" % label)
        else:
            print("    - %s 제거 → 깨짐 = 필수(유지)" % label)
    print("[analyze]   1-minimal = %d 액션, 잉여 = %d" % (len(working), len(redundant)))
    return working, redundant


def prove_cardinality(roll: Rollouter, minimal: list[dict]) -> tuple[str, dict]:
    """opt-in 부분집합 브루트포스로 cardinality-minimal 증명. 1-minimal보다 *더 작은* 부분집합이 클리어
    하면 그게 더 적은 액션 = deletion-minimal은 cardinality-minimal이 아님. 작은 크기부터 검사해 조기종료.
    어떤 size<len도 클리어 못 하면 = cardinality-minimal 증명. plan-hash 캐시(부분집합 인덱스 frozenset)."""
    n = len(minimal)
    meta: dict = {"checked_subsets": 0, "max_size_searched": 0}
    if n > MINIMIZE_SUBSET_CAP:
        meta["skipped"] = "len %d > cap %d" % (n, MINIMIZE_SUBSET_CAP)
        print("[analyze] (A') cardinality 증명 생략: %s" % meta["skipped"])
        return "1-minimal", meta
    print("[analyze] (A') cardinality 증명 (부분집합 브루트포스, n=%d)" % n)
    seen: set = set()
    for k in range(1, n):    # 1..n-1 (n 자신은 1-minimal 자체)
        subsets = list(combinations(range(n), k))
        plans = []
        keys = []
        for combo in subsets:
            key = frozenset(combo)
            if key in seen:
                continue
            seen.add(key)
            keys.append(combo)
            plans.append([minimal[i] for i in combo])
        meta["max_size_searched"] = k
        meta["checked_subsets"] += len(plans)
        oks = roll.batch_clears(plans)
        for combo, ok in zip(keys, oks):
            if ok:
                meta["smaller_clearing_subset"] = list(combo)
                meta["cardinality"] = k
                print("    ! size %d 부분집합 %s 가 클리어 → 1-minimal은 cardinality-minimal 아님" % (k, list(combo)))
                return "1-minimal", meta   # 측정 플랜은 1-minimal 유지(재측정 회피); 발견만 보고
        print("    - size %d: %d 부분집합 모두 비클리어" % (k, len(plans)))
    meta["cardinality"] = n
    print("[analyze]   cardinality-minimal 증명 (어떤 %d 미만 부분집합도 클리어 못 함)" % n)
    return "cardinality-minimal", meta


# ============================================================ (B) 윈도우 측정

def _even_points(lo: int, hi: int, n: int) -> list[int]:
    """[lo,hi] 내부 균등 n점(양 끝 제외)."""
    if hi - lo <= 1 or n <= 0:
        return []
    step = (hi - lo) / (n + 1)
    return sorted({int(round(lo + step * (i + 1))) for i in range(n)})


def measure_time_window(roll: Rollouter, idx: int, minimal: list[dict], sweep_target: dict,
                        f_star: int, deadline: int, required: int, cap: int) -> dict:
    """액션 idx의 시간 윈도우(at_frame_exact 스윕). f* 주변 기하 확장으로 도메인 bracket → 경계 binary
    정밀 → 내부 gap 검출. cap 초과 = incomplete(하한만)."""
    cache: dict[int, bool] = {}
    used = [0]
    incomplete = [False]

    def test(f: int):
        f = int(f)
        if f < 1 or f > deadline:
            return False                      # frame 0 = 영영 미발화 / deadline 초과 = 비클리어(자연 경계)
        if f in cache:
            return cache[f]
        if used[0] >= cap:
            incomplete[0] = True
            return None
        used[0] += 1
        ok = is_full_clear(roll.exec_one(sweep_time_plan(minimal, idx, sweep_target, f)), required)
        cache[f] = ok
        return ok

    def test_batch(frames):
        todo = sorted({int(x) for x in frames if 1 <= int(x) <= deadline and int(x) not in cache})
        if not todo:
            return
        allow = max(0, cap - used[0])
        if len(todo) > allow:
            incomplete[0] = True
            todo = todo[:allow]
        if not todo:
            return
        used[0] += len(todo)
        oks = roll.batch_clears([sweep_time_plan(minimal, idx, sweep_target, f) for f in todo])
        for f, ok in zip(todo, oks):
            cache[f] = ok

    # baseline pin은 반드시 클리어해야 한다(같은 개미·같은 프레임 재현). 아니면 측정 불가 → 정직 incomplete.
    if test(f_star) is not True:
        return {"lo": f_star, "hi": f_star, "width_frames": 0, "width_s": 0.0,
                "intervals": [], "gaps": [], "incomplete": True,
                "domain": [f_star, f_star], "note": "baseline_pin_did_not_clear"}

    # 도메인 거친 격자(병렬) — f* ± 기하 offset. 이후 expand가 캐시 재사용(추가 롤아웃 최소).
    test_batch([f_star - o for o in PROBE_OFFSETS] + [f_star + o for o in PROBE_OFFSETS])

    def expand(direction: int) -> tuple:
        """f*에서 direction(+1/-1)으로 기하 확장해 가장 가까운 fail을 찾는다. (last_clear, fail_or_bound)."""
        step = 16
        last_clear = f_star
        f = f_star
        while True:
            f = f + direction * step
            if f < 1:
                return last_clear, 0           # 하한(frame 0 = 미발화 fail)
            if f > deadline:
                return last_clear, deadline + 1
            r = test(f)
            if r is None:
                return last_clear, None        # cap → incomplete
            if r:
                last_clear = f
                step *= 2
            else:
                return last_clear, f

    def refine(clear_f: int, fail_f: int) -> int:
        """clear_f(클리어)와 fail_f(비클리어) 사이 경계를 binary로 1프레임 정밀화 → 가장 바깥 클리어 프레임."""
        a, b = clear_f, fail_f                 # a 클리어, b 비클리어
        while abs(b - a) > 1:
            mid = (a + b) // 2
            r = test(mid)
            if r is None:
                break
            if r:
                a = mid
            else:
                b = mid
        return a

    left_clear, left_fail = expand(-1)
    right_clear, right_fail = expand(+1)
    lo = refine(left_clear, left_fail) if left_fail is not None else left_clear
    hi = refine(right_clear, right_fail) if right_fail is not None else right_clear
    domain = [left_fail if left_fail is not None else lo,
              right_fail if right_fail is not None else hi]

    # 내부 비연속(gap) 검출 — [lo,hi] 균등 샘플(병렬). 모두 클리어면 단일 interval(현 S11~S14 기대).
    test_batch(_even_points(lo, hi, GAP_PROBES))
    intervals, gaps = _reconstruct_runs(test, lo, hi, cache)

    widths = [b - a + 1 for a, b in intervals]
    width_frames = max(widths) if widths else 0
    return {
        "lo": lo, "hi": hi,
        "width_frames": width_frames,
        "width_s": round(width_frames / PHYS_FPS, 4),
        "intervals": intervals, "gaps": gaps,
        "incomplete": incomplete[0],
        "domain": domain,
        "rollouts": used[0],
    }


def _reconstruct_runs(test, lo: int, hi: int, cache: dict) -> tuple[list, list]:
    """[lo,hi](양 끝 클리어 보장) 내 캐시 샘플로 clear/fail run 복원. 인접 샘플 값이 다르면 전이 경계를
    binary 정밀화 → intervals(clear run) + gaps(fail run). 내부 fail 없으면 단일 interval."""
    pts = sorted({lo, hi} | {f for f in cache if lo <= f <= hi})
    vals = {f: cache.get(f) for f in pts}
    vals[lo] = True
    vals[hi] = True
    # 인접 전이 정밀화 → 경계쌍 (a:클리어/fail, b:반대) 수집.
    edges: list[tuple] = []   # (boundary_low_frame, boundary_high_frame) where value flips
    i = 0
    refined_pts = list(pts)
    while i < len(refined_pts) - 1:
        fa, fb = refined_pts[i], refined_pts[i + 1]
        va, vb = vals[fa], vals[fb]
        if va is None or vb is None or va == vb:
            i += 1
            continue
        a, b = fa, fb
        while b - a > 1:
            mid = (a + b) // 2
            r = test(mid)
            if r is None:
                break
            vals[mid] = r
            if r == va:
                a = mid
            else:
                b = mid
        edges.append((a, b))    # a=va, b=vb, b-a==1 (or cap-truncated)
        i += 1
    # lo부터 클리어 시작 → 경계마다 토글하며 interval/gap 구간 구성.
    intervals: list[list[int]] = []
    gaps: list[list[int]] = []
    cur_start = lo
    cur_val = True
    for a, b in edges:
        if cur_val:
            intervals.append([cur_start, a])     # 클리어 구간은 a(마지막 클리어)에서 끝
            cur_start = b                        # b부터 fail
        else:
            gaps.append([cur_start, a])          # fail 구간은 a(마지막 fail)에서 끝
            cur_start = b                        # b부터 클리어
        cur_val = not cur_val
    if cur_val:
        intervals.append([cur_start, hi])
    else:
        gaps.append([cur_start, hi])             # 이론상 hi는 클리어라 도달 안 함(방어)
    return intervals, gaps


def _reachable_x_domain(trace: dict, spawn_index: int, cs: int) -> tuple[int, int]:
    """개미 si의 trace 셀-x 범위 → 위치 스윕 도메인(px). trace 부재 시 보수적 광역 [0, 60셀]."""
    entries = trace.get(str(spawn_index)) or trace.get(spawn_index)
    if not entries:
        return 0, 60 * cs
    cxs = [e[1] for e in entries]
    return min(cxs) * cs, (max(cxs) + 1) * cs - 1


def measure_pos_window(roll: Rollouter, idx: int, minimal: list[dict], baseline_x: float,
                       spawn_index: int, trace: dict, cs: int, x_dom: tuple[int, int],
                       required: int, cap: int) -> dict:
    """위치 윈도우(공간 보조, ant_reaches_x 한정 — verify 게이트 비포함). 원본 트리거 x를 스윕 → 클리어
    x 구간 [lo_x,hi_x]. **도메인은 개미가 실제 도달하는 x 범위(trace)로 제한** — ge/le는 단방향 임계라
    무한 스윕하면 "즉시 발화"로 포화(개미가 닿지 않는 좌표는 물리적 무의미)되므로, 도달 범위 밖은 측정
    대상이 아니다. 경계가 도메인 끝에 닿으면 `saturated_lo/hi`로 정직 표기(그 방향 무제한). baseline trace로
    그 개미가 그 셀 범위 지나는 frame을 cell-bracket 교차검증(정보용; 프레임-정확은 report_fired가 authority)."""
    cache: dict[int, bool] = {}
    used = [0]
    incomplete = [False]
    x_lo_dom, x_hi_dom = x_dom

    def test(x: int):
        x = int(x)
        if x < x_lo_dom or x > x_hi_dom:
            return False
        if x in cache:
            return cache[x]
        if used[0] >= cap:
            incomplete[0] = True
            return None
        used[0] += 1
        ok = is_full_clear(roll.exec_one(sweep_pos_plan(minimal, idx, x)), required)
        cache[x] = ok
        return ok

    def test_batch(xs):
        todo = sorted({int(v) for v in xs if x_lo_dom <= int(v) <= x_hi_dom and int(v) not in cache})
        if not todo:
            return
        allow = max(0, cap - used[0])
        if len(todo) > allow:
            incomplete[0] = True
            todo = todo[:allow]
        if not todo:
            return
        used[0] += len(todo)
        oks = roll.batch_clears([sweep_pos_plan(minimal, idx, x) for x in todo])
        for x, ok in zip(todo, oks):
            cache[x] = ok

    x0 = int(round(baseline_x))
    x0 = max(x_lo_dom, min(x_hi_dom, x0))
    if test(x0) is not True:
        return {"baseline_x": baseline_x, "lo_x": x0, "hi_x": x0, "width_x": 0, "width_cells": 0.0,
                "intervals": [], "gaps": [], "incomplete": True, "domain": [x_lo_dom, x_hi_dom],
                "note": "baseline_x_did_not_clear"}
    test_batch([x0 - o for o in POS_PROBE_OFFSETS] + [x0 + o for o in POS_PROBE_OFFSETS])

    def expand(direction: int) -> tuple:
        """(last_clear, fail_or_None, saturated). 도메인 끝까지 클리어면 saturated=True(fail None)."""
        step = 12
        last_clear = x0
        x = x0
        while True:
            nx = x + direction * step
            if nx < x_lo_dom or nx > x_hi_dom:
                # 도메인 edge까지 클리어 확장 — edge 자체를 테스트해 거기서도 클리어면 포화.
                edge = x_lo_dom if direction < 0 else x_hi_dom
                if edge != last_clear and test(edge) is True:
                    last_clear = edge
                return last_clear, None, True
            r = test(nx)
            if r is None:
                return last_clear, None, True       # cap → 미완(포화로 보고, incomplete 플래그 동반)
            if r:
                last_clear = nx
                step *= 2
                x = nx
            else:
                return last_clear, nx, False

    def refine(clear_x: int, fail_x: int) -> int:
        a, b = clear_x, fail_x
        while abs(b - a) > 1:
            mid = (a + b) // 2
            r = test(mid)
            if r is None:
                break
            if r:
                a = mid
            else:
                b = mid
        return a

    lc, lf, sat_lo = expand(-1)
    rc, rf, sat_hi = expand(+1)
    lo_x = refine(lc, lf) if lf is not None else lc
    hi_x = refine(rc, rf) if rf is not None else rc

    cell_bracket = None
    entries = trace.get(str(spawn_index)) or trace.get(spawn_index)
    if entries:
        lo_cell = int(math.floor(lo_x / cs))
        hi_cell = int(math.floor(hi_x / cs))
        frs = [e[0] for e in entries if lo_cell <= e[1] <= hi_cell]
        if frs:
            cell_bracket = [min(frs), max(frs)]
    return {
        "baseline_x": baseline_x,
        "lo_x": lo_x, "hi_x": hi_x,
        "width_x": hi_x - lo_x,
        "width_cells": round((hi_x - lo_x) / cs, 3),
        "intervals": [[lo_x, hi_x]], "gaps": [],
        "saturated_lo": sat_lo, "saturated_hi": sat_hi,
        "domain": [x_lo_dom, x_hi_dom],
        "cell_bracket_frames": cell_bracket,
        "incomplete": incomplete[0],
        "rollouts": used[0],
    }


# ============================================================ (D) 오케스트레이션

def analyze_stage(stage_id: int, args) -> int:
    solve_path = SOLUTIONS_DIR / f"stage{stage_id:02d}.solve.json"
    if not solve_path.exists():
        print("[analyze] solve.json 없음: %s" % solve_path.relative_to(ROOT))
        return 1
    solve = json.loads(solve_path.read_text(encoding="utf-8"))
    stage = solve["stage"]
    deadline = int(solve["deadline_frames"])
    orig_actions = solve["actions"]
    required = int(solve.get("result", {}).get("hp", solve.get("expect", {}).get("saved", 0)))
    if required < 1:
        print("[analyze] required_saved 미상(result.hp/expect.saved 없음)")
        return 1
    caps = load_caps()
    roll = Rollouter(stage, deadline, required, args.workers)

    print("=== analyze stage%02d (최소화 + 윈도우 측정) ===" % stage_id)
    print("  stage=%s deadline=%d required_saved=%d actions=%d workers=%d" % (
        stage, deadline, required, len(orig_actions), args.workers))

    # (A) 최소화
    minimal, redundant = minimize(roll, orig_actions)
    if not roll.clears(minimal):
        print("[analyze] FATAL: 1-minimal 플랜이 클리어 안 됨(최소화 버그)")
        return 1
    minimal_kind, card_meta = "1-minimal", None
    if args.prove_cardinality:
        minimal_kind, card_meta = prove_cardinality(roll, minimal)

    # baseline(1-minimal) 1회 — report_fired + trace 동시(가산①·trace). f*·대상·cell-bracket 원천.
    base = roll.exec_one(minimal, trace=True, report_fired=True)
    if not is_full_clear(base, required):
        print("[analyze] FATAL: baseline(report_fired) 비클리어:", base.get("reason"), base.get("error"))
        return 1
    fired = {int(e.get("index", -1)): e for e in base.get("fired_actions", [])}
    trace = base.get("trace", {})
    cs = int(base.get("cell_size", 48))
    print("[analyze] baseline 1-minimal: cleared frame=%s fired=%d" % (base.get("frame"), len(fired)))

    # (B)+(C) 액션별 윈도우 + 티어
    print("[analyze] (B) 윈도우 측정 (%d 필수 액션)" % len(minimal))
    per_action: list[dict] = []
    for idx, act in enumerate(minimal):
        skill = str(act.get("skill", "?"))
        label = "%s#%d" % (skill, idx)
        trig_type = str(act.get("trigger", {}).get("type", ""))
        fe = fired.get(idx)
        if fe is None:
            print("    [%s] baseline 미발화 → incomplete(측정 불가)" % label)
            per_action.append({
                "index": idx, "label": label, "skill": skill, "trigger_axis": "time",
                "target": {"kind": "unknown"}, "baseline_frame": None, "sweep_target": None,
                "time_window": {"lo": None, "hi": None, "width_frames": 0, "width_s": 0.0,
                                "intervals": [], "gaps": [], "incomplete": True,
                                "note": "not_fired_in_baseline"},
                "pos_window": None, "tier": "unknown", "tier_source": caps["tier_source"],
                "provisional_flags": [],
            })
            continue
        f_star = int(fe.get("frame", -1))
        kind = str(fe.get("target_kind", "ant"))
        if kind == "cell":
            target = {"kind": "cell", "target_cell": fe.get("target_cell")}
            sweep_target = dict(act.get("target", {}))    # 셀 고정 — 그대로(spawn_index 불요)
            axis = "time"
        else:
            si = int(fe.get("spawn_index", -1))
            target = {"kind": "ant", "spawn_index": si, "target_pos": fe.get("target_pos")}
            sweep_target = make_sweep_target(act.get("target", {}), si)
            axis = "time+pos" if trig_type == "ant_reaches_x" else "time"

        tw = measure_time_window(roll, idx, minimal, sweep_target, f_star, deadline, required, args.cap)
        pw = None
        if axis == "time+pos":
            x_dom = _reachable_x_domain(trace, target["spawn_index"], cs)
            pw = measure_pos_window(roll, idx, minimal, float(act["trigger"].get("x", 0.0)),
                                    target["spawn_index"], trace, cs, x_dom, required, args.pos_cap)
        if tw["incomplete"]:
            tier, flags = "unknown", []
        else:
            tier, flags = classify_tier(tw["width_s"], caps)
        per_action.append({
            "index": idx, "label": label, "skill": skill, "trigger_axis": axis,
            "target": target, "baseline_frame": f_star, "sweep_target": sweep_target,
            "time_window": tw, "pos_window": pw,
            "tier": tier, "tier_source": caps["tier_source"], "provisional_flags": flags,
        })
        wd = "incomplete" if tw["incomplete"] else "%.4fs (%s)" % (tw["width_s"], tier)
        extra = ""
        if pw is not None:
            extra = " | pos=[%s,%s] %.2f셀%s" % (pw["lo_x"], pw["hi_x"], pw["width_cells"],
                                                 " incomplete" if pw["incomplete"] else "")
        print("    [%s] f*=%d 시간윈도우 %s intervals=%s gaps=%s%s" % (
            label, f_star, wd, tw["intervals"], tw["gaps"], extra))

    # 스테이지 최소 윈도우(완성된 필수 액션 한정).
    done = [p for p in per_action if not p["time_window"]["incomplete"]]
    stage_min = min((p["time_window"]["width_s"] for p in done), default=None)
    stage_flags = []
    if stage_min is not None and stage_min < caps["machine_only_s"]:
        stage_flags.append("provisional_machine_only_flag")
    any_incomplete = any(p["time_window"]["incomplete"] for p in per_action)

    analysis = {
        "solution_ref": str(solve_path.relative_to(ROOT)).replace("\\", "/"),
        "stage": stage,
        "deadline_frames": deadline,
        "required_saved": required,
        "physics_fps": PHYS_FPS,
        "minimal_kind": minimal_kind,
        "minimal_plan": minimal,
        "redundant": redundant,
        "baseline": {"cleared": True, "saved": int(base.get("saved", 0)), "frame": int(base.get("frame", -1))},
        "per_action": per_action,
        "stage_min_window_s": stage_min,
        "stage_provisional_flags": stage_flags,
        "any_incomplete": any_incomplete,
        "capabilities": caps,
        "sweep_meta": {
            "time_cap": args.cap, "pos_cap": args.pos_cap, "gap_probes": GAP_PROBES,
            "probe_offsets": PROBE_OFFSETS, "total_rollouts": roll.count,
        },
    }
    if card_meta is not None:
        analysis["cardinality_meta"] = card_meta

    out_path = SOLUTIONS_DIR / f"stage{stage_id:02d}.analysis.json"
    out_path.write_text(json.dumps(analysis, indent=2, ensure_ascii=False), encoding="utf-8")
    print("[analyze] 저장 → %s (%s, stage_min_window=%s, rollouts=%d)" % (
        out_path.relative_to(ROOT), minimal_kind,
        "n/a" if stage_min is None else "%.4fs" % stage_min, roll.count))
    if any_incomplete:
        print("[analyze] ⚠ incomplete 필수 액션 존재 — verify는 FAIL 처리(cap 상향 또는 --allow-incomplete 재측정 필요)")
    return 0


# ============================================================ (E) 게이트 — analyze.py --verify

def _coverage_check(analysis: dict) -> list[str]:
    """index/label 1:1 coverage + incomplete 필수 액션 0 선검증(plan §E·R3-M2). 위반 메시지 목록."""
    fails: list[str] = []
    minimal = analysis.get("minimal_plan", [])
    per = analysis.get("per_action", [])
    if len(per) != len(minimal):
        fails.append("per_action %d != minimal_plan %d" % (len(per), len(minimal)))
    seen: set = set()
    for p in per:
        idx = p.get("index")
        if idx in seen:
            fails.append("duplicate per_action index %s" % idx)
        seen.add(idx)
        if not isinstance(idx, int) or idx < 0 or idx >= len(minimal):
            fails.append("per_action index %s out of range" % idx)
            continue
        exp_label = "%s#%d" % (str(minimal[idx].get("skill", "?")), idx)
        if str(p.get("label")) != exp_label:
            fails.append("label %r != expected %r (idx %d)" % (p.get("label"), exp_label, idx))
        tw = p.get("time_window", {})
        if tw.get("incomplete"):
            fails.append("필수 액션 %s incomplete=true (미완 측정 통과 위장 금지)" % p.get("label"))
        elif not tw.get("intervals"):
            fails.append("필수 액션 %s time_window.intervals 비어있음" % p.get("label"))
    missing = set(range(len(minimal))) - seen
    if missing:
        fails.append("per_action 누락 index %s" % sorted(missing))
    return fails


def _selfcheck_gate() -> bool:
    """coverage 검출기(`_coverage_check`)의 음성/양성 자가검증 — fail-open 회귀 방지(solve.py
    `_selfcheck_schema` 선례). 검출기가 약해지면 verify 자체가 먼저 FAIL한다. 양성 1 + 음성 6."""
    def good() -> dict:
        return {
            "minimal_plan": [{"skill": "blocker"}, {"skill": "climber"}],
            "per_action": [
                {"index": 0, "label": "blocker#0", "sweep_target": {},
                 "time_window": {"incomplete": False, "intervals": [[10, 20]]}},
                {"index": 1, "label": "climber#1", "sweep_target": {},
                 "time_window": {"incomplete": False, "intervals": [[30, 40]]}},
            ],
        }
    cases: list[tuple] = [(good(), False)]   # (analysis, should_reject)
    # 음성 변형들 — 각각 거부되어야 함.
    a = good(); a["per_action"].pop(); cases.append((a, True))                       # count mismatch / 누락
    a = good(); a["per_action"][1]["index"] = 0; cases.append((a, True))             # duplicate index
    a = good(); a["per_action"][1]["index"] = 9; cases.append((a, True))             # out of range
    a = good(); a["per_action"][0]["label"] = "wrong#0"; cases.append((a, True))     # label mismatch
    a = good(); a["per_action"][0]["time_window"]["incomplete"] = True; cases.append((a, True))  # incomplete 필수
    a = good(); a["per_action"][0]["time_window"]["intervals"] = []; cases.append((a, True))     # 빈 intervals
    for analysis, should_reject in cases:
        rejected = bool(_coverage_check(analysis))
        if rejected != should_reject:
            print("[verify] GATE SELFCHECK FAIL: should_reject=%s 인데 rejected=%s" % (should_reject, rejected))
            return False
    return True


def verify_one(stage_id: int, workers: int) -> bool:
    apath = SOLUTIONS_DIR / f"stage{stage_id:02d}.analysis.json"
    if not apath.exists():
        print("[verify] stage%02d: analysis.json 없음 — FAIL" % stage_id)
        return False
    analysis = json.loads(apath.read_text(encoding="utf-8"))
    minimal = analysis["minimal_plan"]
    required = int(analysis["required_saved"])
    roll = Rollouter(analysis["stage"], int(analysis["deadline_frames"]), required, workers)

    cov = _coverage_check(analysis)
    if cov:
        print("[verify] stage%02d: coverage FAIL" % stage_id)
        for c in cov:
            print("    - %s" % c)
        return False

    # 싼 재검증 체크 묶음 — (설명, plan, 기대 클리어). 1-minimal 자체 + 액션별 interval/gap 경계.
    checks: list[tuple] = [("1-minimal self-clear", minimal, True)]
    for p in analysis["per_action"]:
        idx = p["index"]
        st = p["sweep_target"]
        tw = p["time_window"]
        if st is None:
            continue
        for lo, hi in tw["intervals"]:
            mid = (lo + hi) // 2
            checks.append(("a%d interval[%d,%d] 내부=clear" % (idx, lo, hi),
                           sweep_time_plan(minimal, idx, st, mid), True))
            checks.append(("a%d %d(下) 밖=fail" % (idx, lo - 1),
                           sweep_time_plan(minimal, idx, st, lo - 1), False))
            checks.append(("a%d %d(上) 밖=fail" % (idx, hi + 1),
                           sweep_time_plan(minimal, idx, st, hi + 1), False))
        for glo, ghi in tw.get("gaps", []):
            gmid = (glo + ghi) // 2
            checks.append(("a%d gap[%d,%d] 내부=fail" % (idx, glo, ghi),
                           sweep_time_plan(minimal, idx, st, gmid), False))

    plans = [c[1] for c in checks]
    oks = roll.batch_clears(plans)
    ok_all = True
    for (desc, _plan, expect_clear), got in zip(checks, oks):
        if got != expect_clear:
            print("[verify] stage%02d FAIL: %s (got cleared=%s want %s)" % (stage_id, desc, got, expect_clear))
            ok_all = False
    if ok_all:
        print("[verify] stage%02d PASS (%d 체크, %d 롤аут)" % (stage_id, len(checks), roll.count))
    return ok_all


def verify(stage_ids: list[int], workers: int) -> int:
    print("[verify] analyze.py 게이트 재검증: %s" % ["stage%02d" % s for s in stage_ids])
    if not _selfcheck_gate():
        return 1
    if not stage_ids:        # fail-closed — 검증 대상 0개는 통과가 아니라 실패(빈 통과 위장 차단).
        print("[verify] FAIL - 검증할 analysis 대상 없음(solve.json glob 0)")
        return 1
    all_ok = True
    for sid in stage_ids:
        if not verify_one(sid, workers):
            all_ok = False
    if all_ok:
        print("[verify] PASS - all %d analysis 게이트 그린" % len(stage_ids))
        return 0
    print("[verify] FAIL")
    return 1


# ============================================================ (F) 직관 대조 (정보, 게이트 아님)

def intuition_compare(label_order: list[int]) -> None:
    """사용자 pre-register 난이도 순위(쉬움→어려움) vs 측정 stage_min_window(넓을수록 쉬움) Spearman 순위
    상관 + 불일치 쌍. 게이트 아님(사후 해석 방지). analysis.json들을 읽어 산출."""
    rows = []
    for sid in label_order:
        apath = SOLUTIONS_DIR / f"stage{sid:02d}.analysis.json"
        if not apath.exists():
            print("[compare] stage%02d analysis 없음 — 생략" % sid)
            continue
        a = json.loads(apath.read_text(encoding="utf-8"))
        w = a.get("stage_min_window_s")
        rows.append((sid, w))
    measured = [r for r in rows if r[1] is not None]
    if len(measured) < 2:
        print("[compare] 측정 윈도우 2개 미만 — 대조 생략")
        return
    # 사용자 라벨 순위: label_order 순서가 곧 쉬움(낮은 rank)→어려움. 측정: width 큰 게 쉬움.
    user_rank = {sid: i for i, sid in enumerate(label_order)}
    meas_sorted = sorted(measured, key=lambda r: -r[1])     # width 큰 순 = 쉬움 순
    meas_rank = {sid: i for i, (sid, _w) in enumerate(meas_sorted)}
    common = [sid for sid, _w in measured if sid in user_rank]
    n = len(common)
    d2 = sum((user_rank[s] - meas_rank[s]) ** 2 for s in common)
    rho = 1 - (6 * d2) / (n * (n * n - 1)) if n > 1 else float("nan")
    print("[compare] 직관 대조(정보, 게이트 아님): n=%d Spearman ρ=%.3f" % (n, rho))
    print("    측정 윈도우(넓을수록 쉬움): %s" % [(s, round(w, 4)) for s, w in meas_sorted])
    mism = [(s, user_rank[s], meas_rank[s]) for s in common if user_rank[s] != meas_rank[s]]
    if mism:
        print("    불일치 쌍(sid, user_rank, measured_rank): %s" % mism)


# ============================================================ main

def _expected_stage_ids() -> list[int]:
    ids = []
    for p in sorted(SOLUTIONS_DIR.glob("stage*.solve.json")):
        m = re.match(r"stage(\d+)\.solve\.json$", p.name)
        if m:
            ids.append(int(m.group(1)))
    return ids


def main() -> int:
    ap = argparse.ArgumentParser(description="auto-solver Phase 3a 최소화+윈도우 측정")
    ap.add_argument("stage_id", type=int, nargs="?", help="측정/검증할 stage id (없으면 --all/--verify 필요)")
    ap.add_argument("--all", action="store_true", help="모든 발견 해(solve.json) 측정")
    ap.add_argument("--verify", action="store_true", help="저장된 analysis.json 게이트 재검증")
    ap.add_argument("--prove-cardinality", action="store_true", help="부분집합 브루트포스로 cardinality-minimal 증명(opt-in)")
    ap.add_argument("--allow-incomplete", action="store_true", help="(탐색용) incomplete 측정도 verify 통과 허용")
    ap.add_argument("--workers", type=int, default=4, help="병렬 롤아웃 수(기본 4)")
    ap.add_argument("--cap", type=int, default=TIME_CAP, help="시간 윈도우 액션당 롤아웃 상한")
    ap.add_argument("--pos-cap", type=int, default=POS_CAP, help="위치 윈도우 액션당 롤아웃 상한")
    ap.add_argument("--labels", type=str, default="", help='난이도 순위 pre-register "11,13,12,14"(쉬움→어려움)')
    args = ap.parse_args()

    if args.verify:
        ids = [args.stage_id] if args.stage_id is not None else _expected_stage_ids()
        rc = verify(ids, args.workers)
        if args.labels:
            intuition_compare([int(x) for x in args.labels.split(",") if x.strip()])
        return rc

    if args.all:
        ids = _expected_stage_ids()
    elif args.stage_id is not None:
        ids = [args.stage_id]
    else:
        print(__doc__)
        return 64

    rc = 0
    for sid in ids:
        if analyze_stage(sid, args) != 0:
            rc = 1
    if args.labels:
        intuition_compare([int(x) for x in args.labels.split(",") if x.strip()])
    return rc


if __name__ == "__main__":
    raise SystemExit(main())
