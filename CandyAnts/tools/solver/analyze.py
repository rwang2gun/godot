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
import hashlib
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
GAP_PROBE_BUDGET = 8   # interval gap 스캔 내부 샘플 예산 → stride = 폭/(budget+1) (명시 기록·verify 강제)
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
        return [is_full_clear(r, self.required) for r in self.batch_results(plans)]

    def batch_results(self, plans: list[list[dict]]) -> list[dict]:
        """원시 결과 dict 리스트(병렬). verify는 error/verdict-부재를 클리어 여부와 분리해 tri-state 평가."""
        if not plans:
            return []
        with ThreadPoolExecutor(max_workers=self.workers) as ex:
            return list(ex.map(self.exec_one, plans))


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


def _stride_points(lo: int, hi: int, stride: int) -> list[int]:
    """[lo,hi] 내부를 stride 간격으로 샘플(양 끝 제외). 측정·verify가 동일 stride로 같은 점을 재생성 →
    sampled-clear 주장의 결정론적 재검증(gap 검출 해상도 = stride, 명시 기록)."""
    if stride < 1 or hi - lo <= 1:
        return []
    pts: list[int] = []
    f = lo + stride
    while f < hi:
        pts.append(f)
        f += stride
    return pts


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

    # 내부 비연속(gap) 검출 — [lo,hi]를 **균일 stride**로 스캔(병렬). stride = 폭/(budget+1)을 명시 기록해
    # "stride 이하 간격에서 gap 미검출"을 정직 보고(sub-stride island은 배제 못 함 = gap_check_stride가 그
    # 해상도 한계의 coverage proof; R1-H2 과대주장 차단). verify가 같은 stride로 재스캔해 sampled-clear 강제.
    stride = max(1, (hi - lo) // (GAP_PROBE_BUDGET + 1))
    test_batch(_stride_points(lo, hi, stride))
    intervals, gaps = _reconstruct_runs(test, lo, hi, cache)

    widths = [b - a + 1 for a, b in intervals]
    width_frames = max(widths) if widths else 0
    return {
        "lo": lo, "hi": hi,
        "width_frames": width_frames,
        "width_s": round(width_frames / PHYS_FPS, 4),
        "intervals": intervals, "gaps": gaps,
        "gap_check_stride": stride,
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
    # incomplete = 시간 윈도우 OR (측정한) 위치 윈도우 미완(R1-H1 — 보조 측정도 미완을 통과로 위장 금지).
    any_incomplete = any(
        p["time_window"]["incomplete"] or (p.get("pos_window") is not None and p["pos_window"].get("incomplete"))
        for p in per_action)

    analysis = {
        "solution_ref": str(solve_path.relative_to(ROOT)).replace("\\", "/"),
        # 측정 대상 solve.json의 해시 — verify가 재계산해 stale/변경된 해 위에 선 analysis를 거부(R2-H1 바인딩).
        "solution_sha256": hashlib.sha256(solve_path.read_bytes()).hexdigest(),
        "stage": stage,
        "deadline_frames": deadline,
        "required_saved": required,
        "physics_fps": PHYS_FPS,
        "cell_size": cs,        # 위치 윈도우 width_cells 재계산 검증용(verify가 권위로 사용).
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
            "time_cap": args.cap, "pos_cap": args.pos_cap, "gap_probe_budget": GAP_PROBE_BUDGET,
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
        else:
            # gap_check_stride 정합(R2-H2) — lo/hi에서 결정론적으로 재계산한 값과 **정확히 일치**해야 한다.
            # 누락(get-fallback 신뢰)·과대값(점 0개로 dense 재스캔 무력화)·변조를 fail-closed로 차단.
            lo, hi, s = tw.get("lo"), tw.get("hi"), tw.get("gap_check_stride")
            if not isinstance(lo, int) or not isinstance(hi, int):
                fails.append("필수 액션 %s time_window lo/hi 정수 아님" % p.get("label"))
            elif isinstance(s, bool) or not isinstance(s, int) or s < 1:
                fails.append("필수 액션 %s gap_check_stride 양의 정수 아님 (%r)" % (p.get("label"), s))
            elif s != max(1, (hi - lo) // (GAP_PROBE_BUDGET + 1)):
                fails.append("필수 액션 %s gap_check_stride %d != 기대 %d (누락/과대/변조)" % (
                    p.get("label"), s, max(1, (hi - lo) // (GAP_PROBE_BUDGET + 1))))
        pw = p.get("pos_window")
        if pw is not None:
            if pw.get("incomplete"):                     # R1-H1 — 측정한 위치 윈도우 미완도 fail-closed
                fails.append("필수 액션 %s pos_window incomplete=true (보조 측정도 미완 위장 금지)" % p.get("label"))
            else:
                # pos_window 스키마/파생 정합(R7-H1) — 완료 pos는 lo_x/hi_x/width/intervals 내부 일관 +
                # width_cells 재계산. 임의 위조 pos가 무검증 통과(silent-pass)하던 보조 차원 차단.
                lx, hx, wx = pw.get("lo_x"), pw.get("hi_x"), pw.get("width_x")
                if not all(isinstance(v, int) and not isinstance(v, bool) for v in (lx, hx, wx)):
                    fails.append("필수 액션 %s pos_window lo_x/hi_x/width_x 정수 아님" % p.get("label"))
                else:
                    if lx > hx:
                        fails.append("필수 액션 %s pos_window lo_x>hi_x" % p.get("label"))
                    if wx != hx - lx:
                        fails.append("필수 액션 %s pos_window width_x %d != hi-lo %d" % (p.get("label"), wx, hx - lx))
                    if pw.get("intervals") != [[lx, hx]]:
                        fails.append("필수 액션 %s pos_window intervals != [[lo_x,hi_x]]" % p.get("label"))
                    if pw.get("gaps") not in ([], None):
                        fails.append("필수 액션 %s pos_window gaps 비어있지 않음(보조는 gap 미검출)" % p.get("label"))
                    cs = analysis.get("cell_size")
                    if not isinstance(cs, int) or cs <= 0:
                        fails.append("cell_size 없음/부정 — pos width_cells 검증 불가")
                    elif abs(float(pw.get("width_cells", -1)) - round(wx / cs, 3)) > 1e-9:
                        fails.append("필수 액션 %s pos_window width_cells %s != 재계산 %.3f" % (
                            p.get("label"), pw.get("width_cells"), round(wx / cs, 3)))
                    # domain + 포화 플래그 정합(R8-H1) — saturated_lo/hi는 lo_x/hi_x가 도달 도메인 끝일 때만
                    # 정당(밖=fail 검사 스킵의 근거). 위조 포화로 경계 검사 우회 차단.
                    dom = pw.get("domain")
                    if not (isinstance(dom, list) and len(dom) == 2
                            and all(isinstance(v, int) and not isinstance(v, bool) for v in dom)):
                        fails.append("필수 액션 %s pos_window domain 스키마 부정" % p.get("label"))
                    else:
                        if not (dom[0] <= lx <= hx <= dom[1]):
                            fails.append("필수 액션 %s pos_window lo_x/hi_x가 domain 밖" % p.get("label"))
                        if pw.get("saturated_lo") and lx != dom[0]:
                            fails.append("필수 액션 %s saturated_lo인데 lo_x != domain[0]" % p.get("label"))
                        if pw.get("saturated_hi") and hx != dom[1]:
                            fails.append("필수 액션 %s saturated_hi인데 hi_x != domain[1]" % p.get("label"))
    missing = set(range(len(minimal))) - seen
    if missing:
        fails.append("per_action 누락 index %s" % sorted(missing))
    # minimal_kind 가드 — 1-minimal(기본) 또는 cardinality-minimal(증명 메타 동반)만 허용(R5-H1).
    mk = analysis.get("minimal_kind")
    if mk == "cardinality-minimal":
        cm = analysis.get("cardinality_meta")
        if not isinstance(cm, dict) or cm.get("cardinality") != len(minimal):
            fails.append("minimal_kind=cardinality-minimal인데 증명 메타 부재/불일치(cardinality!=%d)" % len(minimal))
    elif mk != "1-minimal":
        fails.append("minimal_kind 미상 (%r)" % mk)
    return fails


def _verdict_check(res: dict, expect_clear: bool, required: int) -> str:
    """verify 리플레이 결과 1건 tri-state 평가(순수). 통과면 "", 아니면 사유. **error/verdict-부재 = infra
    실패 → 항상 거부**(음성 단언도 fail-closed, R6-H1): 서브프로세스 실패·no-result를 진짜 게임 non-clear와
    구분. 음성 단언은 진짜 게임 verdict(cleared=false)만 인정."""
    if not isinstance(res, dict) or "error" in res:
        return "replay error: %s" % (res.get("error") if isinstance(res, dict) else res)
    if "cleared" not in res:
        return "게임 verdict 부재(infra 실패 의심)"
    got = is_full_clear(res, required)
    if got != expect_clear:
        return "got cleared=%s saved=%s want clear=%s" % (res.get("cleared"), res.get("saved"), expect_clear)
    return ""


def _solution_binding_fails(analysis: dict, expected_ref: str, solve_present: bool, solve: dict | None,
                            current_sha: str | None) -> list[str]:
    """analysis ↔ 측정 대상 solve.json 바인딩 검증(순수; verify_one이 I/O로 인자 채움). fail-open 차단:
    ① `solution_ref`가 이 stage_id의 **정규 경로**(`expected_ref`)와 일치 — 분석 파일명↔참조 해 불일치(다른
       stage 분석을 stageNN.analysis.json으로 위장) 차단(R4-H1). solve는 정규 경로에서 로드(인자로 받음).
    ② solve.json 존재 + 해시(R2-H1) — stale/변경/삭제 거부.
    ③ replay 파라미터(stage/deadline/required) + minimal_plan 파생(부분집합) 정합. 어떤 불일치든 메시지."""
    fails: list[str] = []
    ref = analysis.get("solution_ref")
    if ref != expected_ref:
        fails.append("solution_ref %r != 기대 %r (분석 파일명-해 불일치)" % (ref, expected_ref))
    if not solve_present or solve is None:
        fails.append("solve.json 없음(stale/삭제): %s" % expected_ref)
        return fails
    if analysis.get("solution_sha256") != current_sha:
        fails.append("solution_sha256 불일치 — solve.json 변경됨, 재측정 필요 (%s != %s)" % (
            str(current_sha)[:12], str(analysis.get("solution_sha256"))[:12]))
    if analysis.get("stage") != solve.get("stage"):
        fails.append("stage 불일치 (%s != %s)" % (analysis.get("stage"), solve.get("stage")))
    if int(analysis.get("deadline_frames", -1)) != int(solve.get("deadline_frames", -2)):
        fails.append("deadline_frames 불일치")
    req = int(solve.get("result", {}).get("hp", solve.get("expect", {}).get("saved", -2)))
    if int(analysis.get("required_saved", -1)) != req:
        fails.append("required_saved 불일치 (%s != %s)" % (analysis.get("required_saved"), req))
    solve_actions = solve.get("actions", [])
    for a in analysis.get("minimal_plan", []):
        if a not in solve_actions:
            fails.append("minimal_plan 액션이 solve.json actions에 없음(파생 불일치): %s" % a.get("skill"))
            break
    return fails


def _derived_consistency_fails(analysis: dict, caps: dict) -> list[str]:
    """파생 필드 재계산 정합(verify가 저장값을 신뢰하지 않고 검증된 intervals + 권위 caps에서 다시 계산해
    대조). width_frames/width_s/tier/provisional_flags(액션) + stage_min_window_s + any_incomplete. 난이도
    주장(width/tier/stage_min) 변조를 fail-closed로 차단. caps는 verify_one이 capabilities.tres에서 권위
    로드해 주입(저장 caps 변조도 무력). 순수 함수."""
    fails: list[str] = []
    EPS = 1e-9
    complete_ws: list[float] = []
    for p in analysis.get("per_action", []):
        lbl = p.get("label")
        tw = p.get("time_window", {})
        if tw.get("incomplete") or not tw.get("intervals"):
            continue
        exp_wf = max(b - a + 1 for a, b in tw["intervals"])
        if tw.get("width_frames") != exp_wf:
            fails.append("%s width_frames %s != 재계산 %d" % (lbl, tw.get("width_frames"), exp_wf))
        exp_ws = round(exp_wf / PHYS_FPS, 4)
        if abs(float(tw.get("width_s", -1)) - exp_ws) > EPS:
            fails.append("%s width_s %s != 재계산 %.4f" % (lbl, tw.get("width_s"), exp_ws))
        exp_tier, exp_flags = classify_tier(exp_ws, caps)
        if p.get("tier") != exp_tier:
            fails.append("%s tier %s != 재계산 %s" % (lbl, p.get("tier"), exp_tier))
        if sorted(p.get("provisional_flags", []) or []) != sorted(exp_flags):
            fails.append("%s provisional_flags %s != 재계산 %s" % (lbl, p.get("provisional_flags"), exp_flags))
        complete_ws.append(exp_ws)
    exp_min = min(complete_ws) if complete_ws else None
    got_min = analysis.get("stage_min_window_s")
    if exp_min is None:
        if got_min is not None:
            fails.append("stage_min_window_s %s != 재계산 None" % got_min)
    elif got_min is None or abs(float(got_min) - exp_min) > EPS:
        fails.append("stage_min_window_s %s != 재계산 %.4f" % (got_min, exp_min))
    exp_any = any(p["time_window"].get("incomplete") or
                  (p.get("pos_window") is not None and p["pos_window"].get("incomplete"))
                  for p in analysis.get("per_action", []))
    if bool(analysis.get("any_incomplete")) != bool(exp_any):
        fails.append("any_incomplete %s != 재계산 %s" % (analysis.get("any_incomplete"), exp_any))
    return fails


def _selfcheck_gate() -> bool:
    """게이트 검출기(`_coverage_check` + `_solution_binding_fails`)의 음성/양성 자가검증 — fail-open 회귀
    방지(solve.py `_selfcheck_schema` 선례). 검출기가 약해지면 verify 자체가 먼저 FAIL한다.
    `good()`의 time_window stride=1 = (20-10)//9 / (40-30)//9 기대값과 일치."""
    def good() -> dict:
        return {
            "minimal_kind": "1-minimal",
            "minimal_plan": [{"skill": "blocker"}, {"skill": "climber"}],
            "per_action": [
                {"index": 0, "label": "blocker#0", "sweep_target": {},
                 "time_window": {"incomplete": False, "intervals": [[10, 20]], "lo": 10, "hi": 20, "gap_check_stride": 1}},
                {"index": 1, "label": "climber#1", "sweep_target": {},
                 "time_window": {"incomplete": False, "intervals": [[30, 40]], "lo": 30, "hi": 40, "gap_check_stride": 1}},
            ],
        }
    def good_pos() -> dict:
        a = good(); a["cell_size"] = 48
        a["per_action"][0]["pos_window"] = {"incomplete": False, "lo_x": 100, "hi_x": 196,
            "width_x": 96, "width_cells": round(96 / 48, 3), "intervals": [[100, 196]], "gaps": [],
            "domain": [50, 300], "saturated_lo": False, "saturated_hi": False}
        return a
    cov_cases: list[tuple] = [(good(), False)]   # (analysis, should_reject) — _coverage_check 대상
    cov_cases.append((good_pos(), False))                                            # 정합 pos → 통과
    a = good_pos(); a["per_action"][0]["pos_window"]["width_x"] = 999; cov_cases.append((a, True))   # pos width_x 변조
    a = good_pos(); a["per_action"][0]["pos_window"]["width_cells"] = 9.9; cov_cases.append((a, True))  # pos width_cells 변조
    a = good_pos(); a["per_action"][0]["pos_window"]["intervals"] = [[0, 9]]; cov_cases.append((a, True))  # pos intervals 변조
    a = good_pos(); a["per_action"][0]["pos_window"]["lo_x"] = 300; cov_cases.append((a, True))      # lo_x>hi_x
    a = good_pos(); del a["per_action"][0]["pos_window"]["domain"]; cov_cases.append((a, True))      # domain 누락(R8)
    a = good_pos(); a["per_action"][0]["pos_window"]["domain"] = [150, 300]; cov_cases.append((a, True))  # lo_x<domain[0]
    a = good_pos(); a["per_action"][0]["pos_window"]["saturated_lo"] = True; cov_cases.append((a, True))  # 위조 포화(lo_x!=dom[0])
    a = good_pos(); pw = a["per_action"][0]["pos_window"]; pw["saturated_lo"] = True; pw["lo_x"] = 50; pw["width_x"] = 146; pw["width_cells"] = round(146 / 48, 3); pw["intervals"] = [[50, 196]]; cov_cases.append((a, False))  # 정당 포화(lo_x==dom[0])
    a = good(); a["per_action"].pop(); cov_cases.append((a, True))                       # count mismatch / 누락
    a = good(); a["per_action"][1]["index"] = 0; cov_cases.append((a, True))             # duplicate index
    a = good(); a["per_action"][1]["index"] = 9; cov_cases.append((a, True))             # out of range
    a = good(); a["per_action"][0]["label"] = "wrong#0"; cov_cases.append((a, True))     # label mismatch
    a = good(); a["per_action"][0]["time_window"]["incomplete"] = True; cov_cases.append((a, True))  # incomplete 필수
    a = good(); a["per_action"][0]["time_window"]["intervals"] = []; cov_cases.append((a, True))     # 빈 intervals
    a = good(); del a["per_action"][0]["time_window"]["gap_check_stride"]; cov_cases.append((a, True))  # stride 누락(R2-H2)
    a = good(); a["per_action"][0]["time_window"]["gap_check_stride"] = 999; cov_cases.append((a, True))  # stride 과대(무력화)
    a = good(); a["per_action"][0]["time_window"]["gap_check_stride"] = 0; cov_cases.append((a, True))    # stride 비양수
    a = good(); a["per_action"][0]["pos_window"] = {"incomplete": True}; cov_cases.append((a, True))  # pos 미완(R1-H1)
    a = good(); del a["minimal_kind"]; cov_cases.append((a, True))                        # minimal_kind 누락(R5-H1)
    a = good(); a["minimal_kind"] = "cardinality-minimal"; cov_cases.append((a, True))    # cardinality 증명 메타 부재
    a = good(); a["minimal_kind"] = "cardinality-minimal"; a["cardinality_meta"] = {"cardinality": 2}; cov_cases.append((a, False))  # 메타 일치 → 통과
    for analysis, should_reject in cov_cases:
        if bool(_coverage_check(analysis)) != should_reject:
            print("[verify] GATE SELFCHECK FAIL (coverage): should_reject=%s" % should_reject)
            return False

    # solution-binding 검출기 자가검증(R2-H1·R4-H1) — 순수 비교기에 in-memory 인자 주입.
    EXP = "data/solutions/stage11.solve.json"
    a = good(); a["solution_ref"] = EXP; a["solution_sha256"] = "deadbeef"
    a["stage"] = "res://S.tscn"; a["deadline_frames"] = 100; a["required_saved"] = 4
    a["minimal_plan"] = [{"skill": "blocker"}]
    solve = {"stage": "res://S.tscn", "deadline_frames": 100, "result": {"hp": 4},
             "actions": [{"skill": "blocker"}]}
    bind_cases = [
        (a, EXP, True, solve, "deadbeef", False),                 # 전부 일치 → 통과
        (a, EXP, False, None, "deadbeef", True),                  # solve 파일 없음 → 거부
        (a, EXP, True, solve, "OTHERHASH", True),                 # 해시 불일치 → 거부
        (a, EXP, True, {**solve, "stage": "res://Z.tscn"}, "deadbeef", True),   # stage 불일치 → 거부
        (a, EXP, True, {**solve, "result": {"hp": 5}}, "deadbeef", True),       # required 불일치 → 거부
        (a, EXP, True, {**solve, "actions": [{"skill": "climber"}]}, "deadbeef", True),  # 파생 불일치 → 거부
        (a, "data/solutions/stage12.solve.json", True, solve, "deadbeef", True),  # ref가 다른 stage → 거부(R4-H1)
    ]
    for analysis, exp, present, sv, sha, should_reject in bind_cases:
        if bool(_solution_binding_fails(analysis, exp, present, sv, sha)) != should_reject:
            print("[verify] GATE SELFCHECK FAIL (binding): should_reject=%s" % should_reject)
            return False

    # derived-consistency 검출기 자가검증 — 검증된 intervals에서 재계산한 width/tier/stage_min/any_incomplete
    # 대조. caps = 기본 티어값(comfortable=0.30 등). width_s=11/60=0.1833 → hard. stage_min=0.1833.
    dcaps = {"comfortable_s": 0.30, "hard_s": 0.15, "machine_only_s": 0.10}
    def dgood() -> dict:
        return {
            "per_action": [{"index": 0, "label": "b#0", "time_window": {
                "incomplete": False, "intervals": [[10, 20]], "width_frames": 11, "width_s": 0.1833},
                "tier": "hard", "provisional_flags": []}],
            "stage_min_window_s": 0.1833, "any_incomplete": False,
        }
    d_cases = [
        (dgood(), False),                                                          # 일치 → 통과
    ]
    d = dgood(); d["per_action"][0]["time_window"]["width_frames"] = 99; d_cases.append((d, True))   # width_frames 변조
    d = dgood(); d["per_action"][0]["time_window"]["width_s"] = 9.9; d_cases.append((d, True))       # width_s 변조
    d = dgood(); d["per_action"][0]["tier"] = "comfortable"; d_cases.append((d, True))               # tier 변조
    d = dgood(); d["stage_min_window_s"] = 9.9; d_cases.append((d, True))                            # stage_min 변조
    d = dgood(); d["any_incomplete"] = True; d_cases.append((d, True))                               # any_incomplete 변조
    for analysis, should_reject in d_cases:
        if bool(_derived_consistency_fails(analysis, dcaps)) != should_reject:
            print("[verify] GATE SELFCHECK FAIL (derived): should_reject=%s" % should_reject)
            return False

    # verdict tri-state 검출기 자가검증(R6-H1) — error/verdict-부재는 음성 단언에서도 거부(fail-closed).
    v_cases = [
        ({"cleared": True, "saved": 4}, True, 4, False),    # 진짜 클리어 + expect clear → 통과
        ({"cleared": False, "saved": 0}, False, 4, False),  # 진짜 non-clear + expect 非 → 통과
        ({"error": "no SOLVER_RESULT"}, False, 4, True),    # infra 실패 + expect 非 → 거부(R6-H1 핵심)
        ({"error": "boom"}, True, 4, True),                 # infra 실패 + expect clear → 거부
        ({"saved": 0}, False, 4, True),                     # verdict 부재(cleared 없음) → 거부
        ({"cleared": True, "saved": 4}, False, 4, True),    # 진짜 클리어인데 expect 非 → 거부
        ({"cleared": False, "saved": 0}, True, 4, True),    # 진짜 non-clear인데 expect clear → 거부
    ]
    for res, expect_clear, req, should_reject in v_cases:
        if bool(_verdict_check(res, expect_clear, req)) != should_reject:
            print("[verify] GATE SELFCHECK FAIL (verdict): res=%s should_reject=%s" % (res, should_reject))
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

    # solution.json 바인딩 — solve를 이 stage_id의 **정규 경로**에서 로드(분석이 임의 지정한 ref가 아니라)해
    # 해시·파라미터·파생 정합 + analysis.solution_ref가 그 정규 경로와 일치하는지(R4-H1) 확인. stale/변경/삭제/
    # 파일명-해 불일치 차단.
    expected_ref = "data/solutions/stage%02d.solve.json" % stage_id
    sp = ROOT / expected_ref
    present = sp.exists()
    solve = json.loads(sp.read_text(encoding="utf-8")) if present else None
    cur_sha = hashlib.sha256(sp.read_bytes()).hexdigest() if present else None
    bind = _solution_binding_fails(analysis, expected_ref, present, solve, cur_sha)
    if bind:
        print("[verify] stage%02d: solution-binding FAIL" % stage_id)
        for b in bind:
            print("    - %s" % b)
        return False

    # 파생 필드 정합 — width/tier/stage_min/any_incomplete를 검증된 intervals + **권위 caps**(capabilities.tres
    # 재로드)에서 다시 계산해 대조. 저장 caps(analysis.capabilities)도 권위와 일치해야(난이도 기준 변조 차단).
    caps_auth = load_caps()
    a_caps = analysis.get("capabilities", {})
    for k in ("comfortable_s", "hard_s", "machine_only_s"):
        if float(a_caps.get(k, -1)) != float(caps_auth[k]):
            print("[verify] stage%02d: capabilities FAIL — %s %s != tres %s" % (
                stage_id, k, a_caps.get(k), caps_auth[k]))
            return False
    deriv = _derived_consistency_fails(analysis, caps_auth)
    if deriv:
        print("[verify] stage%02d: derived-field FAIL" % stage_id)
        for d in deriv:
            print("    - %s" % d)
        return False

    # 재검증 체크 묶음 — (설명, plan, 기대 클리어). 1-minimal 자체 + 액션별 interval/gap 경계 + interval
    # 내부를 **gap_check_stride로 dense 재스캔**(측정 해상도에서 sampled-clear 강제 = 숨은 gap·analysis 변조
    # 차단, R1-H2). stride가 클(넓은 interval)수록 적은 점이지만 측정과 동일 해상도라 정직.
    checks: list[tuple] = [("1-minimal self-clear", minimal, True)]
    # 1-minimality 강제(R5-H1) — 각 액션 제거 시 **깨져야**(non-clear). 단순 clear만으론 잉여 액션을 품은
    # 비최소 플랜이 통과해 최소-스킬 proxy·난이도를 오염시킨다(잉여가 더 빡빡한 윈도우면 특히). deletion 트라이얼.
    for j in range(len(minimal)):
        trial = [minimal[k] for k in range(len(minimal)) if k != j]
        checks.append(("1-minimal: a%d(%s) 제거 → 깨져야" % (j, str(minimal[j].get("skill", "?"))), trial, False))
    for p in analysis["per_action"]:
        idx = p["index"]
        st = p["sweep_target"]
        tw = p["time_window"]
        if st is None:
            continue
        stride = int(tw["gap_check_stride"])    # _coverage_check가 존재·정합 강제 후 — fallback 불요(R2-H2)
        for lo, hi in tw["intervals"]:
            # **경계(lo,hi) 자체를 clear 리플레이**(R8-H1) + 내부 mid/stride + 양 끝 밖 fail. 경계를 안 찍으면
            # 한쪽을 fail 프레임으로 넓혀도(폭 일관 유지) 내부 샘플만 clear면 통과하는 silent-pass가 생긴다.
            interior = [lo, hi, (lo + hi) // 2] + _stride_points(lo, hi, stride)
            for f in sorted(set(interior)):
                checks.append(("a%d interval[%d,%d] %d=clear" % (idx, lo, hi, f),
                               sweep_time_plan(minimal, idx, st, f), True))
            checks.append(("a%d %d(下) 밖=fail" % (idx, lo - 1),
                           sweep_time_plan(minimal, idx, st, lo - 1), False))
            checks.append(("a%d %d(上) 밖=fail" % (idx, hi + 1),
                           sweep_time_plan(minimal, idx, st, hi + 1), False))
        for glo, ghi in tw.get("gaps", []):
            gmid = (glo + ghi) // 2
            checks.append(("a%d gap[%d,%d] 내부=fail" % (idx, glo, ghi),
                           sweep_time_plan(minimal, idx, st, gmid), False))
        # 위치 윈도우 리플레이(R7-H1) — 보조 차원도 권위 재검증. 내부=clear + 비-포화 경계=fail
        # (포화 경계 = 도달 범위 끝까지 클리어 = 정당, "밖"이 도달 밖이라 ill-defined → 스킵).
        pw = p.get("pos_window")
        if pw is not None and not pw.get("incomplete"):
            lx, hx = int(pw["lo_x"]), int(pw["hi_x"])
            # 경계(lo_x,hi_x)도 clear 리플레이(R8-H1) + 내부 mid. 비-포화 경계만 밖=fail.
            for x in sorted({lx, hx, (lx + hx) // 2}):
                checks.append(("a%d pos[%d,%d] %d=clear" % (idx, lx, hx, x),
                               sweep_pos_plan(minimal, idx, x), True))
            if not pw.get("saturated_lo"):
                checks.append(("a%d pos %d(下) 밖=fail" % (idx, lx - 1),
                               sweep_pos_plan(minimal, idx, lx - 1), False))
            if not pw.get("saturated_hi"):
                checks.append(("a%d pos %d(上) 밖=fail" % (idx, hx + 1),
                               sweep_pos_plan(minimal, idx, hx + 1), False))

    plans = [c[1] for c in checks]
    results = roll.batch_results(plans)      # tri-state — error/verdict-부재를 분리(R6-H1)
    ok_all = True
    for (desc, _plan, expect_clear), res in zip(checks, results):
        why = _verdict_check(res, expect_clear, required)
        if why:
            print("[verify] stage%02d FAIL: %s (%s)" % (stage_id, desc, why))
            ok_all = False
    if ok_all:
        print("[verify] stage%02d PASS (%d 체크, %d 롤아웃)" % (stage_id, len(checks), roll.count))
    return ok_all


def verify(stage_ids: list[int], workers: int) -> int:
    print("[verify] analyze.py 게이트 재검증: %s" % ["stage%02d" % s for s in stage_ids])
    if not _selfcheck_gate():
        return 1
    if not stage_ids:        # fail-closed — 검증 대상 0개는 통과가 아니라 실패(빈 통과 위장 차단).
        print("[verify] FAIL - 검증할 대상 없음(analysis ∪ solve glob 0)")
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


def _analysis_stage_ids() -> list[int]:
    ids = []
    for p in sorted(SOLUTIONS_DIR.glob("stage*.analysis.json")):
        m = re.match(r"stage(\d+)\.analysis\.json$", p.name)
        if m:
            ids.append(int(m.group(1)))
    return ids


def _verify_target_ids() -> list[int]:
    """기본 verify 대상 = analysis ∪ solve id의 **합집합**(R3-H1). solve만 있고 analysis 없으면 verify_one이
    analysis 부재로 FAIL; analysis만 있고 solve 없으면(orphan) _solution_binding_fails가 solve 부재로 FAIL.
    solve glob에만 의존하면 solve 삭제·rename 시 orphan analysis가 ids에서 빠져 stale 가드를 우회한다."""
    return sorted(set(_expected_stage_ids()) | set(_analysis_stage_ids()))


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
        ids = [args.stage_id] if args.stage_id is not None else _verify_target_ids()
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
