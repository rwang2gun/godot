#!/usr/bin/env python3
"""
auto-solver Phase 5b — 가능성-공간 다양-해 발견 + 풀이법 보고서 (revised 계약, 2026-06-24 사용자).

솔버 산출물의 단위 질문 = "해가 몇 개"가 아니라 **"어디에 놓으면 클리어되나(가능성 공간)"**. 좌표 ±1타일
시프트를 별개 해로 오보하던 naive distinctness를 **검증된 연속 구역(range) + 4요소 solution-class 동치**로
교체한다(plan §"5b 계약"). 의도 판단·조절 제안 없음 — 중립 발견·보고만(designer-in-the-loop).

핵심:
  - **표현 = 검증된 연속 구역(range)**: 스킬 배치를 좌표가 아니라 *연속 클리어 셀 구간*으로 보고. "연속"은
    선언된 `gap_check_stride`로 검증(gap_verified)된 구간일 때만 병합 근거(미검증 = provisional, 병합 금지).
  - **solution-class 동치(병합) = 4요소 모두 동일**: (i) 스킬 multiset (ii) 각 슬롯이 같은 검증 구역 내
    (iii) target role/state(select·state·mode) (iv) trigger/timing(trigger type·cmp·picked_ge 서수·subgoal).
    넷 다 같을 때만 한 해(구역 내부 시프트만 무시). 하나라도 다르면 분리.
  - **범위 발견 = 독립 축 스윕**: 각 cell_x 슬롯의 placement를 *나머지를 한 클리어 기준배치로 고정*한 채
    스윕, 엔진 검증(D4) → intervals/gaps/gap_verified. 슬롯 정체성 = 좌→우 정렬 순서. axis_independent
    (각 축 cross-section, 곱공간 joint 미주장).
  - **분리-해 탐색 = 4요소 시그니처 forbid**(placement 구역만 아님 — R3): 발견 class를 4요소로 forbid해
    재탐색. forbid가 (skill,role,timing) 일치 AND placement∈검증구역일 때만 막으므로, **같은 구역·다른
    role/timing class는 forbid에 안 걸려 그대로 발견**(2단계 (a) in-region 변형이 자동 포착).

게이트(5c): `diverse-verify` — 저장된 `stageNN.diverse.json`의 각 class를 결정론 리플레이로 fail-closed
검증(reference_plan clear + 각 cell_x 슬롯 interval **경계+내부**=clear / 양 끝 밖·gap=fail, analyze.py
--verify와 동형). gap_verified 구간만 경계 fail 단언(sampled는 보고만).

Usage:
    GODOT_BIN=... python tools/solver/try_solve.py diverse 12 [--save]
    GODOT_BIN=... python tools/solver/try_solve.py diverse-verify [12]
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
sys.path.insert(0, str(HERE))

import analyze  # noqa: E402  (Rollouter·is_full_clear·_verdict_check 재사용 — 엔진 롤아웃·tri-state)
import knowledge  # noqa: E402  (위기 어휘 — 보고서 맥락)
import model  # noqa: E402
import solve  # noqa: E402

SOLUTIONS_DIR = ROOT / "data" / "solutions"
# diverse.json 스키마 버전 — 의미 변경 시 bump. verify가 정확 일치를 강제해 stale schema 거부(analyze R11 선례).
DIVERSE_SCHEMA_VERSION = 1
# placement 스윕 셀 예산(슬롯당). 도메인(그리드 폭)이 이보다 넓으면 stride 샘플링 + provisional 표기.
SWEEP_CELL_CAP = 40


# ============================================================ 4요소 시그니처 (순수)

def _placement_cell(action: dict, cs: int):
    """액션의 공간 placement 셀(ant_reaches_x 트리거의 x → 셀). 공간 축이 없으면 None(picked_ge carry·
    immediate·at_frame 등 — placement가 좌표가 아니라 타이밍/서수로 결정되는 슬롯)."""
    trg = action.get("trigger", {})
    if trg.get("type") == "ant_reaches_x" and "x" in trg:
        return int(float(trg["x"]) // cs)
    return None


def _role_sig(action: dict) -> dict:
    """target role/state 시그니처(4요소 iii) — select·state·mode. 위치 좌표(y_min/y_max)는 *공간 선택
    수단*이라 시그니처에서 제외(placement는 별도 range 축). state 없으면 'any'."""
    t = action.get("target", {})
    return {"mode": t.get("mode"), "select": t.get("select"), "state": t.get("state") or "any"}


def _timing_sig(action: dict) -> dict:
    """trigger/timing 시그니처(4요소 iv) — trigger type·cmp·picked_ge 서수(n)·frame·subgoal. ant_reaches_x의
    x는 **placement(range 축)라 제외**(같은 방향·다른 위치는 같은 timing). 그 외 trigger 파라미터는 timing."""
    trg = action.get("trigger", {})
    sig: dict = {"trigger_type": trg.get("type")}
    if "cmp" in trg:
        sig["cmp"] = trg["cmp"]
    if "n" in trg:                      # picked_ge 서수
        sig["n"] = trg["n"]
    if "frame" in trg:                  # at_frame / at_frame_exact
        sig["frame"] = trg["frame"]
    if "subgoal" in action:
        sig["subgoal"] = action["subgoal"]
    return sig


def _skill_multiset(plan: list) -> dict:
    ms: dict = {}
    for a in plan:
        s = a.get("skill")
        ms[s] = ms.get(s, 0) + 1
    return ms


# ============================================================ 범위 발견 (placement range-sweep, D4)

def _make_sweep_plan(reference: list, ref_index: int, cell: int, cs: int) -> list:
    """reference 플랜에서 액션 ref_index의 trigger.x만 셀 중심((cell+0.5)*cs)으로 치환(나머지 불변). 측정·
    게이트가 동일 함수를 써 결정론 리플레이 byte-identical. model.propose의 x=(col+0.5)*cs와 동일 규약."""
    plan = [dict(a) for a in reference]
    act = dict(reference[ref_index])
    trg = dict(act.get("trigger", {}))
    trg["x"] = (cell + 0.5) * cs
    act["trigger"] = trg
    plan[ref_index] = act
    return plan


def _runs(sampled: list, clears: dict) -> tuple[list, list]:
    """샘플된 셀들의 clear/fail 맵에서 연속 run을 복원 → (intervals[clear], gaps[fail]). [최초 clear,
    최후 clear] 구간 내부의 인접 샘플로 run을 만든다(양 끝 fail은 구간 밖이라 제외). stride==1이면 인접 =
    연속 정수라 intervals/gaps가 권위, stride>1이면 그 해상도의 sampled 추정."""
    clear_cells = [c for c in sampled if clears.get(c)]
    if not clear_cells:
        return [], []
    lo_c, hi_c = clear_cells[0], clear_cells[-1]
    span = [c for c in sampled if lo_c <= c <= hi_c]
    intervals: list = []
    gaps: list = []
    cur_val = clears.get(span[0])
    start = prev = span[0]
    for c in span[1:]:
        v = clears.get(c)
        if v == cur_val:
            prev = c
            continue
        (intervals if cur_val else gaps).append([start, prev])
        cur_val = v
        start = prev = c
    (intervals if cur_val else gaps).append([start, prev])
    return intervals, gaps


def _sweep_placement(roll: "analyze.Rollouter", reference: list, ref_index: int, cs: int,
                     c_star: int, grid_cols: int, cap: int) -> dict:
    """슬롯(ref_index, ant_reaches_x)의 placement 셀을 *나머지 고정* 스윕 → 검증된 연속 구역. 도메인이
    cap 이하면 전 셀(stride 1, gap_verified) 스윕, 넘으면 stride 샘플(gap_verified=False·provisional)."""
    lo_dom, hi_dom = 0, max(grid_cols - 1, c_star + 1)
    n_cells = hi_dom - lo_dom + 1
    if n_cells <= cap:
        stride = 1
        sampled = list(range(lo_dom, hi_dom + 1))
    else:
        stride = math.ceil(n_cells / cap)
        sampled = sorted(set(range(lo_dom, hi_dom + 1, stride)) | {c_star})
    plans = [_make_sweep_plan(reference, ref_index, c, cs) for c in sampled]
    results = roll.batch_results(plans)
    clears = {c: analyze.is_full_clear(r, roll.required) for c, r in zip(sampled, results)}
    intervals, gaps = _runs(sampled, clears)
    gap_verified = (stride == 1)
    in_region = any(lo <= c_star <= hi for lo, hi in intervals)
    return {
        "intervals": intervals, "gaps": gaps, "range_sampled": True,
        "gap_check_stride": stride, "gap_verified": gap_verified,
        "gap_coverage": ("full@1" if stride == 1 else "sampled@%d" % stride),
        # joint 미검증(R2-HIGH 정직 경계): 보고 range는 *나머지 고정 시* 각 축 cross-section이며 모든 조합의
        # 곱공간 클리어를 주장하지 않는다(전수 joint = 조합 폭발).
        "axis_independent": True,
        # provisional(R2-HIGH): stride>1(미검증) 또는 c_star가 구역에 없으면 확정 병합 금지 표기.
        "provisional": (not gap_verified) or (not in_region),
        "domain": [lo_dom, hi_dom], "sampled_points": sampled, "rollouts": len(sampled),
    }


# ============================================================ solution-class 빌드 + forbid

def _build_class(roll: "analyze.Rollouter", plan: list, cs: int, grid_cols: int,
                 inventory: dict, axis: str, sweep_cap: int) -> dict:
    """클리어 플랜 → solution-class(슬롯 좌→우 정렬, cell_x 슬롯은 range-sweep). 4요소 = skill_multiset +
    슬롯별 (role,timing,검증구역)."""
    slots_raw = []
    for ref_index, a in enumerate(plan):
        slots_raw.append({
            "ref_index": ref_index, "skill": a.get("skill"),
            "role": _role_sig(a), "timing": _timing_sig(a), "cell": _placement_cell(a, cs),
        })
    # 슬롯 정체성 = 좌→우 정렬(공간 슬롯 먼저 셀 오름차순, 비공간 슬롯은 원본 순서 유지하며 뒤).
    slots_raw.sort(key=lambda s: (s["cell"] is None, s["cell"] if s["cell"] is not None else 0, s["ref_index"]))
    slots = []
    for slot_i, s in enumerate(slots_raw):
        slot = {"slot": slot_i, "ref_index": s["ref_index"], "skill": s["skill"],
                "role": s["role"], "timing": s["timing"]}
        if s["cell"] is None:
            slot.update({"placement_axis": "none", "fixed_cell": None, "intervals": [], "gaps": [],
                         "range_sampled": False, "gap_check_stride": None, "gap_verified": False,
                         "gap_coverage": "none", "axis_independent": True, "provisional": False})
        else:
            sw = _sweep_placement(roll, plan, s["ref_index"], cs, s["cell"], grid_cols, sweep_cap)
            slot.update({"placement_axis": "cell_x", "fixed_cell": s["cell"], **sw})
        slots.append(slot)
    return {"skill_multiset": _skill_multiset(plan), "axis": axis, "reference_plan": plan,
            "inventory": {k: v for k, v in inventory.items() if v > 0}, "slots": slots}


def _class_sig(cls: dict) -> tuple:
    """클래스 동치 시그니처(dedup) — skill_multiset + 슬롯별 (skill, role, timing, 구역키). 구역키 = cell_x는
    intervals 튜플, none은 ('none',). placement 좌표가 아니라 *검증 구역*으로 동치 판정 → 구역 내 시프트 무시."""
    parts = []
    for s in cls["slots"]:
        if s["placement_axis"] == "cell_x":
            region = tuple(tuple(iv) for iv in s.get("intervals", []))
        else:
            region = ("none",)
        parts.append((s["skill"], json.dumps(s["role"], sort_keys=True),
                      json.dumps(s["timing"], sort_keys=True), region))
    return (json.dumps(cls["skill_multiset"], sort_keys=True), tuple(parts))


def _make_forbid(classes: list, cs: int):
    """4요소 시그니처 forbid 술어(R3 MEDIUM — placement 구역만 아님). 액션이 어떤 발견 class의 슬롯과
    (skill, role, timing) 일치 AND placement∈그 슬롯 검증 구역(cell_x) / 비공간이면 일치만으로 → 금지.
    같은 구역·다른 role/timing는 안 걸려 발견됨(2단계 (a) in-region 변형 자동 포착). 비-병합 provisional
    구역도 forbid에 쓰지 않게 gap_verified 구역만 막는다(미검증 구역 재탐색 허용 = 정직)."""
    def forbidden(action: dict) -> bool:
        skill = action.get("skill")
        role = _role_sig(action)
        timing = _timing_sig(action)
        cell = _placement_cell(action, cs)
        for cls in classes:
            for s in cls["slots"]:
                if s["skill"] != skill or s["role"] != role or s["timing"] != timing:
                    continue
                if s["placement_axis"] != "cell_x":
                    return True                          # 비공간 슬롯: 4요소 일치 = 같은 class 슬롯
                if not s.get("gap_verified"):
                    continue                             # 미검증 구역은 forbid 안 함(병합 근거 아님)
                if cell is not None and any(lo <= cell <= hi for lo, hi in s.get("intervals", [])):
                    return True
        return False
    return forbidden


# ============================================================ 오케스트레이터: diverse 보고서

def _slot_summary(slot: dict) -> str:
    role = slot["role"]
    tim = slot["timing"]
    where = ""
    if slot["placement_axis"] == "cell_x":
        ivs = "·".join("[%d–%d]" % (lo, hi) for lo, hi in slot["intervals"]) or "[]"
        flag = "" if slot["gap_verified"] else "(sampled@%s)" % slot["gap_check_stride"]
        where = " col%s%s" % (ivs, flag)
    extra = ""
    if "n" in tim:
        extra = " picked_ge%s" % tim["n"]
    return "%s[%s/%s %s%s]%s" % (slot["skill"], role.get("select"), role.get("state"),
                                 tim.get("trigger_type"), tim.get("cmp", ""), where) + extra


def diverse_report(stage_id: int, max_rollouts: int, extra_cap: int, save: bool = False,
                   workers: int = 4) -> int:
    """한 스테이지의 **구별되는 solution-class**를 자동 발견해 가능성-공간(검증된 range) 보고서로 출력.

    탐색: ① 전략 축 — 전체 인벤토리로 발견 class를 4요소 forbid에 누적·재탐색(첫 해 이후 롤아웃만 extra_cap
    예산). ② 인벤토리 축 — 변형(수량/종류 감소). 각 class는 cell_x 슬롯 range-sweep으로 검증 구역 산출.
    좌표 ±시프트는 같은 구역 → 같은 class(naive 결함 해소)."""
    notes = knowledge.load_vault()
    meta = solve.stage_meta(stage_id)
    base_inv = meta["inventory"]
    hp = int(meta["candy_hp"])
    deadline = int(round(meta["time_limit_seconds"] * 60)) + 1500
    stage_scene = f"res://scenes/stages/Stage{stage_id:02d}.tscn"
    layout = model.parse_layout(ROOT / "data" / "stage_layouts" / f"stage{stage_id:02d}_layout.tres")
    cs = int(layout["cell_size"])
    grid_cols = max((c for c, _ in layout["occupied"]), default=24) + 1
    roll = analyze.Rollouter(stage_scene, deadline, hp, workers)

    print(f"=== diverse stage{stage_id:02d} (가능성-공간 다양-해) === 인벤토리={base_inv} hp={hp} "
          f"cs={cs} grid_cols={grid_cols} cap={max_rollouts}/탐색")
    base = solve.run_plan(stage_scene, [], deadline)
    diag = model.diagnose(base.get("trace", {}), layout, hp)
    retired = model.count_retired(base.get("trace", {}), layout)
    ct, tt = model.count_trapped(base.get("trace", {}))
    crises = knowledge.resolve(notes, diag, retired, {"carry": ct, "total": tt})
    print(f"  스테이지 위기(볼트): {[c['crisis'] for c in crises] or '없음'}")

    classes: list = []
    seen_sigs: set = set()
    extra_rollouts = 0
    capped = False

    def _record(plan: list, inv: dict, axis: str) -> bool:
        """클리어 플랜 → class 빌드·dedup. 새 class면 True. 빈 플랜([])=무도구 해도 유효 class."""
        cls = _build_class(roll, plan, cs, grid_cols, inv, axis, SWEEP_CELL_CAP)
        sig = _class_sig(cls)
        if sig in seen_sigs:
            return False
        seen_sigs.add(sig)
        cls["class"] = len(classes) + 1
        classes.append(cls)
        return True

    # ── 축 1: 전략(같은 전체 인벤토리, 4요소 forbid 재탐색).
    while True:
        if classes and extra_rollouts >= extra_cap:
            capped = True
            print(f"  [추가 탐색 캡 도달] {extra_rollouts}/{extra_cap}롤 — 전략 탐색 중단.")
            break
        s = {}      # solve.solve가 stats.update로 cleared/rollouts/final_plan을 채움
        pred = _make_forbid(classes, cs) if classes else None
        solve.solve(stage_id, max_rollouts, stats=s, save=False, inv_override=base_inv, forbid=pred)
        if classes:
            extra_rollouts += int(s.get("rollouts", 0))
        if not (s.get("cleared") and s.get("final_plan") is not None):
            break
        plan = s["final_plan"]
        is_new = _record(plan, base_inv, "strategy")
        if not plan:
            break                  # 무도구 해(빈 플랜)는 1회만 — 베이스라인은 항상 클리어(무한루프 방지)
        if not is_new:
            break                  # forbid가 못 막은 중복(안전망) — 무한루프 방지

    # ── 축 2: 인벤토리 변형(수량/종류 감소 → 다른 multiset = 다른 class).
    for variant in _inv_variants(base_inv)[1:]:
        if classes and extra_rollouts >= extra_cap:
            capped = True
            print(f"  [추가 탐색 캡 도달] {extra_rollouts}/{extra_cap}롤 — 인벤토리 변형 중단.")
            break
        s = {}      # solve.solve가 stats.update로 cleared/rollouts/final_plan을 채움
        solve.solve(stage_id, max_rollouts, stats=s, save=False, inv_override=variant)
        if classes:
            extra_rollouts += int(s.get("rollouts", 0))
        if s.get("cleared") and s.get("final_plan"):
            _record(s["final_plan"], variant, "inventory")

    # ── 보고서.
    print(f"\n=== 풀이법 보고서: stage{stage_id:02d} — 구별되는 solution-class {len(classes)}개 ===")
    for cls in classes:
        axis_label = {"strategy": "같은 인벤토리·다른 배치/전략", "inventory": "인벤토리 변형"}.get(cls["axis"], cls["axis"])
        print(f"\n  [class {cls['class']}] {cls['skill_multiset']} (인벤토리 {cls['inventory']}, 축={axis_label})")
        for slot in cls["slots"]:
            print(f"      슬롯{slot['slot']}: {_slot_summary(slot)}"
                  + ("" if not slot.get("provisional") else " ⚠provisional"))
    if capped:
        print(f"\n  ⚠ 추가 탐색이 캡({extra_cap}롤)에서 중단 — 미탐색 변형 잔존 가능(search_capped).")

    report = _build_report(stage_id, stage_scene, deadline, base_inv, hp, cs, grid_cols,
                           [c["crisis"] for c in crises], classes, capped, extra_rollouts)
    print(f"\nDIVERSE_REPORT {json.dumps(report, ensure_ascii=False)}")
    if save and classes:
        out = SOLUTIONS_DIR / f"stage{stage_id:02d}.diverse.json"
        out.parent.mkdir(exist_ok=True)
        out.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"  diverse 보고서 저장 → {out.relative_to(ROOT)}")
    return 0


def _inv_variants(base: dict) -> list[dict]:
    """인벤토리 변형(수량/종류 줄임). full + 각 도구 카운트 감소 + (다중이면) 종류 제거. 중복 제거."""
    variants = [dict(base)]
    for tool, cnt in base.items():
        for n in range(cnt - 1, 0, -1):
            v = dict(base); v[tool] = n; variants.append(v)
        if len(base) > 1:
            v = dict(base); v[tool] = 0; variants.append(v)
    seen, out = set(), []
    for v in variants:
        key = tuple(sorted((k, c) for k, c in v.items() if c > 0))
        if key not in seen:
            seen.add(key); out.append(v)
    return out


def _build_report(stage_id, stage_scene, deadline, base_inv, hp, cs, grid_cols,
                  crises, classes, capped, extra_rollouts) -> dict:
    """diverse.json 스키마(range 기반, 리플레이-ready)를 조립. 각 class = skill_multiset + reference_plan
    + 슬롯별 검증 구역(intervals/gap_verified) + expect. 게이트(diverse-verify)가 결정론 리플레이로 회귀 강제."""
    out_classes = []
    for cls in classes:
        out_classes.append({
            "class": cls["class"], "axis": cls["axis"], "skill_multiset": cls["skill_multiset"],
            "inventory": cls["inventory"], "reference_plan": cls["reference_plan"],
            "expect": {"cleared": True, "saved": hp},
            "slots": cls["slots"],
        })
    return {
        "schema_version": DIVERSE_SCHEMA_VERSION,
        "stage": stage_id, "stage_scene": stage_scene, "deadline_frames": deadline,
        "given_inventory": base_inv, "candy_hp": hp, "cell_size": cs, "grid_cols": grid_cols,
        "crises_present": crises, "n_solution_classes": len(out_classes),
        "search_capped": capped, "extra_rollouts_after_first": extra_rollouts,
        "solution_classes": out_classes,
        "note": ("가능성-공간 다양-해 보고서(중립 발견, designer-in-the-loop). class별 reference_plan은 결정론 "
                 "리플레이-ready, 슬롯 intervals는 검증된 연속 구역(gap_verified=true일 때 병합 권위). "
                 "axis_independent: 각 축 cross-section이며 joint 곱공간 미주장."),
    }


# ============================================================ (게이트) diverse-verify — 5c

def _coverage_check_diverse(report: dict) -> list[str]:
    """diverse.json 스키마 정합 선검증(fail-closed). 위반 메시지 목록(빈=통과). 권위 주장(gap_verified·
    skill_multiset)·필드 완전성·파생 일관성을 검증해 변조/stale을 거부(analyze coverage 선례)."""
    fails: list[str] = []
    if report.get("schema_version") != DIVERSE_SCHEMA_VERSION:
        fails.append("schema_version %r != %d (stale — 재생성 필요)" % (
            report.get("schema_version"), DIVERSE_SCHEMA_VERSION))
    cs = report.get("cell_size")
    if not isinstance(cs, int) or cs <= 0:
        fails.append("cell_size 양의 정수 아님 (%r)" % cs)
    classes = report.get("solution_classes")
    if not isinstance(classes, list) or not classes:
        fails.append("solution_classes 비어있음 (다양-해 0)")
        return fails
    for cls in classes:
        cl = cls.get("class")
        ref = cls.get("reference_plan")
        if not isinstance(ref, list) or not isinstance(cls.get("slots"), list):
            fails.append("class %r reference_plan/slots 형식 오류" % cl)
            continue
        # skill_multiset가 reference_plan과 일치(파생 변조 차단).
        exp_ms = _skill_multiset(ref)
        if cls.get("skill_multiset") != exp_ms:
            fails.append("class %r skill_multiset %s != reference 파생 %s" % (cl, cls.get("skill_multiset"), exp_ms))
        exp = cls.get("expect", {})
        if exp.get("cleared") is not True or not isinstance(exp.get("saved"), int) or isinstance(exp.get("saved"), bool) or exp.get("saved") < 1:
            fails.append("class %r expect 부적격(cleared:true + saved 정수≥1 필요): %r" % (cl, exp))
        if len(cls["slots"]) != len(ref):
            fails.append("class %r slots %d != reference_plan %d" % (cl, len(cls["slots"]), len(ref)))
        seen_slot: set = set()
        for slot in cls["slots"]:
            si = slot.get("slot")
            if si in seen_slot:
                fails.append("class %r duplicate slot %r" % (cl, si))
            seen_slot.add(si)
            ri = slot.get("ref_index")
            if not isinstance(ri, int) or ri < 0 or ri >= len(ref):
                fails.append("class %r slot %r ref_index 범위 밖 (%r)" % (cl, si, ri))
                continue
            # 슬롯 skill/role/timing이 reference_plan[ref_index]에서 파생된 값과 일치(변조 차단).
            a = ref[ri]
            if slot.get("skill") != a.get("skill"):
                fails.append("class %r slot %r skill %r != reference %r" % (cl, si, slot.get("skill"), a.get("skill")))
            if slot.get("role") != _role_sig(a) or slot.get("timing") != _timing_sig(a):
                fails.append("class %r slot %r role/timing != reference 파생" % (cl, si))
            ax = slot.get("placement_axis")
            if ax == "cell_x":
                st = slot.get("gap_check_stride")
                gv, gc = slot.get("gap_verified"), slot.get("gap_coverage")
                ivs = slot.get("intervals")
                if isinstance(st, bool) or not isinstance(st, int) or st < 1:
                    fails.append("class %r slot %r gap_check_stride 양의 정수 아님 (%r)" % (cl, si, st))
                elif gv != (st == 1):
                    fails.append("class %r slot %r gap_verified %r != (stride==1) (sampled→full 위장)" % (cl, si, gv))
                elif gc != ("full@1" if st == 1 else "sampled@%d" % st):
                    fails.append("class %r slot %r gap_coverage %r 불일치" % (cl, si, gc))
                dom = slot.get("domain")
                if not (isinstance(dom, list) and len(dom) == 2 and isinstance(dom[0], int)
                        and isinstance(dom[1], int) and dom[0] <= dom[1]):
                    fails.append("class %r slot %r domain 형식 오류 %r" % (cl, si, dom))
                    dom = None
                if not isinstance(ivs, list) or not ivs:
                    fails.append("class %r slot %r cell_x인데 intervals 비어있음" % (cl, si))
                else:
                    for iv in ivs:
                        if not (isinstance(iv, list) and len(iv) == 2 and isinstance(iv[0], int)
                                and isinstance(iv[1], int) and iv[0] <= iv[1]):
                            fails.append("class %r slot %r interval 형식 오류 %r" % (cl, si, iv))
                        elif dom is not None and (iv[0] < dom[0] or iv[1] > dom[1]):
                            fails.append("class %r slot %r interval %r 도메인 %r 밖" % (cl, si, iv, dom))
            elif ax != "none":
                fails.append("class %r slot %r placement_axis 미상 (%r)" % (cl, si, ax))
    return fails


def verify_one_diverse(stage_id: int, workers: int) -> bool:
    dpath = SOLUTIONS_DIR / f"stage{stage_id:02d}.diverse.json"
    if not dpath.exists():
        print("[diverse-verify] stage%02d: diverse.json 없음 — FAIL" % stage_id)
        return False
    report = json.loads(dpath.read_text(encoding="utf-8"))
    cov = _coverage_check_diverse(report)
    if cov:
        print("[diverse-verify] stage%02d: coverage FAIL" % stage_id)
        for c in cov:
            print("    - %s" % c)
        return False
    cs = int(report["cell_size"])
    required = int(report["candy_hp"])
    roll = analyze.Rollouter(report["stage_scene"], int(report["deadline_frames"]), required, workers)

    # 재검증 체크 묶음 — class별 reference clear + 각 cell_x 슬롯 interval 경계/내부=clear, 양 끝 밖·gap=fail
    # (gap_verified 구간만 양 끝 밖 fail 단언; sampled는 내부 clear만). analyze.py --verify와 동형.
    checks: list = []
    for cls in report["solution_classes"]:
        cl = cls["class"]
        ref = cls["reference_plan"]
        checks.append(("class%d reference clears" % cl, ref, True))
        for slot in cls["slots"]:
            if slot.get("placement_axis") != "cell_x":
                continue
            ri = int(slot["ref_index"])
            stride = int(slot["gap_check_stride"])
            gv = bool(slot["gap_verified"])
            dom_lo, dom_hi = slot["domain"]
            for lo, hi in slot["intervals"]:
                interior = sorted(set([lo, hi, (lo + hi) // 2] + list(range(lo, hi + 1, stride))))
                for c in interior:
                    checks.append(("c%d s%d cell%d=clear" % (cl, slot["slot"], c),
                                   _make_sweep_plan(ref, ri, c, cs), True))
                # 경계 밖 fail 단언은 **검증 구역(gap_verified) + 도메인 내부 경계**만(R: 구역이 스윕 도메인
                # 끝에 닿으면 그 바깥은 미샘플 → fail 미보장, threshold 즉시발화 모호성도 회피). lo>dom_lo이면
                # lo-1은 스윕된 fail 셀, hi<dom_hi이면 hi+1은 스윕된 fail 셀이라 결정론 재현된다.
                if gv and lo > dom_lo:
                    checks.append(("c%d s%d cell%d(下)밖=fail" % (cl, slot["slot"], lo - 1),
                                   _make_sweep_plan(ref, ri, lo - 1, cs), False))
                if gv and hi < dom_hi:
                    checks.append(("c%d s%d cell%d(上)밖=fail" % (cl, slot["slot"], hi + 1),
                                   _make_sweep_plan(ref, ri, hi + 1, cs), False))
            for glo, ghi in slot.get("gaps", []):
                checks.append(("c%d s%d gap[%d,%d]=fail" % (cl, slot["slot"], glo, ghi),
                               _make_sweep_plan(ref, ri, (glo + ghi) // 2, cs), False))

    results = roll.batch_results([c[1] for c in checks])
    ok_all = True
    for (desc, _plan, expect_clear), res in zip(checks, results):
        why = analyze._verdict_check(res, expect_clear, required)
        if why:
            print("[diverse-verify] stage%02d FAIL: %s (%s)" % (stage_id, desc, why))
            ok_all = False
    if ok_all:
        print("[diverse-verify] stage%02d PASS (%d 체크, %d 롤아웃)" % (stage_id, len(checks), roll.count))
    return ok_all


def _diverse_stage_ids() -> list[int]:
    import re
    ids = []
    for p in sorted(SOLUTIONS_DIR.glob("stage*.diverse.json")):
        m = re.match(r"stage(\d+)\.diverse\.json$", p.name)
        if m:
            ids.append(int(m.group(1)))
    return ids


def _selfcheck_diverse() -> bool:
    """게이트 검출기(`_coverage_check_diverse`) 음성/양성 자가검증 — fail-open 회귀 방지(analyze
    `_selfcheck_gate` 선례). 검출기가 약해지면 verify 자체가 먼저 FAIL한다."""
    def good() -> dict:
        ref = [
            {"skill": "blocker", "target": {"mode": "ant", "select": "min_x", "y_min": 1.0, "y_max": 2.0},
             "trigger": {"type": "ant_reaches_x", "cmp": "le", "x": 24.0}},
            {"skill": "climber", "target": {"mode": "ant", "select": "min_x", "state": "carrying"},
             "trigger": {"type": "picked_ge", "n": 1}},
        ]
        return {
            "schema_version": DIVERSE_SCHEMA_VERSION, "cell_size": 48,
            "solution_classes": [{
                "class": 1, "axis": "strategy", "skill_multiset": {"blocker": 1, "climber": 1},
                "inventory": {"blocker": 1, "climber": 1}, "reference_plan": ref,
                "expect": {"cleared": True, "saved": 5},
                "slots": [
                    {"slot": 0, "ref_index": 0, "skill": "blocker",
                     "role": {"mode": "ant", "select": "min_x", "state": "any"},
                     "timing": {"trigger_type": "ant_reaches_x", "cmp": "le"},
                     "placement_axis": "cell_x", "fixed_cell": 0, "intervals": [[0, 1]], "gaps": [],
                     "range_sampled": True, "gap_check_stride": 1, "gap_verified": True,
                     "gap_coverage": "full@1", "axis_independent": True, "provisional": False,
                     "domain": [0, 18], "sampled_points": list(range(0, 19))},
                    {"slot": 1, "ref_index": 1, "skill": "climber",
                     "role": {"mode": "ant", "select": "min_x", "state": "carrying"},
                     "timing": {"trigger_type": "picked_ge", "n": 1},
                     "placement_axis": "none", "fixed_cell": None, "intervals": [], "gaps": [],
                     "range_sampled": False, "gap_check_stride": None, "gap_verified": False,
                     "gap_coverage": "none", "axis_independent": True, "provisional": False},
                ],
            }],
        }
    cases: list = [(good(), False)]
    a = good(); del a["schema_version"]; cases.append((a, True))                          # 스키마 누락
    a = good(); a["schema_version"] = 99; cases.append((a, True))                         # 스키마 버전 불일치
    a = good(); a["solution_classes"] = []; cases.append((a, True))                       # 빈 class
    a = good(); a["solution_classes"][0]["skill_multiset"] = {"blocker": 9}; cases.append((a, True))  # multiset 변조
    a = good(); a["solution_classes"][0]["expect"] = {"cleared": True, "saved": 0}; cases.append((a, True))  # 약한 expect
    a = good(); a["solution_classes"][0]["expect"] = {"cleared": False, "saved": 5}; cases.append((a, True))  # cleared 위장
    a = good(); a["solution_classes"][0]["slots"][0]["gap_verified"] = False; cases.append((a, True))  # stride1인데 gv=false
    a = good(); a["solution_classes"][0]["slots"][0]["gap_coverage"] = "full@9"; cases.append((a, True))  # coverage 불일치
    a = good(); a["solution_classes"][0]["slots"][0]["gap_check_stride"] = 0; cases.append((a, True))  # stride 비양수
    a = good(); a["solution_classes"][0]["slots"][0]["intervals"] = []; cases.append((a, True))  # cell_x 빈 intervals
    a = good(); a["solution_classes"][0]["slots"][0]["ref_index"] = 9; cases.append((a, True))  # ref_index 범위 밖
    a = good(); a["solution_classes"][0]["slots"][0]["role"] = {"mode": "ant", "select": "max_x", "state": "any"}; cases.append((a, True))  # role 변조
    a = good(); a["solution_classes"][0]["slots"][0]["timing"] = {"trigger_type": "ant_reaches_x", "cmp": "ge"}; cases.append((a, True))  # timing 변조
    a = good(); a["solution_classes"][0]["slots"].pop(); cases.append((a, True))          # slots count 불일치
    a = good(); a["solution_classes"][0]["slots"][0]["placement_axis"] = "weird"; cases.append((a, True))  # 미상 axis
    a = good()
    a["solution_classes"][0]["slots"][0].update({"gap_check_stride": 3, "gap_verified": False,
                                                 "gap_coverage": "sampled@3", "intervals": [[0, 6]], "provisional": True})
    cases.append((a, False))                                                              # sampled(stride>1) 정합 → 통과
    for report, should_reject in cases:
        if bool(_coverage_check_diverse(report)) != should_reject:
            print("[diverse-verify] GATE SELFCHECK FAIL: should_reject=%s\n  %s" % (
                should_reject, json.dumps(report.get("solution_classes"), ensure_ascii=False)[:300]))
            return False
    return True


def verify_diverse(stage_ids: list[int], workers: int) -> int:
    print("[diverse-verify] diverse.json 게이트 재검증: %s" % ["stage%02d" % s for s in stage_ids])
    if not _selfcheck_diverse():
        return 1
    if not stage_ids:        # fail-closed — 검증 대상 0개 = 통과 아닌 실패(빈 통과 위장 차단).
        print("[diverse-verify] FAIL - 검증할 diverse.json 없음")
        return 1
    all_ok = True
    for sid in stage_ids:
        if not verify_one_diverse(sid, workers):
            all_ok = False
    if all_ok:
        print("[diverse-verify] PASS - all %d diverse 게이트 그린" % len(stage_ids))
        return 0
    print("[diverse-verify] FAIL")
    return 1
