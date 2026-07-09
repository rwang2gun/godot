#!/usr/bin/env python3
"""
auto-solver Phase 2 — 라우팅 예측 모델 (순수 / 엔진 비의존).

D10: 엔진은 진실(verdict 오라클)이고, 이 모듈은 *계획 가속 휴리스틱*이다. 개미는 "막히기 전엔 방향을
안 바꾼다"(사용자 통찰)는 규칙 위에서, **엔진이 관측한 베이스라인 궤적(트레이스)** 을 입력으로 받아
실패를 진단하고 다음 개입(어떤 스킬을 어디에·언제)을 제안한다. 제안은 solve.py가 엔진으로 검증한다.

순수 함수 모음(엔진/subprocess 호출 없음):
  parse_layout(path)          → 지형 그리드(occupied/ladder/hazard/candy/home/cell_size)
  diagnose(trace, layout, hp) → 실패 진단(물 진입 지점·candy 근접·픽업/저장 격차)
  propose(layout, diag, inventory, metas, notes, exclude) → 다음 개입 후보(랭킹, v1 액션 스키마)

스킬 라우팅은 메타(SOLVER_META.routing, D11)로 디스패치 — 스킬 id 하드코딩 0(신규 도구 자동 편입).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):              # cp949 무관 UTF-8(knowledge.py 등 다른 솔버 모듈과 동일) —
    try:                                         # _selfcheck_* 등 한글/em-dash 출력이 standalone에서도 안전.
        _s.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass


# ---------- 레이아웃 ----------

def parse_layout(layout_tres: Path) -> dict:
    text = layout_tres.read_text(encoding="utf-8")
    cell_size = int(re.search(r"cell_size\s*=\s*(\d+)", text).group(1))
    occupied: set[tuple[int, int]] = set()    # 충돌 셀(solid·사다리 등; 해저드 제외)
    ladder: set[tuple[int, int]] = set()
    kinds: dict[tuple[int, int], str] = {}
    # tile_map 블록만(아래 hazard_map과 분리). 가장 먼저 나오는 tile_map = { ... } 캡처.
    tm = re.search(r"tile_map\s*=\s*\{(.*?)\}", text, re.S)
    if tm:
        for m in re.finditer(r'"(-?\d+),(-?\d+)"\s*:\s*"(\w+)"', tm.group(1)):
            c, r, kind = int(m.group(1)), int(m.group(2)), m.group(3)
            occupied.add((c, r))
            kinds[(c, r)] = kind
            if kind == "sand_mound":
                ladder.add((c, r))
    hazard: dict[tuple[int, int], str] = {}
    hm = re.search(r"hazard_map\s*=\s*\{(.*?)\}", text, re.S)
    if hm:
        for m in re.finditer(r'"(-?\d+),(-?\d+)"\s*:\s*"(\w+)"', hm.group(1)):
            hazard[(int(m.group(1)), int(m.group(2)))] = m.group(3)

    def _vec(name: str) -> tuple[int, int] | None:
        mm = re.search(name + r"\s*=\s*Vector2i\((-?\d+),\s*(-?\d+)\)", text)
        return (int(mm.group(1)), int(mm.group(2))) if mm else None

    return {
        "cell_size": cell_size, "occupied": occupied, "ladder": ladder, "kinds": kinds,
        "hazard": hazard, "candy": _vec("candy_cell"), "home": _vec("home_cell"),
    }


# ---------- 트레이스 진단 ----------

def _samples(trace: dict, si) -> list:
    return trace.get(str(si)) or trace.get(si) or []


def _died_water(ss: list, layout: dict) -> bool:
    """개미가 물(hazard)로 리타이어했는가 — 마지막 샘플 셀이 hazard이거나 바로 아래가 hazard(물 위 허공
    = 익사 직전). 발판 x-범위 밖으로 나가 맵 끝 물로 떨어진 경우도 below-hazard로 잡힌다."""
    haz = layout["hazard"]
    cx, cy = ss[-1][1], ss[-1][2]
    return (cx, cy) in haz or (cx, cy + 1) in haz


def _grounded_backpath(ss: list, i: int, occ: set, cap: int = 4) -> list:
    """낙하 가장자리 샘플 i에서 뒤로 가며 **grounded(바로 아래 solid) 타일만** 수집(공중 낙하 건너뜀). 첫 원소
    = 가장자리 셀 자신(off=0), 이후 = 거슬러 간 보행 타일(off=1,2,…). 같은 (col,row) 연속 중복 제외. cap 중단.
    (reverse backpath용 — 인접성 무관. wall_targets의 연속-세그먼트 수집과 별개.)"""
    bp: list = []
    for j in range(i, -1, -1):
        s = ss[j]
        if (s[1], s[2] + 1) not in occ:
            continue
        cell = (s[1], s[2])
        if bp and bp[-1] == cell:
            continue
        bp.append(cell)
        if len(bp) >= cap:
            break
    return bp


def diagnose(trace: dict, layout: dict, candy_hp: int) -> dict:
    """관측 궤적에서 실패를 진단. 반환:
      picked_total, reverse_targets(반전 블로커 후보, **동선 backpath 포함**), near_candy, fall_edges(legacy).
    **반전 타깃** = 개미가 발판 끝을 밟고 허공/물로 나간 **낙하 가장자리**. 개미는 막히기 전엔 방향을 안
    바꾸므로, 그 직전 grounded 타일에 벽(blocker)을 세우면 반전한다 — (a) 물·추락사 회피 (b) 상승/하강
    라우팅을 동시에 해결.
    **동선 backpath(사용자 통찰)**: off=1,2 변형은 좌표(x-off)가 아니라 **개미가 실제 지나온 grounded
    타일을 거슬러** 잡는다 — 공중 낙하 타일은 건너뛴다. 계단형 하강처럼 가장자리 접근이 수평이 아니어도
    실제 보행 타일(반전 가능)에 정확히 놓이고, 더 거슬러 갈수록 발화 여유(lead time)가 커진다.
    **물 우선(사용자 통찰)**: 물 익사로 이어진 가장자리를 최우선 정렬 — 리타이어 직전 grounded 타일이 1순위."""
    candy = layout["candy"]
    occ = layout["occupied"]
    def supported(cx: int, cy: int) -> bool:
        return (cx, cy + 1) in occ            # 바로 아래 셀이 solid = 발판에 받쳐짐

    fall_edges: dict[tuple, int] = {}                       # (col,row,dir) → count (legacy)
    edge_back: dict[tuple, list] = {}                       # (col,row,dir) → 동선 grounded backpath [(cx,cy),...]
    edge_water: dict[tuple, bool] = {}                      # (col,row,dir) → 물 익사로 이어짐
    edge_goal_above: dict[tuple, bool] = {}                 # (col,row,dir) → **per-sample 목표가 이 셀보다 위**
    #   (미픽업이면 candy, 운반이면 home; 5d② per-sample 목표 규약 정합, OR 집계). 5e D1: 목표-위 fall-edge에만
    #   cell-up(sand_mound 사다리) 후보를 낸다 — 운반 개미를 절벽 위 목표 경로로 들어올리는 게 진척일 때만.
    #   ①(reverse/safe_fall/cross) 후보는 이 필드를 **무시**(낙하 차단은 목표 방향 무관) → byte-identical 보존.
    edge_back_above: dict[tuple, list] = {}                 # (col,row,dir) → **목표-위를 만족한 샘플**의 backpath
    #   (cell-up 전용, codex impl R1 HIGH). edge_back(① 공용, 첫 발견)이 stale 픽업-전 동선이면 cell-up 셀이 틀려
    #   운반 귀환 backpath를 누락하므로, 목표-위 phase의 동선에서 따로 잡는다(첫 목표-위 통과 동선).
    near_candy: dict = {"dist": 1 << 30, "cell": None, "dir": 0}
    picked_ants = 0
    ant_ids = sorted({int(k) for k in trace.keys()}) if trace else []
    for si in ant_ids:
        ss = _samples(trace, si)
        if not ss:
            continue
        picked = any(s[3] == 1 for s in ss)
        if picked:
            picked_ants += 1
        died_water = _died_water(ss, layout)
        # 낙하 가장자리: '받쳐진 셀(cur)'에서 '안 받쳐진 셀(nxt)'로 수평/하향 진입(발판 끝을 밟고 허공/물로
        # 나감). cur가 막을 지점. 등반(cy 감소)은 제외.
        for i in range(len(ss) - 1):
            cur, nxt = ss[i], ss[i + 1]
            if not supported(cur[1], cur[2]):
                continue
            if supported(nxt[1], nxt[2]) or nxt[2] < cur[2]:
                continue                      # 다음도 받쳐짐(정상 보행) 또는 위로(등반) → 낙하 아님
            if nxt[1] > cur[1]:
                d = 1
            elif nxt[1] < cur[1]:
                d = -1
            else:                              # 수직으로 밟고 떨어짐 → 직전 수평 방향 사용
                d = 1 if (i > 0 and cur[1] >= ss[i - 1][1]) else -1
            key = (cur[1], cur[2], d)
            fall_edges[key] = fall_edges.get(key, 0) + 1
            if died_water:
                edge_water[key] = True
            # 5e D1: 이 가장자리 *시점*의 목표(per-sample, cur[3]==1=운반→home / 아니면 candy)가 셀보다 위인가.
            # OR 집계(어느 통과 샘플이든 목표-위면 True) — cell-up 후보 게이트(목표-아래 전용 가장자리는 미emit).
            _goal = _goal_cell(cur[3] == 1, layout)
            _above = _goal is not None and _goal[1] < cur[2]
            edge_goal_above[key] = edge_goal_above.get(key, False) or _above
            # 동선 backpath(① reverse/safe_fall/cross 공용): 첫 발견 동선(가장 이른 통과). ①은 목표 방향 무관이라
            # 첫 발견으로 충분 → byte-identical 보존.
            if key not in edge_back:
                edge_back[key] = _grounded_backpath(ss, i, occ)
            # cell-up 전용 backpath(codex impl R1 HIGH): **목표-위를 만족한** 샘플(운반=home 위/미픽업=candy 위)의
            # 동선에서 따로 수집(첫 목표-위 통과). OR 집계 goal_above에 stale 픽업-전 backpath가 섞여 cell-up이
            # 엉뚱한 route에 사다리를 emit하던 결함을 막는다 — propose ③ fall은 이 backpath_above를 쓴다.
            if _above and key not in edge_back_above:
                edge_back_above[key] = _grounded_backpath(ss, i, occ)
        # candy 근접(미픽업 개미만).
        if not picked and candy is not None:
            for i2, s in enumerate(ss):
                cx, cy = s[1], s[2]
                dist = abs(cx - candy[0]) + abs(cy - candy[1])
                if dist < near_candy["dist"]:
                    d = 0
                    if i2 + 1 < len(ss):
                        d = 1 if ss[i2 + 1][1] >= cx else (-1 if ss[i2 + 1][1] < cx else 0)
                    near_candy = {"dist": dist, "cell": (cx, cy), "dir": d}
    # 정렬: **물 익사 우선**, 그다음 빈도 desc, 그다음 하위 표면(cy 큰 것=candy가 아래일 때 진척) 먼저.
    keys = sorted(fall_edges.keys(),
                  key=lambda k: (0 if edge_water.get(k) else 1, -fall_edges[k], -k[1]))
    reverse_targets = [{"cell": (k[0], k[1]), "dir": k[2], "backpath": edge_back.get(k, [(k[0], k[1])]),
                        "backpath_above": edge_back_above.get(k),
                        "to_water": bool(edge_water.get(k)), "count": fall_edges[k],
                        "goal_above": bool(edge_goal_above.get(k))} for k in keys]
    return {
        "picked_total": picked_ants,
        "reverse_targets": reverse_targets,
        "wall_targets": _wall_targets(trace, layout),   # 상승판(sand_mound cell-up routing)
        "fall_edges": keys,                  # legacy(좌표 키 리스트)
        "near_candy": near_candy,
        "candy_hp": candy_hp,
        "ant_count": len(ant_ids),
    }


def _goal_cell(picked: bool, layout: dict):
    """이 개미의 현재 목표 셀 — 픽업했으면 home(귀환), 아니면 candy(접근)."""
    return layout.get("home") if picked else layout.get("candy")


def _wall_targets(trace: dict, layout: dict) -> list[dict]:
    """**벽-반전** 검출(reverse_targets의 *상승판*, sand_mound cell-up routing용). 개미가 grounded로 진행하다
    **같은 row 전방 셀이 solid**(벽)라 반전(flip)하고 **목표가 더 위**(climbing이 진척)일 때의 벽-기저 셀을 수집.
    방향 d = **진입(incoming) 세그먼트 방향**(반전 직전 마지막 수평 이동 부호) — 트레이스에 ant.direction이 없으므로
    명시 정의(plan-review R1). soundness = 전방 `(cx+d_in, cy)` occupied(허공 반전·절벽 배제). backpath = 진입측
    grounded 타일을 거슬러 ≥6 수집(reverse의 depth-4 cap **비재사용**, plan-review R3-M1 — col-sweep witness 보호)."""
    occ = layout["occupied"]
    def supported(cx, cy):
        return (cx, cy + 1) in occ
    agg: dict = {}                                  # (col,row,d_in) -> {backpath, count}
    for si in sorted({int(k) for k in trace.keys()}) if trace else []:
        ss = _samples(trace, si)
        if len(ss) < 2:
            continue
        for i in range(1, len(ss) - 1):
            cx, cy = ss[i][1], ss[i][2]
            if not supported(cx, cy):
                continue
            dx_in = ss[i][1] - ss[i - 1][1]
            dx_out = ss[i + 1][1] - ss[i][1]
            if dx_in == 0:
                continue
            d_in = 1 if dx_in > 0 else -1
            reversed_here = (dx_out == 0) or ((1 if dx_out > 0 else -1) != d_in)
            if not reversed_here:
                continue
            if (cx + d_in, cy) not in occ:           # 전방 same-row solid 아님 → 벽 아님(허공 반전·절벽)
                continue
            # **per-sample 목표**(codex impl-review R1-HIGH): 이 반전 *시점*의 상태로 목표 결정 — carrying(s[3]==1)
            # 이면 home(귀환), 아니면 candy(접근). 트레이스 전체 any()-picked로 단일화하면 픽업 *전* 접근 벽을 home
            # 기준 오판정해 유효 상승 벽을 누락한다. 게이트·정렬 모두 이 phase-별 목표를 쓴다.
            picked = 1 if ss[i][3] == 1 else 0
            goal = _goal_cell(picked == 1, layout)
            if goal is None or goal[1] >= cy:        # 목표가 위가 아니면 상승 무익 → 배제
                continue
            # **phase(picked)를 키에 포함**(codex impl-review R2-HIGH): 같은 벽이 픽업 전/후 둘 다 나올 때, 나중
            # phase가 자기 gx·backpath를 잃고 stale 접근-phase 데이터로 병합·정렬되지 않게 한다(phase별 별도 레코드).
            key = (cx, cy, d_in, picked)
            if key in agg:
                agg[key]["count"] += 1
                continue
            # **연속 접근 세그먼트**(codex impl-review R2-MED): 진입측 grounded 타일을 거슬러 수집하되, 직전 수용
            # 셀과 **비인접**(Chebyshev>1: 루프·점프·무관 행)이면 중단 — 접근로 밖 stale 셀이 off-preference로
            # 실제 벽 접근 셀을 밀어내 cap을 소진하는 걸 막는다. (S19 평지는 전부 인접 → 6칸 수집.)
            bp: list = []
            last = None
            for j in range(i, -1, -1):
                s = ss[j]
                if not supported(s[1], s[2]):
                    continue
                cell = (s[1], s[2])
                if last is not None and cell == last:
                    continue
                if last is not None and (abs(cell[0] - last[0]) > 1 or abs(cell[1] - last[1]) > 1):
                    break                            # 비인접 → 접근 세그먼트 종단(stale 셀 배제)
                bp.append(cell)
                last = cell
                if len(bp) >= 6:
                    break
            agg[key] = {"backpath": bp, "count": 1, "gx": goal[0]}   # gx = 이 target의 phase-별 목표 col(정렬용)
    # 정렬: **각 target의 목표 col** 근접 desc(가까운 벽 우선), 빈도 desc, 결정론 tie-break(좌표·방향·phase).
    keys = sorted(agg.keys(), key=lambda k: (abs(k[0] - agg[k]["gx"]), -agg[k]["count"], k[0], k[1], k[2], k[3]))
    return [{"cell": (k[0], k[1]), "dir": k[2], "backpath": agg[k]["backpath"], "count": agg[k]["count"]}
            for k in keys]


# ---------- 개입 제안 (메타 routing 디스패치, D11) ----------

def count_trapped(trace: dict, reversal_thresh: int = 6) -> tuple[int, int]:
    """무한루프(블로커와 왕복) 개미 수 — 사용자 통찰: 한 블로커와의 충돌(=방향 반전)이 과다하면 갇힘.
    트레이스 수평 방향-반전 횟수로 근사(엔진 수정 불요). 반환 (carry_trapped, total_trapped).
    carry_trapped = carrying 상태로 갇힌 수(귀환 막힘 = S12 증상의 직접 신호)."""
    carry = total = 0
    ant_ids = sorted({int(k) for k in trace.keys()}) if trace else []
    for si in ant_ids:
        ss = _samples(trace, si)
        dirs = []
        for i in range(len(ss) - 1):
            dx = ss[i + 1][1] - ss[i][1]
            if dx != 0:
                dirs.append(1 if dx > 0 else -1)
        reversals = sum(1 for i in range(1, len(dirs)) if dirs[i] != dirs[i - 1])
        if reversals >= reversal_thresh:
            total += 1
            if any(s[3] == 1 for s in ss):
                carry += 1
    return carry, total


def _goal_dist_at(s: list, layout: dict) -> int:
    """샘플 s의 목표까지 셀 맨해튼 — 픽업 전 candy, 픽업 후 home(per-sample carry). 목표 없으면 큰 값."""
    g = _goal_cell(s[3] == 1, layout)
    if g is None:
        return 1 << 30
    return abs(s[1] - g[0]) + abs(s[2] - g[1])


def frontier_dists(trace: dict, layout: dict) -> tuple:
    """진척 프런티어(워크로그 §14.3 v3 — 사용자 정의 '시행착오' 판정용, 2026-07-10).
    에피소드 전체에서 (빈손 개미가 candy에 접근한 최소 맨해튼, 운반 개미가 home에 접근한 최소 맨해튼).
    '시행착오' = 미클리어 & 두 축 모두 역대 최소 미갱신 — 판정은 호출측(train.KnowledgeLedger).
    해당 상태 샘플이 없으면 그 축은 BIG(1<<30, fail-safe: 개선으로 오인 안 됨). 순수·결정론."""
    best_w = best_c = 1 << 30
    if not trace:
        return best_w, best_c
    for si in {int(k) for k in trace.keys()}:
        for s in _samples(trace, si):
            d = _goal_dist_at(s, layout)
            if d >= (1 << 30):                # 목표 없음(_goal_cell None) — 프런티어 집계 제외
                continue
            if s[3] == 1:
                best_c = min(best_c, d)
            else:
                best_w = min(best_w, d)
    return best_w, best_c


def blocker_redirect_value(trace: dict, layout: dict, blocker_cells, adj: int = 1) -> float:
    """**생산적 blocker 활용도** — blocker가 유발한 반전이 목표 진척으로 이어진 총량(정규화 전, 셀 단위).
    실증(2026-07-06): S12에서 raw bump 카운트는 좋은/나쁜 배치를 못 가른다(가드가 트랩 bump 폭발을
    막음, 좋은 해가 오히려 bump 최다). 진짜 판별자 = **반전 × 진척**. 각 개미 trace에서:
      ① blocker 셀 인접(Chebyshev<=adj)에서 수평 방향-반전이 1회 이상 있었는가(= blocker가 이 개미를
         리다이렉트) → 아니면 제외(blocker-귀속 게이트, 스킬-의미론 = 전이 가능).
      ② 그렇다면 이 개미의 (시작 goal_dist − 도달 최소 goal_dist)를 진척으로 적립(픽업=candy 접근, 귀환=home).
    blocker_cells = 이번 에피소드 실제 정착 blocker 셀 집합 {(col,row)}. 순수·결정론. 정규화(D0·ants)는
    호출측(mdp.blocker_bonus). 반환 = 진척 셀 합(≥0)."""
    if not trace or not blocker_cells:
        return 0.0
    bcells = set(blocker_cells)
    total = 0.0
    for si in sorted({int(k) for k in trace.keys()}):
        ss = _samples(trace, si)
        if len(ss) < 2:
            continue
        redirected = False
        prev_dir = 0
        for i in range(1, len(ss)):
            dx = ss[i][1] - ss[i - 1][1]
            d = 1 if dx > 0 else (-1 if dx < 0 else 0)
            if d != 0 and prev_dir != 0 and d != prev_dir:
                rc = (ss[i - 1][1], ss[i - 1][2])   # 반전이 일어난 셀
                if any(max(abs(rc[0] - bc[0]), abs(rc[1] - bc[1])) <= adj for bc in bcells):
                    redirected = True
                    break
            if d != 0:
                prev_dir = d
        if not redirected:
            continue
        d_start = _goal_dist_at(ss[0], layout)
        d_best = min(_goal_dist_at(s, layout) for s in ss)
        total += max(0.0, float(d_start - d_best))
    return total


def count_retired(trace: dict, layout: dict) -> dict:
    """리타이어한 개미를 **원인별로 구별**해 카운트. 회수 실패하고 죽은 개미만(저장·생존 제외):
      water = 물 익사 — 마지막 샘플이 hazard 위/안(_died_water). **낙하 중 드리프트로 바닥을 놓치고
              물에 빠지는 S14 패턴도 below-hazard로 잡힌다**(개미는 착지하지 않으므로 stun 미발생).
      fall  = **낙하피해(stun death)**: 궤적에 'dead'(DeadState) 상태 샘플이 있음 = 실제 기절사. 트레이스
              상태(D10)를 쓰므로 **큰 낙하를 생존한 개미(walk로 이어짐)는 카운트하지 않는다**(거짓양성 제거).
    반환 {"water":w, "fall":f, "total":w+f}. (물 먼저 분류; dead 상태는 fall.)
    **생존자 미카운트 핵심**: 예전 `_max_fall_run>=5` 휴리스틱은 낙하를 살아남고 계속 걷는 개미를 낙하사로
    오판해 score를 오염(하강 기피)시켰다. 실제 종단 상태/익사 위치로 대체."""
    home = layout.get("home")
    water = fall = 0
    for si in sorted({int(k) for k in trace.keys()}) if trace else []:
        ss = _samples(trace, si)
        if not ss:
            continue
        cx, cy = ss[-1][1], ss[-1][2]
        ended_home = home is not None and abs(cx - home[0]) <= 1 and abs(cy - home[1]) <= 1
        if ended_home:
            continue                                       # 귀가(저장) — 리타이어 아님
        if _died_water(ss, layout):
            water += 1
        elif any((len(s) > 4 and s[4] == "dead") for s in ss):
            fall += 1
    return {"water": water, "fall": fall, "total": water + fall}


def best_goal_dist(trace: dict, layout: dict) -> int:
    """궤적에서 **목표까지의 최소 접근**(셀 맨해튼) — 방향 무관 진척 신호. 개미별:
      픽업한 적 있으면 목표=home(귀환 거리), 아니면 목표=candy(접근 거리). 전 개미 중 최소.
    best_min_y(항상 '위로' 보상)를 대체 — candy가 아래(S14)면 하강을, 위(S11/S12)면 상승을 보상한다."""
    candy = layout.get("candy")
    home = layout.get("home")
    best = 1 << 30
    for si in sorted({int(k) for k in trace.keys()}) if trace else []:
        ss = _samples(trace, si)
        if not ss:
            continue
        carried = any(s[3] == 1 for s in ss)
        if carried and home is not None:
            for s in ss:
                if s[3] == 1:
                    best = min(best, abs(s[1] - home[0]) + abs(s[2] - home[1]))
        elif candy is not None:
            for s in ss:
                best = min(best, abs(s[1] - candy[0]) + abs(s[2] - candy[1]))
    return best


def frontier(trace: dict) -> int:
    """트레이스 전 개미 **visited cell `{(cx,cy)}` 합집합 크기** = 탐험 프론티어(Phase 5g Phase B 전용 bounded
    tie-break 신호). 결정론·좌표 비의존. ⚠ *전역 품질 metric이 아니다* — 왕복/루프도 frontier를 키울 수 있어
    해의 품질 판정이 아닌 *탐색 순서* heuristic으로만 쓴다(품질=엔진 verdict). Phase A는 이 함수를 호출하지 않는다."""
    cells: set[tuple[int, int]] = set()
    for si in sorted({int(k) for k in trace.keys()}) if trace else []:
        for s in _samples(trace, si):
            cells.add((s[1], s[2]))
    return len(cells)


def _skills_by_routing(inventory: dict, metas: dict) -> dict[str, list[str]]:
    """인벤토리 스킬을 routing별로 그룹(메타 기반, 하드코딩 0)."""
    out: dict[str, list[str]] = {}
    for sid in inventory:
        meta = metas.get(sid) or {}
        r = str(meta.get("routing", ""))
        if r:
            out.setdefault(r, []).append(sid)
    for r in out:
        out[r].sort()
    return out


def _band(cs: int, row: int) -> tuple[float, float]:
    # 트레이스 cy = body_cell row(= floor((y-2)/cs)) → 개미는 그 아래 발판(row+1) 위에 서 있다(픽셀
    # y ≈ [cy*cs, (cy+1)*cs)). 그 보행 개미를 확실히 포함하도록 넉넉히(위 surface 개미는 안 걸리게 +2칸까지).
    return (row * cs - 8.0, (row + 2) * cs + 8.0)


def _has_early_arm(plan, sid: str) -> bool:
    """plan에 이 스킬(sid)의 **early 무장**(select=spawn_index + trigger immediate) 액션이 이미 채택돼
    있는가. early 체인(상행 climber)의 게이트 — carry 체인의 상행판이다(아래 propose ② 참조). 채택된 적
    없으면(기존 모든 스테이지: early 무장을 끝내 채택 안 하거나[carry로 풀림] 첫 early 후보서 즉시 클리어)
    False → 종전 후보 집합·순서와 byte-identical. plan=None(기본)이면 False."""
    if not plan:
        return False
    for a in plan:
        if a.get("skill") != sid:
            continue
        if (a.get("trigger") or {}).get("type") != "immediate":
            continue
        if (a.get("target") or {}).get("select") == "spawn_index":
            return True
    return False


def _has_ceiling(occ: set, col: int, row: int) -> bool:
    """blocker 셀 (col,row) **상공**(같은 열, 더 위 행)에 solid 타일(천장)이 있는가.
    있으면 = 위층 개미가 그 열로 직접 낙하할 수 없다 → 그 자리 반전 blocker는 위층 낙하 개미와 **재충돌하지
    않는다**(사용자 통찰, stage17 실측: L2 col17[천장 無]→재충돌 무한왕복 saved 0, col≤16[맨위 플랫폼이
    천장]→saved 5/5). 천장 없는(상공 뻥 뚫린) 가장자리 셀에 두면 위층 낙하 개미가 착지 즉시 재충돌한다.
    최상층(상공에 아무 층도 없음)도 False지만, 그쪽은 애초에 낙하 원본 층이 없어 무해 — reverse target
    가중이 알아서 처리한다(천장 보너스는 동순위 타이브레이커)."""
    return any((col, r) in occ for r in range(row - 1, -1, -1))


def _cellup_cols(cellup_base, metas: dict) -> set:
    """base plan(또는 accepted actions)에서 이미 배치된 **cell-up 사다리의 col 집합**(T1 같은-col 회피용,
    plan-review R2). cell-up = meta.target==cell && routing==up(현 sand_mound). down/break cell 디바이스는 제외."""
    cols: set = set()
    for a in (cellup_base or []):
        m = metas.get(a.get("skill")) or {}
        t = a.get("target") or {}
        if str(m.get("target")) == "cell" and str(m.get("routing")) == "up" and t.get("mode") == "cell":
            c = t.get("cell")
            if isinstance(c, (list, tuple)) and len(c) == 2:
                cols.add(int(c[0]))
    return cols


def propose(layout: dict, diag: dict, inventory: dict, metas: dict,
            notes: dict, exclude: set, max_n: int, plan: list | None = None,
            cellup_base: list | None = None) -> list[dict]:
    """다음 개입 후보를 랭킹 반환. 각 후보 = {"action": v1액션, "label": str}.
    우선순위: ① 물 진입을 막는 반전(blocker 등 routing=reverse) — 가장 흔한 치명적 실패.
              ② 픽업했으나 귀환 부족 → 무장 up(climber 등)으로 귀로 확보(타이밍: 회수 완료 후).
              ③ 상승 벽-반전 → cell-up 사다리(sand_mound, routing=up·target=cell) 설치.
    notes(스테이지 비고)는 우선순위 가중만(비구속).
    plan = 현재 누적 plan(없으면 None) — early 체인(상행 climber) 게이트 `_has_early_arm`에만 쓴다.
    cellup_base = ③ cell-up 같은-col 회피(T1)의 *speculative* 기준 plan(LA2의 base2 포함, plan-review R3-H1).
                  None이면 같은-col 필터 미적용(첫 라운드/단독 호출). early-chain closure(plan)와 직교."""
    cs = layout["cell_size"]
    by_r = _skills_by_routing(inventory, metas)
    cands: list[dict] = []
    # 천장 선호(사용자 통찰): 반전 blocker는 **상공에 천장(solid)이 있는 셀**에 두어야 위층에서 낙하한
    # 개미가 그 위로 떨어지지 못해 착지 재충돌이 없다. 천장 없는 가장자리 셀(상공 뻥 뚫림)에 두면 위층 낙하
    # 개미가 착지 즉시 반전돼 무한 왕복한다(stage17 실측). 같은 backpath 후보들 중 천장 있는 안쪽을 가중한다.
    occ: set = layout["occupied"]

    # ① 낙하 차단(반전) + ①' 방어 대응(safe_fall) — 둘 다 **동선 backpath**를 따라 후보를 낸다.
    # 낙하 가장자리에서 개미를 반전(reverse)하거나 안전낙하(safe_fall) 시킨다. **off=0,1,2는 좌표(x-off)가
    # 아니라 backpath의 grounded 타일을 거슬러**(사용자 통찰) — 공중 낙하 타일을 건너뛰어 실제 보행 타일에
    # 정확히 놓이고, 거슬러 갈수록 발화 여유(lead time)가 커진다. 물 익사 가장자리가 reverse_targets 앞쪽
    # (물 우선 정렬)이라 _w 가중도 그쪽이 높다. select/cmp는 가장자리에서의 진행 방향으로 결정.
    sel_cmp = {1: ("max_x", "ge"), -1: ("min_x", "le")}
    n_tgt = len(diag["reverse_targets"])
    for routing in ("reverse", "safe_fall", "cross"):
        for sid in by_r.get(routing, []):
            for ti, tgt in enumerate(diag["reverse_targets"]):
                d = tgt["dir"]
                sel, cmp = sel_cmp[1 if d > 0 else -1]
                bp: list = tgt["backpath"] or [tgt["cell"]]
                water_w = 4 if tgt["to_water"] else 0       # 물 익사 가장자리 우선 가중
                tgt_w = (n_tgt - ti)                        # reverse_targets 정렬 순위 가중(물·깊이)
                for off in range(min(3, len(bp))):
                    col, row = bp[off]
                    y_min, y_max = _band(cs, row)
                    label = "%s@%d,%d:%s%s" % (sid, col, row, sel, cmp)
                    ceil = _has_ceiling(occ, col, row)
                    # 천장 있는(재충돌 안전) reverse 후보는 exclude(tried) **면제** — plan 맥락이 바뀌면(다른
                    # blocker와 조합) 재평가돼야 한다. 한 단계에서 단독 기각된 천장 blocker가 다른 blocker와
                    # 함께라야 진척하는 상호의존(stage17: 16,6은 8,3과 함께라야 saved 5/5)을 greedy/LA가
                    # 놓치지 않게 한다. 천장 없는 후보는 exclude 유지(폭증 방지). 중복 롤아웃은 eval_cands
                    # action-dup 가드(이미 plan에 든 액션 skip)가 막는다 — carry 연쇄와 동일 패턴.
                    if label in exclude and not ceil:
                        continue
                    action = {"skill": sid,
                              "target": {"mode": "ant", "select": sel, "y_min": y_min, "y_max": y_max},
                              "trigger": {"type": "ant_reaches_x", "cmp": cmp, "x": (col + 0.5) * cs}}
                    ceil_w = 4 if ceil else 0                            # 천장 있는 셀 선호(낙하 재충돌 회피, 사용자 통찰)
                    cands.append({"action": action, "label": label, "_class": routing,
                                  "_w": _note_w(notes, sid) * 8 + water_w + tgt_w + (2 - off) + ceil_w})

    # ② 무장 up(climber 등) — 세 타이밍·타깃을 후보로 내고 엔진이 고른다(사용자 통찰):
    #   early(스폰 직후 개미별 무장): S13처럼 일찍 줘도 무방하고 늦으면 시간초과인 경우.
    #   carry(픽업 후 운반 개미 무장): **S14 귀환 핵심** — 운반 개미가 벽에서 climb로 귀가(바닥→벽→상단→
    #     home). select=min_x+state=carrying = 가장 왼쪽(벽 근처) 운반 개미부터 단계별로 무장. picked_ge n
    #     로 n번째 픽업 시점에 발화 → 5조각이면 carry1..5가 서로 다른 개미에 분배(무장 개미는 climb로 빠짐).
    #   late(회수 완료 후 max_x 무장): 일반 상승 보조.
    # 귀로 단계(전 사탕 회수됨)면 climber를 최우선으로(귀환 확보), 아니면 후순위(상승은 blocker 우선).
    cnt = diag["candy_hp"]
    return_phase = diag["picked_total"] >= cnt > 0
    base = 100 if return_phase else 1
    # carry 가중 기준(픽업 발생 시만 운반 무장 제안). early-armed 가중도 이 위에 얹는다(carry-mirror).
    carry_base = (220 if return_phase else 40) if diag["picked_total"] > 0 else 0
    ant_n = diag.get("ant_count", 0)
    # early 체인 가중 = **carry 프로파일 바로 위**(carry-mirror, 사용자 결정 2026-06-25). carry no-op보다 먼저
    # 평가돼 체인이 cap 내 완결되되, carry-chain과 **동형 가중 프로파일**이라 구조 후보와의 관계가 검증된
    # carry-chain과 동일(새 starvation 클래스 없음 = R1~R4 보존 메커니즘 폐기). carry_base=0(픽업 전, 드묾)이면
    # 40 floor로 구조 위 유지.
    early_w_base = (carry_base if carry_base > 0 else 40) + cnt
    for sid in by_r.get("up", []):
        if str((metas.get(sid) or {}).get("category", "")) != "ANT_ARMED":
            continue   # 무장형만(설치형 up=sand_mound는 cell 대상, ① 경로)
        # early 체인(사용자 통찰, stage20 "이상한 계단" = 다단 상승 + 물 갭). 각 개미가 **픽업 전(상행)** 에
        # 벽을 타야 candy에 닿는 레벨에선 climber를 spawn_index 전반으로 체이닝해야 한다 — carry 체인(②
        # 아래, 운반=하행 귀환)의 **상행판**. 한 early 무장이 이미 plan에 채택돼 진척을 냈으면(early_armed),
        # 나머지 spawn_index 무장은 ⓐ exclude(tried) **면제**(plan 맥락이 바뀌었으니 재평가) + ⓑ carry-mirror
        # 가중(early_w_base, carry no-op 바로 위)으로 si0→…→si(n-1) 연쇄 채택된다. 이미 채택된
        # early의 중복 롤아웃은 solve.eval_cands action-dup 가드가 차단(carry와 동일 패턴). early_armed가 False
        # (기존 모든 스테이지)면 종전 후보 집합·순서와 byte-identical.
        early_armed = _has_early_arm(plan, sid)
        for si in range(ant_n):                        # early: 개미별 즉시 무장
            label = "%s@early:si%d" % (sid, si)
            if label in exclude and not early_armed:
                continue
            action = {"skill": sid, "target": {"mode": "ant", "select": "spawn_index", "spawn_index": si},
                      "trigger": {"type": "immediate"}}
            w = (early_w_base + (ant_n - si)) if early_armed else (base + _note_w(notes, sid))
            cands.append({"action": action, "label": label, "_class": "up_armed", "_w": w})
        # carry: 픽업이 하나라도 발생했으면(picked_total>0) 운반 개미 귀환 무장을 제안. 귀로 단계면 최우선.
        # carry(운반 개미 무장)는 exclude(tried) 면제 — plan 누적 시 재평가돼야 carry1→2→…→n 연쇄 채택이
        # 된다(사용자 통찰: carry가 tried로 막히면 early/afterpick으로 흩어져 *비운반* 개미에 climber가 가고,
        # 그 개미는 candy 미도달·등반 무한루프가 된다). 이미 채택된 carry의 중복 롤아웃은 solve.eval_cands의
        # action-dup 가드가 차단하므로 면제해도 폭주하지 않는다.
        for n in range(1, cnt + 1):
            label = "%s@carry%d" % (sid, n)
            if carry_base <= 0:
                continue
            action = {"skill": sid, "target": {"mode": "ant", "select": "min_x", "state": "carrying"},
                      "trigger": {"type": "picked_ge", "n": n}}
            cands.append({"action": action, "label": label, "_class": "up_armed",
                          "_w": carry_base + (cnt - n) + _note_w(notes, sid)})
        for n in range(1, cnt + 1):                      # late: 회수 완료 후 max_x 무장
            label = "%s@afterpick%d" % (sid, n)
            if label in exclude:
                continue
            action = {"skill": sid, "target": {"mode": "ant", "select": "max_x"},
                      "trigger": {"type": "picked_ge", "n": n}}
            cands.append({"action": action, "label": label, "_class": "up_armed",
                          "_w": base - 1 + _note_w(notes, sid)})

    # ③ SIGN cell-up (sand_mound 등 meta.target==cell && routing==up) — 상승 벽-반전(wall_targets)에 사다리 설치.
    # **후보 column-sweep(A안)**: 단일 반전-셀이 아니라 진입측 backpath off=0..K를 펼쳐, 엔진 verdict가 배치 위상
    # (T1 다른-col / T2 우향 / T3 off≥1)을 만족하는 조합을 선별한다(plan-review R2). off=0(벽 붙음)은 (T3) 위반이라
    # 단독 실패하나, 실패 후 검색이 off≥1을 이어 평가해 witness(S19: col10=off5)에 닿는다. inert: target==cell &&
    # routing==up 스킬이 인벤토리에 없으면 루프 미진입 → 후보 byte-identical.
    cellup_cols = _cellup_cols(cellup_base, metas)       # 이미 깐 사다리 col(LA2 base 포함, T1 같은-col 회피, R3-H1)
    wts = diag.get("wall_targets", [])
    # 5e D1: 목표-위 fall-edge(reverse_targets 중 goal_above)도 cell-up 소스로 편입 — 운반 개미가 추락하는 *절벽*
    # 위에도 사다리를 세워 목표 경로를 확보한다(S22 귀환 절벽). wall(전방 solid)과 fall-edge(전방 비-solid·추락)는
    # **배타**라 셀 중복 없음(seen_cells가 한 번 더 보장). 목표-위 게이트: wall은 _wall_targets에서 이미, fall-edge는
    # goal_above로(목표-아래 전용 가장자리는 fall_up에서 빠짐 → 미emit). 수집 상한 N: wall=6(R3-M1), fall=4(reverse
    # backpath cap). inert: cell-up 스킬 없으면 루프 미진입, fall_up 비면 fall 소스 무발화(byte-identical).
    fall_up = [t for t in diag.get("reverse_targets", []) if t.get("goal_above")]
    for sid in sorted(inventory):
        meta = metas.get(sid) or {}
        if str(meta.get("target")) != "cell" or str(meta.get("routing")) != "up":
            continue
        seen_cells: set = set()                           # 좌·우 벽 + fall/wall이 같은 backpath 셀을 양쪽서 내는
        for src_order, (src_list, n_cap, risk_kind) in enumerate(((wts, 6, "wall"), (fall_up, 4, "fall"))):
            for ti, tgt in enumerate(src_list):           # 중복 차단(첫 발견 가중 유지). src_order·ti = diagnose 우선순위.
                # fall은 **목표-위 phase backpath**(backpath_above, codex impl R1 HIGH — stale 픽업전 동선 회피),
                # wall은 wall_targets backpath. fall_up은 goal_above=True만이라 backpath_above 존재(fallback 안전).
                bp = (tgt.get("backpath_above") if risk_kind == "fall" else tgt.get("backpath")) or [tgt["cell"]]
                tgt_w = len(src_list) - ti                # 소스 내 정렬 순위(목표 근접) 가중
                tcol, trow = tgt["cell"]
                for off in range(min(n_cap, len(bp))):    # wall off=0..5 / fall off=0..3 (R3-M1: reverse cap 비재사용)
                    col, row = bp[off]
                    if col in cellup_cols:                # T1: 같은-col 재스택 배제(speculative base 기준, R3-H1)
                        continue
                    if (col, row) in seen_cells:          # 동일 셀 중복 emit 방지(좌·우 벽·fall/wall 교집합)
                        continue
                    seen_cells.add((col, row))
                    label = "%s@cell:%d,%d" % (sid, col, row)
                    if label in exclude:
                        continue
                    action = {"skill": sid, "target": {"mode": "cell", "cell": [col, row]},
                              "trigger": {"type": "at_frame", "frame": 0}}
                    # off **큰 쪽 선호**(+off): ladder1을 벽/가장자리에서 멀리(접근로 안쪽) 놓아야 climb 후 목표
                    # 방향 다음 사다리(T2) 공간이 남는다. off=0(붙음)은 T3 dead-end라 후순위. tgt_w 1급, off 2급.
                    # D2(5e): off는 _w 내부 선호일 뿐 — burial 시 `_class_prefix_protect`가 off 전부를 평가 보장.
                    cands.append({"action": action, "label": label, "_class": "up_cell",
                                  "_off": off, "_src_rank": (src_order, ti), "_risk": (risk_kind, tcol, trow),
                                  "_w": _note_w(notes, sid) * 8 + tgt_w * 8 + off})

    cands.sort(key=lambda c: -c["_w"])
    return _class_prefix_protect(cands, max_n)


def _class_prefix_protect(cands: list[dict], max_n: int) -> list[dict]:
    """5e D2 — 리스크별 intervention-class *evaluated-prefix* 보장(burial 해소, plan §"5e 계약" D2).
    한 라운드에 `up_cell`(cell-up 사다리)이 *다른 class*(carry-arm 등 `up_armed`, bridge `cross` …)와 경쟁할
    때, cell-up은 _w(≈10)가 carry-arm(_w≈220)에 눌려 top-`max_n` 절단에서 밀려 **롤아웃조차 안 되던** cross-
    routing burial이 있었다(S22 de-risk 실측). 여기서 up_cell 프리픽스(backpath off 전부)를 절단 밖이면 **보호**해,
    어느 routing이 그 리스크를 푸는지를 _w가 아니라 엔진 verdict가 결정하게 한다.
    **bounded extra quota = max_n**(codex impl R2 [HIGH]): 보호 extra를 **최대 max_n개**로 제한해 반환 길이 ≤
    2·max_n(무제한 append → per-round 롤аут budget 잠식 금지). 첫 max_n 슬롯은 종전 _w 순(carry-arm/cross 등
    non-cell 후보 보존 → LA2/non-cell starvation 없음).
    **risk별 라운드-로빈 인터리브**(codex impl R3·R4 [HIGH]): bounded quota를 risk(_src_rank)별 그룹으로 공평
    분배 — raw (src_order, ti) global 순서면 wall off0..5가 quota를 독점해 fall witness가 starve(R4 cross-source).
    src_rank 순 그룹의 off↑ 프리픽스를 라운드-로빈으로 뽑아 고우선순위 risk 먼저이되(R3) cross-source 공평(R4).
    단일 risk(S22 fall 1개)면 1 그룹 → off↑ 순차(동일). many-risk·cap 초과는 정직 bounded(cap은 시퀀스 깊이로).
    정직 inert:
      - up_cell이 *유일* class(S19=sand_mound only)면 절단이 곧 그 class의 _w 순 → 보호 항등 → byte-identical.
      - up_cell *없는* multi-class(S13/14/20 = reverse+up_armed)면 보호 대상 부재(extra=[]) → 무영향 → byte-identical.
      - up_cell + 다른 class(S22 = cross/up_armed/up_cell)일 때만 발동. 절단(len(cands)>max_n)이 없으면 무발동."""
    out = cands[:max_n]
    classes = {c.get("_class") for c in cands if c.get("_class")}
    if "up_cell" not in classes or len(classes) <= 1 or len(cands) <= max_n:
        return out
    in_out = {id(c) for c in out}
    extra = [c for c in cands if c.get("_class") == "up_cell" and id(c) not in in_out]
    # **risk별 라운드-로빈 인터리브**(codex impl R3·R4 [HIGH]): bounded quota를 risk(`_src_rank=(src_order, ti)` =
    # propose 순회 diagnose 정렬: wall src_order=0/fall=1, ti=source 내 water·freq·목표근접 순위)별 그룹으로 묶어
    # **공평 분배**. raw (src_order, ti) global 순서로 자르면 wall off0..5가 quota를 독점해 fall-edge witness가 완전
    # starve된다(R4: wall+fall 공존 시 D1 burial 재발). src_rank 순 그룹의 off↑ 프리픽스를 라운드-로빈으로 max_n까지
    # 뽑아 — 고우선순위 risk가 먼저이되(R3) 어느 source도 다른 source를 완전 굶기지 않는다(R4 cross-source 공평).
    extra.sort(key=lambda c: (c.get("_src_rank", (9, 9)), c.get("_off", 0)))   # src_rank 순(고우선순위 먼저) + off↑
    groups: list = []                                  # risk별 그룹(src_rank order 유지, 내부 off↑)
    for c in extra:
        sr = c.get("_src_rank", (9, 9))
        if groups and groups[-1][0] == sr:
            groups[-1][1].append(c)
        else:
            groups.append((sr, [c]))
    glists = [g[1] for g in groups]
    picked: list = []                                  # bounded ≤ max_n, risk 그룹 라운드-로빈(cross-source 공평)
    while len(picked) < max_n and any(glists):
        for grp in glists:
            if grp:
                picked.append(grp.pop(0))
                if len(picked) >= max_n:
                    break
    return out + picked                                # 반환 ≤ 2·max_n (codex R2 bounded)


def _note_w(notes: dict, sid: str) -> int:
    """스테이지 비고에 이 스킬 언급이 있으면 우선순위 가중(비구속 힌트)."""
    if notes and sid in notes:
        return 1
    return 0


def _selfcheck_wall_targets() -> bool:
    """`wall_targets` 검출 + cell-up 후보 emit의 **fail-closed 단위 검증**(plan-review R1·R3 박제, 엔진 불요).
    ⓐ right-wall ⓑ left-wall ⓒ two-wall valley(둘 다 검출·목표근접 정렬) ⓓ 허공 반전(전방 비-solid → 미검출)
    ⓔ 목표-아래(미검출) + **R3-M1**: S19형 우측벽 wall_target이 backpath ≥6 보유 + `propose`가 off=5 후보
    (10,14)를 실제 emit(reverse depth-4 cap 비재사용 prove-it). 반환 True=PASS / False=FAIL(상세 출력)."""
    def _L(occupied, candy=None, home=None):
        return {"cell_size": 48, "occupied": set(occupied), "ladder": set(), "kinds": {},
                "hazard": {}, "candy": candy, "home": home}
    def _tr(*paths):                               # 각 path=[(col,row),...] → 한 개미 trace(has_candy=0)
        return {str(si): [[i, c, r, 0] for i, (c, r) in enumerate(p)] for si, p in enumerate(paths)}

    # ⓐ right-wall: 바닥 row11 cols0..4, 벽 col5, candy 위(3,5). 개미 우향→(4,10)서 반전(전방 (5,10) solid).
    occ_a = {(c, 11) for c in range(0, 5)} | {(5, 10), (5, 11)}
    wt_a = diagnose(_tr([(0, 10), (1, 10), (2, 10), (3, 10), (4, 10), (3, 10), (2, 10)]),
                    _L(occ_a, candy=(3, 5)), 1)["wall_targets"]
    if not any(t["cell"] == (4, 10) and t["dir"] == 1 for t in wt_a):
        print("[wall_targets selfcheck] FAIL ⓐ right-wall 미검출:", wt_a); return False
    # ⓓ 허공 반전: 같은 바닥인데 전방 (5,10) **비-solid**(벽 없음) → 미검출. (절벽이라 실제론 추락이나 검출만 검사.)
    occ_d = {(c, 11) for c in range(0, 6)}         # row11 floor cols0..5, row10 전부 빔
    wt_d = diagnose(_tr([(2, 10), (3, 10), (4, 10), (3, 10), (2, 10)]),
                    _L(occ_d, candy=(3, 5)), 1)["wall_targets"]
    if any(t["cell"] == (4, 10) for t in wt_d):
        print("[wall_targets selfcheck] FAIL ⓓ 허공 반전 오검출:", wt_d); return False
    # ⓔ 목표-아래: ⓐ와 동일 지형인데 candy가 아래(3,15) → 상승 무익 → 미검출.
    wt_e = diagnose(_tr([(0, 10), (1, 10), (2, 10), (3, 10), (4, 10), (3, 10), (2, 10)]),
                    _L(occ_a, candy=(3, 15)), 1)["wall_targets"]
    if wt_e:
        print("[wall_targets selfcheck] FAIL ⓔ 목표-아래 오검출:", wt_e); return False
    # ⓕ **per-sample 목표(codex impl-review HIGH) — has_candy 0→1 플립 트레이스**: 개미가 **픽업 전(hc=0)** 우측
    # 벽서 반전(candy 위), 그 *후* 픽업(hc=1). home은 아래(0,15). per-sample 목표면 이 반전 시점 hc=0 → goal=candy
    # (위) → 검출. any()-picked 단일화 버그면 트레이스에 hc=1 샘플이 있어 goal=home(아래) → 게이트 reject로 **누락**
    # = FAIL. 즉 이 케이스가 버그를 falsify한다(vacuous 아님). 샘플=[t,col,row,has_candy].
    occ_f = {(c, 11) for c in range(0, 9)} | {(9, 10), (9, 11)}
    tr_f = {"0": [[0, 0, 10, 0], [1, 1, 10, 0], [2, 2, 10, 0], [3, 3, 10, 0], [4, 4, 10, 0],
                  [5, 5, 10, 0], [6, 6, 10, 0], [7, 7, 10, 0], [8, 8, 10, 0],     # 픽업 전 우향 접근 → (8,10) 반전
                  [9, 7, 10, 0], [10, 6, 10, 1], [11, 5, 10, 1]]}                 # 반전 후 픽업(hc 0→1 플립)
    wt_f = diagnose(tr_f, _L(occ_f, candy=(10, 5), home=(0, 15)), 1)["wall_targets"]
    if not any(t["cell"] == (8, 10) and t["dir"] == 1 for t in wt_f):
        print("[wall_targets selfcheck] FAIL ⓕ 픽업-전 접근 벽 누락(per-sample 목표 회귀, any()-bug):", wt_f); return False
    # ⓑ left-wall + ⓒ two-wall valley: 바닥 row11 cols2..6, 벽 col1·col7. candy 우상(8,5). 개미 좌우 왕복.
    occ_c = {(c, 11) for c in range(2, 7)} | {(1, 10), (1, 11), (7, 10), (7, 11)}
    wt_c = diagnose(_tr([(6, 10), (5, 10), (4, 10), (3, 10), (2, 10), (3, 10), (4, 10), (5, 10), (6, 10), (5, 10)]),
                    _L(occ_c, candy=(8, 5)), 1)["wall_targets"]
    has_left = any(t["cell"] == (2, 10) and t["dir"] == -1 for t in wt_c)
    has_right = any(t["cell"] == (6, 10) and t["dir"] == 1 for t in wt_c)
    if not (has_left and has_right):
        print("[wall_targets selfcheck] FAIL ⓑ/ⓒ two-wall 미검출(left=%s right=%s):" % (has_left, has_right), wt_c); return False
    if wt_c[0]["cell"] != (6, 10):                 # 목표(col8) 근접 = 우측벽(col6) 먼저
        print("[wall_targets selfcheck] FAIL ⓒ 목표근접 정렬(우측 우선) 위반:", [t["cell"] for t in wt_c]); return False
    # ⓖ **중복 pre/post-pick 벽 키(codex impl-review R2-HIGH)**: 같은 벽 (5,10,+1)을 픽업 전(hc=0, goal=candy(10,5))
    # 과 후(hc=1, goal=home(8,5))에 둘 다 반전. phase가 키에 없으면 나중 것이 count만 증가·stale gx로 병합 → 정렬
    # 오염. phase별 별도 레코드면 **두 target**이 각자 gx로: home(|5-8|=3) target이 candy(|5-10|=5)보다 앞.
    occ_g = {(c, 11) for c in range(2, 6)} | {(6, 10), (6, 11)}
    tr_g = {"0": [[0, 2, 10, 0], [1, 3, 10, 0], [2, 4, 10, 0], [3, 5, 10, 0], [4, 4, 10, 0],   # pre-pick 반전 (5,10)
                  [5, 4, 10, 1], [6, 5, 10, 1], [7, 4, 10, 1]]}                                 # post-pick 반전 (5,10)
    wt_g = diagnose(tr_g, _L(occ_g, candy=(10, 5), home=(8, 5)), 1)["wall_targets"]
    g_at = [t for t in wt_g if t["cell"] == (5, 10) and t["dir"] == 1]
    if len(g_at) != 2:                             # phase별 2 target(구 (col,row,d_in) 병합이면 1·count=2 = FAIL)
        print("[wall_targets selfcheck] FAIL ⓖ pre/post-pick 벽이 phase별 2 target 아님(stale 병합):", wt_g); return False
    # ⓗ **비연속 backpath(codex impl-review R2-MED)**: 직전 grounded 샘플이 far-jump(루프)면 접근 세그먼트 종단.
    # 개미가 (3,10)→(4,10)→(5,10) 직전에 far cell (0,10)을 거쳐옴 → backpath는 (5,10)(4,10)(3,10)만, (0,10) 배제.
    occ_h = {(c, 11) for c in range(0, 6)} | {(6, 10), (6, 11)}
    tr_h = {"0": [[0, 0, 10, 0], [1, 3, 10, 0], [2, 4, 10, 0], [3, 5, 10, 0], [4, 4, 10, 0]]}
    diag_h = diagnose(tr_h, _L(occ_h, candy=(10, 5)), 1)
    bp_h = next((t["backpath"] for t in diag_h["wall_targets"] if t["cell"] == (5, 10)), [])
    if (0, 10) in bp_h or len(bp_h) != 3:
        print("[wall_targets selfcheck] FAIL ⓗ 비연속 backpath stale 셀 미배제:", bp_h); return False
    cands_h = propose(_L(occ_h, candy=(10, 5)), diag_h, {"sand_mound": 2},
                      {"sand_mound": {"target": "cell", "routing": "up"}}, {}, set(), max_n=40)
    if any(c["action"]["target"].get("cell") == [0, 10] for c in cands_h):
        print("[wall_targets selfcheck] FAIL ⓗ off-preference가 접근로 밖 (0,10) 선택:", [c["label"] for c in cands_h if "cell" in c["label"]]); return False
    # R3-M1: S19형 valley(바닥 row14 cols5..15, 벽 col16). 우측벽 (15,14) backpath≥6 + propose off=5 (10,14) emit.
    occ_s = {(c, 15) for c in range(5, 16)} | {(16, 14), (16, 15)}
    diag_s = diagnose(_tr([(c, 14) for c in range(5, 16)] + [(c, 14) for c in range(14, 4, -1)]),
                      _L(occ_s, candy=(16, 6)), 5)
    rw = next((t for t in diag_s["wall_targets"] if t["cell"] == (15, 14) and t["dir"] == 1), None)
    if rw is None or len(rw["backpath"]) < 6:
        print("[wall_targets selfcheck] FAIL R3-M1 우측벽 backpath<6:", rw); return False
    metas_s = {"sand_mound": {"target": "cell", "routing": "up", "category": "SIGN"}}
    L_s = _L(occ_s, candy=(16, 6))
    cands_s = propose(L_s, diag_s, {"sand_mound": 2}, metas_s, {}, set(), max_n=40)
    if not any(c["action"]["target"].get("cell") == [10, 14] for c in cands_s):
        print("[wall_targets selfcheck] FAIL R3-M1 off=5 witness (10,14) 미emit:",
              [c["label"] for c in cands_s if "cell" in c["label"]]); return False
    # R3-H1: T1 같은-col 회피가 **speculative base**(LA2 base2 = plan+[첫 sand_mound])에 적용되는지 prove-it.
    # solve._propose가 `cellup_base=base`(LA2는 base2)로 전달하므로 이 propose-레벨 필터가 곧 LA2 메커니즘이다.
    base_first = [{"skill": "sand_mound", "target": {"mode": "cell", "cell": [10, 14]},
                   "trigger": {"type": "at_frame", "frame": 0}}]
    cands_h1 = propose(L_s, diag_s, {"sand_mound": 2}, metas_s, {}, set(), max_n=40, cellup_base=base_first)
    h1_cols = {c["action"]["target"]["cell"][0] for c in cands_h1 if c["action"]["target"].get("mode") == "cell"}
    if 10 in h1_cols:
        print("[wall_targets selfcheck] FAIL R3-H1 speculative base col10 미배제(같은-col 재스택 가능):", sorted(h1_cols)); return False
    # ===== 5e D1: 목표-위 *fall-edge*(절벽 추락 가장자리)도 cell-up 후보 소스 — wall(전방 solid)과 배타 =====
    # ⓘ 목표-위(운반→home 위): 운반 개미(hc=1)가 row7 플랫폼(cols8..11) 좌단 (8,6)서 col7 절벽으로 추락(전방
    #    (7,6) 비-solid). home(0,2) 위 → goal_above=True → propose가 fall-edge backpath에 cell-up(sand_mound) emit.
    occ_i = {(c, 7) for c in range(8, 12)}             # row7 플랫폼 cols8..11(전방 col7 비어=절벽)
    tr_i = {"0": [[0, 11, 6, 1], [1, 10, 6, 1], [2, 9, 6, 1], [3, 8, 6, 1], [4, 7, 6, 1]]}   # 운반 좌향 → (8,6) 추락
    L_i = _L(occ_i, candy=(11, 2), home=(0, 2))
    diag_i = diagnose(tr_i, L_i, 1)
    fe_i = next((t for t in diag_i["reverse_targets"] if t["cell"] == (8, 6) and t["dir"] == -1), None)
    if fe_i is None or not fe_i.get("goal_above"):
        print("[wall_targets selfcheck] FAIL ⓘ 목표-위 fall-edge goal_above 미설정:", diag_i["reverse_targets"]); return False
    if diag_i["wall_targets"]:                          # soundness: 전방 비-solid라 wall_targets와 배타(누출 0)
        print("[wall_targets selfcheck] FAIL ⓘ fall-edge가 wall_targets로 누출(전방 비-solid인데 벽 검출):", diag_i["wall_targets"]); return False
    cands_i = propose(L_i, diag_i, {"sand_mound": 2}, metas_s, {}, set(), max_n=40)
    if not any(c["action"]["target"].get("cell") == [10, 6] for c in cands_i):
        print("[wall_targets selfcheck] FAIL ⓘ 목표-위 fall-edge cell-up (10,6) 미emit:",
              [c["label"] for c in cands_i if "cell" in c["label"]]); return False
    # ⓙ 목표-아래(미픽업→candy 아래): 같은 절벽이나 candy(11,12)가 *아래* → goal_above=False → cell-up 미emit.
    tr_j = {"0": [[0, 11, 6, 0], [1, 10, 6, 0], [2, 9, 6, 0], [3, 8, 6, 0], [4, 7, 6, 0]]}   # 미픽업 좌향 추락
    L_j = _L(occ_i, candy=(11, 12), home=(0, 12))
    diag_j = diagnose(tr_j, L_j, 1)
    fe_j = next((t for t in diag_j["reverse_targets"] if t["cell"] == (8, 6)), None)
    if fe_j is None or fe_j.get("goal_above"):
        print("[wall_targets selfcheck] FAIL ⓙ 목표-아래 fall-edge goal_above 오설정:", diag_j["reverse_targets"]); return False
    cands_j = propose(L_j, diag_j, {"sand_mound": 2}, metas_s, {}, set(), max_n=40)
    if any("cell" in c["label"] for c in cands_j):
        print("[wall_targets selfcheck] FAIL ⓙ 목표-아래 fall-edge가 cell-up emit:",
              [c["label"] for c in cands_j if "cell" in c["label"]]); return False
    # ⓚ codex impl R1 [HIGH]: 같은 fall edge를 픽업 전(goal_above=false, **긴 동선 A**)과 운반(goal_above=true,
    #    **짧은 동선 B**)이 통과 → goal_above OR=true이나 cell-up backpath는 *운반 동선 B*서 와야(첫 발견 A가 아니라).
    #    A 사용=stale phase merge → A 전용 셀 (10,6)·(11,6) emit = FAIL(prove-it: backpath_above 없으면 A 사용).
    occ_k = {(c, 7) for c in range(8, 12)}             # row7 플랫폼 cols8..11(전방 col7 절벽)
    tr_k = {"0": [[0, 11, 6, 0], [1, 10, 6, 0], [2, 9, 6, 0], [3, 8, 6, 0], [4, 7, 6, 0]],   # 미픽업 A(4셀 동선)
            "1": [[0, 9, 6, 1], [1, 8, 6, 1], [2, 7, 6, 1]]}                                  # 운반 B(2셀 동선)
    L_k = _L(occ_k, candy=(11, 12), home=(0, 2))       # candy 아래(픽업전 goal_above=false) / home 위(운반 true)
    diag_k = diagnose(tr_k, L_k, 1)
    fe_k = next((t for t in diag_k["reverse_targets"] if t["cell"] == (8, 6) and t["dir"] == -1), None)
    if fe_k is None or not fe_k.get("goal_above"):
        print("[wall_targets selfcheck] FAIL ⓚ goal_above 미설정(OR 집계):", diag_k["reverse_targets"]); return False
    cands_k = propose(L_k, diag_k, {"sand_mound": 2}, metas_s, {}, set(), max_n=40)
    k_cells = {tuple(c["action"]["target"]["cell"]) for c in cands_k if c["action"]["target"].get("mode") == "cell"}
    if (10, 6) in k_cells or (11, 6) in k_cells:       # A 전용 셀 = stale 픽업전 backpath 사용(운반 B 동선 밖) = FAIL
        print("[wall_targets selfcheck] FAIL ⓚ cell-up이 stale 픽업전 backpath A 사용(운반 B 밖 셀 emit):",
              sorted(k_cells)); return False
    if (8, 6) not in k_cells or (9, 6) not in k_cells:  # 운반 동선 B 셀은 emit돼야(목표-위 phase backpath)
        print("[wall_targets selfcheck] FAIL ⓚ 운반 backpath B 셀 미emit:", sorted(k_cells)); return False
    # ===== 5e D2 witness-rolled prove-it: burial 해소 보호가 intra-class 랭킹 가정에 안 기댐 =====
    # carry-arm(up_armed _w≈220)이 top-max_n 독점할 때, up_cell 프리픽스(off 전부)가 절단 밖이어도 보호돼
    # witness off=2가 반환에 포함되는가. 현 +off _w면 top=off3만 보장돼 off2 누락 = burial. 합성 cands prove-it.
    fake_armed = [{"action": {"skill": "slideR", "k": i}, "label": "armed%d" % i, "_class": "up_armed",
                   "_w": 220 - i} for i in range(6)]
    fake_cells = [{"action": {"skill": "sand_mound", "target": {"mode": "cell", "cell": [off, 6]}},
                   "label": "cell%d" % off, "_class": "up_cell", "_off": off, "_risk": ("fall", 8, 6),
                   "_w": 8 + off} for off in range(4)]      # _w=8+off → off3 최고(=naive 절단이 보장하는 유일 후보)
    merged = sorted(fake_armed + fake_cells, key=lambda c: -c["_w"])
    protected = _class_prefix_protect(merged, 6)
    if len(protected) > 12:                            # codex impl R2 [HIGH]: bounded extra(≤2·max_n), 무제한 append 금지
        print("[wall_targets selfcheck] FAIL D2 보호 cap 초과(무제한 append, budget 잠식):", len(protected)); return False
    if not any(c.get("_off") == 2 and c.get("_class") == "up_cell" for c in protected):
        print("[wall_targets selfcheck] FAIL D2 보호가 witness off=2 미포함(burial 미해소):",
              [c["label"] for c in protected]); return False
    if sum(1 for c in protected[:6] if c.get("_class") == "up_armed") < 1:   # codex R2: non-cell starvation 방지
        print("[wall_targets selfcheck] FAIL D2 non-cell(armed) starvation(첫 max_n 슬롯에 없음):",
              [c["label"] for c in protected[:6]]); return False
    if any(c.get("_class") == "up_cell" for c in merged[:6]):   # prove-it: naive 절단엔 burial(up_cell 0개)
        print("[wall_targets selfcheck] FAIL D2 prove-it vacuous(naive 절단에 up_cell 존재 = burial 미재현)"); return False
    # codex R2: **many up_cell risks** → extra bounded(≤max_n, 무제한 append 금지) + armed 첫 max_n 슬롯 전부 보존
    # (LA2/non-cell starvation 없음). up_cell 10개라도 반환 ≤ 2·max_n, armed 6개 보존.
    many_cells = [{"action": {"skill": "sand_mound", "target": {"mode": "cell", "cell": [off, 6]}},
                   "label": "mc%d" % off, "_class": "up_cell", "_off": off, "_risk": ("fall", off, 6),
                   "_w": 1 + off} for off in range(10)]
    prot2 = _class_prefix_protect(sorted(fake_armed + many_cells, key=lambda c: -c["_w"]), 6)
    if len(prot2) > 12:
        print("[wall_targets selfcheck] FAIL D2 many-risk 무제한 append(extra>max_n):", len(prot2)); return False
    if sum(1 for c in prot2 if c.get("_class") == "up_armed") < 6:   # armed 6개(첫 max_n) 전부 보존 = starvation 없음
        print("[wall_targets selfcheck] FAIL D2 many-risk armed starvation:", [c.get("label") for c in prot2]); return False
    # codex R3 [HIGH]: bounded quota가 **diagnose 우선순위(source rank)** 보존 — 좌표순이면 저우선순위 risk(작은
    # col)가 quota 독점해 고우선순위 risk winning off 누락. riskA(src_rank ti=0, col 큼=좌표상 후순위)의 off2가
    # riskB(ti=1, col 작음=좌표상 선순위)에 안 밀리고 생존. (좌표순 정렬이면 riskA off2 누락 = FAIL = prove-it.)
    riskA = [{"action": {"skill": "sand_mound", "target": {"mode": "cell", "cell": [20 + off, 6]}},
              "label": "A%d" % off, "_class": "up_cell", "_off": off, "_src_rank": (1, 0),
              "_risk": ("fall", 20 + off, 6), "_w": 8 + off} for off in range(4)]
    riskB = [{"action": {"skill": "sand_mound", "target": {"mode": "cell", "cell": [off, 6]}},
              "label": "B%d" % off, "_class": "up_cell", "_off": off, "_src_rank": (1, 1),
              "_risk": ("fall", off, 6), "_w": 8 + off} for off in range(4)]
    prot3 = _class_prefix_protect(sorted(fake_armed + riskA + riskB, key=lambda c: -c["_w"]), 6)
    if not any(c.get("_src_rank") == (1, 0) and c.get("_off") == 2 for c in prot3):  # 고우선순위 riskA off2 생존
        print("[wall_targets selfcheck] FAIL D2 source-priority: 고우선순위 risk off2가 bounded quota서 누락(좌표순 독점):",
              [c["label"] for c in prot3]); return False
    # codex R4 [HIGH]: **cross-source(wall+fall) 공평** — wall off0..5가 quota 독점해 fall-edge witness starve 금지.
    # wall (0,0) off0..5 + fall (1,0) off0..3, max_n=6 → risk 라운드-로빈으로 fall off2 생존(raw src_order global 순
    # 이면 wall 6개가 quota 독점·fall 0개 = D1 burial 재발 = FAIL = prove-it).
    wall_c = [{"action": {"skill": "sand_mound", "target": {"mode": "cell", "cell": [30 + off, 6]}},
               "label": "W%d" % off, "_class": "up_cell", "_off": off, "_src_rank": (0, 0),
               "_risk": ("wall", 30 + off, 6), "_w": 8 + off} for off in range(6)]
    fall_c = [{"action": {"skill": "sand_mound", "target": {"mode": "cell", "cell": [off, 6]}},
               "label": "F%d" % off, "_class": "up_cell", "_off": off, "_src_rank": (1, 0),
               "_risk": ("fall", off, 6), "_w": 8 + off} for off in range(4)]
    prot4 = _class_prefix_protect(sorted(fake_armed + wall_c + fall_c, key=lambda c: -c["_w"]), 6)
    if not any(c.get("_src_rank") == (1, 0) and c.get("_off") == 2 for c in prot4):  # fall witness off2 생존(starve X)
        print("[wall_targets selfcheck] FAIL D2 cross-source: wall이 bounded quota 독점·fall witness off2 starve:",
              [c["label"] for c in prot4]); return False
    # inert: up_cell이 유일 class면 보호 항등(S19). 단순 절단과 동일해야 byte-identical.
    only_cells = sorted(fake_cells, key=lambda c: -c["_w"])
    if _class_prefix_protect(only_cells, 2) != only_cells[:2]:
        print("[wall_targets selfcheck] FAIL D2 inert(유일 up_cell class인데 보호가 절단을 바꿈):"); return False
    print("[wall_targets selfcheck] PASS — ⓐ-ⓚ 검출/방향/정렬/per-sample목표/phase별키/연속backpath/목표-위fall-edge"
          "/cell-up backpath_above(stale 픽업전 회피) + R3-M1 off=5 + R3-H1 same-col + D2 burial-protect witness off=2 "
          "(bounded ≤2·max_n·non-cell starvation 없음·many-risk bounded·source-priority 보존·cross-source 공평·inert 항등).")
    return True
