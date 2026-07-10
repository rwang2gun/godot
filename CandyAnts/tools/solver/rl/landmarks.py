# auto-solver §R4b — 랜드마크 추출기 (레이아웃-정적, 순수·결정론. 2026-07-10)
#
# r4.0 문법의 액션은 절대 좌표(y_row/x)가 아니라 "장소의 성질"(랜드마크 유형 + 오프셋)을 지시한다.
# 이 모듈은 레이아웃만으로(트레이스 불요) 랜드마크 인스턴스를 결정론 열거하고 geometry-정규화 피처를
# 계산한다. 타일/해저드 *의미*(lethal/slow, breakable_by)는 하드코딩하지 않고 엔진 self-describing
# 메타(SolverMetaDump의 tiles/hazards — §R4a)를 인자로 받는다(D7).
#
# R4_PIN(plan §R4): 유형 어휘 10종 + 정렬 키 (유형-pin-순서, row, col, dir) + OFFSET_DOMAIN {0,1,2}
# + LANDMARK_CANDIDATE_CAP=64(결정론 절단·회계) + 피처 스키마 7항 + landmark_schema_digest.
# 주의: diagnose(model.py)의 낙하-가장자리는 트레이스 기반 — 여기서는 동일 개념을 기하로 정적 검출
# (받쳐진 표면 셀에서 d 방향 이웃이 벽도 지지도 아니면 낙하 가장자리; 낙하 스캔 첫 충돌로 치명 분류).

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import model  # parse_layout(exclude_background)·_has_ceiling read-only 재사용  # noqa: E402

# ---- R4_PIN 상수 (plan §R4 — verify-r4가 digest 대조) ----
LANDMARK_TYPES = (
    "water_edge",        # 치명 낙하 가장자리(낙하 스캔이 lethal hazard/그리드 밖으로 종착)
    "fall_edge",         # 비치명 낙하 가장자리(solid 착지)
    "ladder_top",        # 정적 사다리(climbable) 기둥 최상단
    "ladder_bottom",     # 정적 사다리 기둥 최하단
    "sticky_span_edge",  # 감속(non-lethal) 해저드 구간 진입 경계
    "plant_wall",        # cutter 대상 벽(engine plant) 앞 표면 셀
    "earth_wall",        # basher/digger 대상 벽(engine earth, 사다리 제외) 앞 표면 셀
    "candy_adj",         # candy 인접 표면 셀
    "home_adj",          # home 인접 표면 셀
    "ceiling_surface",   # 천장(상공 solid) 있는 표면 셀 **전부**(per-cell, dir=0) — v11 추가
                         #  (2026-07-10 사용자 결정 2단): ① drop_column 기각(가장자리 직하가 항상
                         #  유익하지 않음) ② 경계-한정도 기각(밀실형 S25류는 경계=벽뿐, 구간 안
                         #  최적점은 상황 의존 — "경계일 수도 아닐 수도"). 천장 구간 내 어느 셀이
                         #  좋은지는 pointer 피처가 상황별로 학습. 근거: S17 천장-선호 실측(천장
                         #  無=saved0/有=5/5) + S19 cell-up 갭 셀(10,14)=천장 표면.
    "surface_segment",   # 잔여 표면 구간 끝점(표현 완전성 하한)
)
OFFSET_DOMAIN = (0, 1, 2)          # 랜드마크에서 dir 반대로 물러나는 표면 셀 수
# cap 64→128 개정(2026-07-10, v11과 동시 — 실측 근거): ceiling_surface(per-cell) 추가 후 S25(밀실형)
# total=113으로 64에서 ceiling 17개 절단 = 사용자 지적 스테이지에서 갭 재발 구조. 128 = 전 캠페인
# 스테이지 무절단(최대 S25=113). 절단 회계·정렬(잔여 유형 후순위)은 그대로 유지.
LANDMARK_CANDIDATE_CAP = 128       # 초과 시 정렬 키 상위 128 결정론 절단(회계 필수)
SORT_KEY_DESC = "(type_pin_index, row, col, dir)"
# 피처 7항(스키마 pin): type one-hot(11) / dist_candy / dist_home / drop_height / has_ceiling /
# adj_hazard one-hot(none,slow,lethal) / breakable_match. 전량 float32 도메인, 레이아웃 상수 정규화.
FEATURE_SCHEMA = ("type_onehot11", "dist_candy_over_WH", "dist_home_over_WH",
                  "drop_height_over_H", "has_ceiling", "adj_hazard_onehot3", "breakable_match")
FEATURE_DIM = 11 + 1 + 1 + 1 + 1 + 3 + 1   # = 19


def landmark_schema_digest() -> str:
    """유형 어휘·정렬·오프셋·cap·피처 스키마의 sha256 — 산출물·ckpt·verify-r4 대조 키."""
    spec = {"types": list(LANDMARK_TYPES), "offset_domain": list(OFFSET_DOMAIN),
            "cap": LANDMARK_CANDIDATE_CAP, "sort_key": SORT_KEY_DESC,
            "features": list(FEATURE_SCHEMA), "feature_dim": FEATURE_DIM}
    return hashlib.sha256(json.dumps(spec, sort_keys=True).encode("utf-8")).hexdigest()


def _standing_cells(occ: set, W: int, H: int) -> set:
    """개미가 설 수 있는 셀: 빈 (c,r) 아래 (c,r+1)이 solid (mdp y_rows와 동일 술어, 그리드 경계 내)."""
    out: set = set()
    for (sc, sr) in occ:
        c, r = sc, sr - 1
        if 0 <= r < H and 0 <= c < W and (c, r) not in occ:
            out.add((c, r))
    return out


def _hazard_lethal(hazard_kind: str, hazard_meta: dict) -> bool:
    m = hazard_meta.get(hazard_kind)
    return bool(m.get("lethal", True)) if m else True   # 미지 kind = 보수적으로 치명(fail-safe)


def _drop_scan(col: int, row: int, occ: set, hazard: dict, hazard_meta: dict, H: int):
    """(col,row)에서 낙하 시작 → (치명 여부, 낙하 높이). 스캔: 아래로 내려가며 lethal hazard 셀 =
    치명 / solid 도달 = 착지(비치명) / 그리드 밖 = 치명(lost). sticky(non-lethal)는 통과."""
    for ry in range(row + 1, H + 1):
        cell = (col, ry)
        hk = hazard.get(cell)
        if hk is not None and _hazard_lethal(hk, hazard_meta):
            return True, ry - row
        if cell in occ:
            return False, (ry - 1) - row
    return True, H - row


def extract(layout: dict, W: int, H: int, inventory_skills: set,
            tile_meta: dict, hazard_meta: dict) -> dict:
    """랜드마크 인스턴스 열거(결정론). 반환:
      {"instances": [{type, cell:(c,r), dir, features:[float]*18}...] (정렬·cap 절단 후),
       "total_before_cap", "truncated_by_type": {type: n}, "digest": landmark_schema_digest()}
    layout = model.parse_layout(..., exclude_background=True) 결과(r4 경로 전용).
    tile_meta/hazard_meta = 엔진 SolverMetaDump tiles/hazards(§R4a) — 의미 하드코딩 0."""
    occ: set = layout["occupied"]
    kinds: dict = layout["kinds"]
    hazard: dict = layout["hazard"]
    ladder: set = layout["ladder"]
    candy = layout.get("candy")
    home = layout.get("home")
    standing = _standing_cells(occ, W, H)

    def engine_kind(cell) -> str:
        k = kinds.get(cell, "")
        m = tile_meta.get(k)
        return str(m.get("engine_kind", "")) if m else ""

    raw: list = []   # (type, cell, dir)

    for (c, r) in sorted(standing):
        for d in (-1, 1):
            ahead, ahead_below = (c + d, r), (c + d, r + 1)
            if ahead in occ:
                # 벽 — engine kind로 분류(사다리 셀은 climbable이라 벽 아님).
                if ahead in ladder:
                    continue
                ek = engine_kind(ahead)
                if ek == "plant":
                    raw.append(("plant_wall", (c, r), d))
                elif ek == "earth":
                    raw.append(("earth_wall", (c, r), d))
                continue
            if ahead_below not in occ:
                # 낙하 가장자리 — 낙하 스캔으로 치명/비치명 분류.
                lethal, _drop = _drop_scan(c + d, r, occ, hazard, hazard_meta, H)
                raw.append(("water_edge" if lethal else "fall_edge", (c, r), d))
            hk = hazard.get(ahead)
            if hk is not None and not _hazard_lethal(hk, hazard_meta) and hazard.get((c, r)) is None:
                raw.append(("sticky_span_edge", (c, r), d))

    # 사다리 기둥 상/하단(정적 climbable — layout ladder 셀).
    for (c, r) in sorted(ladder):
        if (c, r - 1) not in ladder:
            raw.append(("ladder_top", (c, r), -1))
            raw.append(("ladder_top", (c, r), 1))
        if (c, r + 1) not in ladder:
            raw.append(("ladder_bottom", (c, r), -1))
            raw.append(("ladder_bottom", (c, r), 1))

    # candy/home 인접 표면 셀(Chebyshev ≤1, dir = 목표를 향한 부호·0).
    for typ, target in (("candy_adj", candy), ("home_adj", home)):
        if target is None:
            continue
        for (c, r) in sorted(standing):
            if max(abs(c - target[0]), abs(r - target[1])) <= 1:
                dc = target[0] - c
                raw.append((typ, (c, r), 1 if dc > 0 else (-1 if dc < 0 else 0)))

    # 천장 표면(v11): 천장 있는 표면 셀 전부 — per-cell 단일 인스턴스(dir=0, 오프셋 no-op).
    # 경계 한정 아님(밀실형 S25류 + "구간 안 최적점은 상황 의존" — 사용자 결정 2026-07-10).
    for (c, r) in sorted(standing):
        if model._has_ceiling(occ, c, r):
            raw.append(("ceiling_surface", (c, r), 0))

    # 잔여 표면 구간(수평 최대 연속 run)의 양 끝점 — dir는 구간 안쪽(오프셋이 구간 위를 걷도록).
    seen_rows: dict = {}
    for (c, r) in standing:
        seen_rows.setdefault(r, set()).add(c)
    for r in sorted(seen_rows):
        cols = sorted(seen_rows[r])
        run_start = cols[0]
        prev = cols[0]
        for c in cols[1:] + [None]:
            if c is not None and c == prev + 1:
                prev = c
                continue
            raw.append(("surface_segment", (run_start, r), -1))   # 왼끝(안쪽=+1 → 낙하 dir=-1 관례 유지:
            raw.append(("surface_segment", (prev, r), 1))          # dir=바깥쪽, 오프셋=반대(안쪽)로 후퇴)
            if c is not None:
                run_start = c
                prev = c

    # 중복 제거(같은 (type,cell,dir)) 후 pin 정렬.
    uniq = sorted(set(raw), key=lambda t: (LANDMARK_TYPES.index(t[0]), t[1][1], t[1][0], t[2]))

    # cap 절단(결정론 — 정렬 상위 유지) + 유형별 회계.
    truncated_by_type: dict = {}
    if len(uniq) > LANDMARK_CANDIDATE_CAP:
        for (typ, _cell, _d) in uniq[LANDMARK_CANDIDATE_CAP:]:
            truncated_by_type[typ] = truncated_by_type.get(typ, 0) + 1
    kept = uniq[:LANDMARK_CANDIDATE_CAP]

    wh = float(W + H) if (W + H) > 0 else 1.0
    instances = []
    for (typ, cell, d) in kept:
        c, r = cell
        drop = 0
        if typ in ("water_edge", "fall_edge"):
            _lethal, drop = _drop_scan(c + d, r, occ, hazard, hazard_meta, H)
        adj = [0.0, 0.0, 0.0]   # none/slow/lethal one-hot — 인접 4방(상하좌우) 해저드 최악치.
        worst = 0
        for (nc, nr) in ((c + 1, r), (c - 1, r), (c, r + 1), (c, r - 1)):
            hk = hazard.get((nc, nr))
            if hk is None:
                continue
            worst = max(worst, 2 if _hazard_lethal(hk, hazard_meta) else 1)
        adj[worst] = 1.0
        breakable = 0.0
        if typ in ("plant_wall", "earth_wall"):
            wall_kind = kinds.get((c + d, r), "")
            wm = tile_meta.get(wall_kind, {})
            if any(str(s) in inventory_skills for s in wm.get("breakable_by", [])):
                breakable = 1.0
        onehot = [0.0] * len(LANDMARK_TYPES)
        onehot[LANDMARK_TYPES.index(typ)] = 1.0
        feats = onehot + [
            (abs(c - candy[0]) + abs(r - candy[1])) / wh if candy else 1.0,
            (abs(c - home[0]) + abs(r - home[1])) / wh if home else 1.0,
            min(drop, H) / float(H if H > 0 else 1),
            1.0 if model._has_ceiling(occ, c, r) else 0.0,
        ] + adj + [breakable]
        instances.append({"type": typ, "cell": (c, r), "dir": d, "features": feats})

    return {"instances": instances, "total_before_cap": len(uniq),
            "truncated_by_type": truncated_by_type, "digest": landmark_schema_digest()}


def lower_cell(inst: dict, offset: int, layout: dict) -> tuple:
    """랜드마크 인스턴스 + 오프셋 → 실제 표면 셀(하강). 오프셋 k = dir 반대로 같은 행 표면 셀을
    k칸 후퇴(중간에 표면이 끊기면 마지막 유효 셀에서 정지 — 결정론). dir=0이면 후퇴 없음."""
    occ = layout["occupied"]
    c, r = inst["cell"]
    d = inst["dir"]
    if d == 0 or offset == 0:
        return (c, r)
    cur = c
    for _ in range(offset):
        nxt = cur - d
        if (nxt, r) in occ or (nxt, r + 1) not in occ:
            break                                   # 벽이거나 지지 없음 → 후퇴 종료
        cur = nxt
    return (cur, r)
