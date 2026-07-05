#!/usr/bin/env python3
"""
⛔ ARCHIVED (Phase 4 강제 종료, 2026-06-24) — 라이브 경로 아님. 매니페스트: tools/solver/ARCHIVE.md.
   boost(seed) 메커니즘은 4a 실측에서 falsify(NO-TRANSFER: propose() 휴리스틱이 이미 동순위라 롤아웃 0 감소).
   음성-입증 이력으로 **보존**(삭제 안 함). 유일 소비자 = try_solve.py transfer-bench(--mode seed, 역시 archived).
   solve.solve(seed_fn=None)이 기본이라 게이트에 inert. 신규 코드에서 import·재활성 금지.

auto-solver Phase 4 (CBR/EBL) — 전술 라이브러리 (순수 / 엔진 비의존).

D8: 한 레벨을 풀면 해법을 *국소 기하+타이밍*으로 일반화한 **전술**(구조화 사례, ML 가중치 아님)로 저장 →
새 레벨에서 매칭·시드 → 탐색 롤아웃 급감. 해석가능성은 D9 생성 오라클의 전제.

이 모듈은 model.py처럼 **순수**다(엔진/subprocess 호출 0). solve.py가 seed_fn으로 주입하면, propose()가
낸 후보 풀에서 학습 전술과 일치하는 후보를 골라 **source-tag(`seeded:<id>`) + 보너스**를 달아 반환한다.
solve.py는 그걸 앞쪽에 머지해 먼저 롤아웃하고, _Clear를 트리거한 결정적 액션의 source-tag로 **전이를
provenance(출처) 기반으로 귀속**한다(plan-review R2: content-match 금지).

Phase 4 단계(auto-solver-plan.md):
  4a(현재, de-risk): 전술 *수동* 추출(아래 manual_library) → S12/S13 하드 시드 → transfer-bench로 ON/OFF 비교.
  4b: extract()로 solve.json에서 자동 추출. 4c: seed() 자동 매칭으로 4a 수동 시드 대체. 4d: 성장·영속.

전술 데이터 모델 (D8):
  Tactic = {id, routing, precondition(국소패턴), placement(상대배치), timing(앵커), subgoal, success_history}.

리프팅 계약 (plan R1 MEDIUM — 모호성 차단):
  - routing은 스킬 id가 아니라 메타 routing("reverse" 등)으로 — 신규 동종 도구 자동 편입(D7).
  - precondition은 diagnose가 산출하는 국소 패턴(낙하 가장자리·to_water 등)으로만 표현. 절대 셀 참조 금지.
  - placement는 낙하 가장자리 셀(reverse_target backpath off=0..2)에 상대적 — 절대좌표 저장 안 함.
  - timing은 이벤트 상대(ant_reaches_x@edge) — 프레임 절대값 저장 안 함.
  - 모호성 없이 매칭 안 되면 시드 안 함(silent 오버피팅 대신 명시적 누락).
"""
from __future__ import annotations

import re

# 시드 보너스: 학습 전술과 일치하는 후보를 후보 풀 맨 앞으로 당긴다(먼저 롤아웃 → 맞으면 적은 롤아웃에
# _Clear). propose의 reverse _w(≈최대 20대)·climber carry_base(≤220)보다 크게 잡아 reverse 전술을
# 확실히 front-load(4a: blocker-우선이 S12·S13 모두 정답 순서). 보너스 정밀 튜닝은 4c 범위.
SEED_BONUS = 1000


def manual_library() -> list[dict]:
    """4a 수동 추출: S11 해(blocker 1개, max_x 반전@물-가장자리)에서 리프팅한 전술 1개.

    S11 solve.json action을 리프팅 계약으로 일반화:
      절대값 {select:max_x, x:1032(col21), y:520~632(row11)} → 국소 패턴 {routing:reverse, to_water 가장자리,
      placement:가장자리 grounded 셀, timing:해당 가장자리 x 도달}. 좌표·특정 개미 식별은 모두 제거됐다.
    이 전술은 "물로 떨어지는 낙하 가장자리에서 개미를 반전시켜 익사 회피 + 라우팅"을 인코딩한다(S11 본질).
    S12(같은 blocker-반전 3회)·S13(blocker-반전 1회)이 이 전술의 재사용으로 풀린다는 게 전이 가설.
    """
    return [{
        "id": "s11.blocker_reverse_water_edge",
        "routing": "reverse",                      # 스킬 id 아님(D7) — reverse 라우팅 도구 일반
        "precondition": {"fall_edge": True, "to_water": True},   # 국소 패턴(diagnose 산출)
        "placement": "grounded_edge_backpath",     # 가장자리 grounded 셀(off=0..2 상대)
        "timing": "ant_reaches_edge_x",            # 이벤트 상대
        "subgoal": "reverse",
        "success_history": ["stage11"],
    }]


# label 형식(model.propose reverse 분기): "%s@%d,%d:%s%s" % (sid, col, row, sel, cmp)
_REVERSE_LABEL = re.compile(r"^(?P<sid>\w+)@(?P<col>-?\d+),(?P<row>-?\d+):(?P<sel>\w+?)(?P<cmp>ge|le)$")


def _cand_cell(cand: dict) -> tuple[int, int] | None:
    """reverse 분기 후보 label에서 (col,row) 복원. carry/early/afterpick 등 비-reverse label은 None."""
    m = _REVERSE_LABEL.match(cand.get("label", ""))
    if not m:
        return None
    return (int(m.group("col")), int(m.group("row")))


def _water_edge_cells(diag: dict) -> set[tuple[int, int]]:
    """물 익사로 이어진 낙하 가장자리의 backpath 셀(off=0..2) 집합 — 전술 precondition(to_water) 매칭용."""
    cells: set[tuple[int, int]] = set()
    for tgt in diag.get("reverse_targets", []):
        if not tgt.get("to_water"):
            continue
        bp = tgt.get("backpath") or [tgt.get("cell")]
        for off, cell in enumerate(bp[:3]):
            if cell is not None:
                cells.add(tuple(cell))
    return cells


def _matches(tac: dict, cand: dict, diag: dict, metas: dict, water_cells: set) -> bool:
    """후보가 전술을 실현하는가 — routing 일치 + precondition(물-가장자리) 일치(모호성 없을 때만)."""
    sid = cand.get("action", {}).get("skill")
    routing = str((metas.get(sid) or {}).get("routing", ""))
    if routing != tac["routing"]:
        return False
    if tac["precondition"].get("to_water"):
        cell = _cand_cell(cand)
        if cell is None or cell not in water_cells:
            return False
    return True


def seed(layout: dict, diag: dict, inventory: dict, metas: dict, library: list[dict]) -> list[dict]:
    """학습 전술과 일치하는 시드 후보를 반환. 각 후보 = propose가 낸 dict의 복제 + 보너스 + source-tag.

    **byte-identical 보장**: model.propose의 후보 풀에서 *고르기*만 한다(action을 새로 만들지 않음) →
    OFF/ON 경로의 후보 action 집합이 동일하고, 차이는 _w 보너스 + source-tag뿐(plan R1 HIGH-1 측정 계약).
    OFF는 seed를 아예 호출하지 않으므로 모든 후보 source="fallback"으로 남는다.
    """
    # 늦은 import(순수 모듈 간 순환 회피). model.propose는 엔진 비의존이라 안전.
    import model
    pool = model.propose(layout, diag, inventory, metas, notes={}, exclude=set(), max_n=10_000)
    water_cells = _water_edge_cells(diag)
    seeded: list[dict] = []
    for tac in library:
        for c in pool:
            if _matches(tac, c, diag, metas, water_cells):
                sc = dict(c)
                sc["_w"] = c["_w"] + SEED_BONUS
                sc["source"] = "seeded:" + tac["id"]
                seeded.append(sc)
    return seeded
