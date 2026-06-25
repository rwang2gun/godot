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
from pathlib import Path


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
            # 동선 backpath: 이 가장자리 샘플 i에서 뒤로 가며 **grounded 타일만** 수집(공중 낙하 건너뜀).
            # 첫 원소 = 가장자리 셀 자신(off=0), 이후 = 거슬러 간 보행 타일(off=1,2,...). 같은 (col,row)
            # 연속 중복은 제외(셀 변화 단위). 첫 발견 시에만 기록(가장 이른 통과 동선).
            if key not in edge_back:
                bp: list = []
                for j in range(i, -1, -1):
                    s = ss[j]
                    if not supported(s[1], s[2]):
                        continue
                    cell = (s[1], s[2])
                    if bp and bp[-1] == cell:
                        continue
                    bp.append(cell)
                    if len(bp) >= 4:
                        break
                edge_back[key] = bp
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
                        "to_water": bool(edge_water.get(k)), "count": fall_edges[k]} for k in keys]
    return {
        "picked_total": picked_ants,
        "reverse_targets": reverse_targets,
        "fall_edges": keys,                  # legacy(좌표 키 리스트)
        "near_candy": near_candy,
        "candy_hp": candy_hp,
        "ant_count": len(ant_ids),
    }


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


def propose(layout: dict, diag: dict, inventory: dict, metas: dict,
            notes: dict, exclude: set, max_n: int, plan: list | None = None) -> list[dict]:
    """다음 개입 후보를 랭킹 반환. 각 후보 = {"action": v1액션, "label": str}.
    우선순위: ① 물 진입을 막는 반전(blocker 등 routing=reverse) — 가장 흔한 치명적 실패.
              ② 픽업했으나 귀환 부족 → 무장 up(climber 등)으로 귀로 확보(타이밍: 회수 완료 후).
    notes(스테이지 비고)는 우선순위 가중만(비구속).
    plan = 현재 누적 plan(없으면 None) — early 체인(상행 climber) 게이트 `_has_early_arm`에만 쓴다."""
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
                    cands.append({"action": action, "label": label,
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
    ant_n = diag.get("ant_count", 0)
    early_active = False               # early 체인 boost가 한 sid라도 켜졌는가(아래 구조-후보 보존 게이트)
    for sid in by_r.get("up", []):
        if str((metas.get(sid) or {}).get("category", "")) != "ANT_ARMED":
            continue   # 무장형만(설치형 up=sand_mound는 cell 대상, ① 경로)
        # early 체인(사용자 통찰, stage20 "이상한 계단" = 다단 상승 + 물 갭). 각 개미가 **픽업 전(상행)** 에
        # 벽을 타야 candy에 닿는 레벨에선 climber를 spawn_index 전반으로 체이닝해야 한다 — carry 체인(②
        # 아래, 운반=하행 귀환)의 **상행판**. 한 early 무장이 이미 plan에 채택돼 진척을 냈으면(early_armed),
        # 나머지 spawn_index 무장은 ⓐ exclude(tried) **면제**(plan 맥락이 바뀌었으니 재평가) + ⓑ 가중 부스트
        # (carry처럼 연쇄가 다른 후보보다 먼저 평가돼 cap 내 완결)로 si0→…→si(n-1) 연쇄 채택된다. 이미 채택된
        # early의 중복 롤아웃은 solve.eval_cands action-dup 가드가 차단(carry와 동일 패턴). early_armed가 False
        # (기존 모든 스테이지)면 종전 후보 집합·순서와 byte-identical.
        early_armed = _has_early_arm(plan, sid)
        early_active = early_active or early_armed
        for si in range(ant_n):                        # early: 개미별 즉시 무장
            label = "%s@early:si%d" % (sid, si)
            if label in exclude and not early_armed:
                continue
            action = {"skill": sid, "target": {"mode": "ant", "select": "spawn_index", "spawn_index": si},
                      "trigger": {"type": "immediate"}}
            w = (210 + (ant_n - si)) if early_armed else (base + _note_w(notes, sid))
            cands.append({"action": action, "label": label, "_w": w})
        # carry: 픽업이 하나라도 발생했으면(picked_total>0) 운반 개미 귀환 무장을 제안. 귀로 단계면 최우선.
        carry_base = (220 if return_phase else 40) if diag["picked_total"] > 0 else 0
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
            cands.append({"action": action, "label": label, "_w": carry_base + (cnt - n) + _note_w(notes, sid)})
        for n in range(1, cnt + 1):                      # late: 회수 완료 후 max_x 무장
            label = "%s@afterpick%d" % (sid, n)
            if label in exclude:
                continue
            action = {"skill": sid, "target": {"mode": "ant", "select": "max_x"},
                      "trigger": {"type": "picked_ge", "n": n}}
            cands.append({"action": action, "label": label, "_w": base - 1 + _note_w(notes, sid)})

    cands.sort(key=lambda c: -c["_w"])
    if not early_active:
        return cands[:max_n]                       # 기존 모든 스테이지: early_active=False → byte-identical
    # codex impl-review HIGH: early_armed 부스트(210+)가 `cands[:max_n]` 절단에서 **구조 후보**(reverse/
    # safe_fall/cross = 다리·블로커 배치, trigger=ant_reaches_x)를 굶기면 structure→early→structure 다단
    # 레벨이 막힌다(boost가 max_n을 early로 채워 구조 진척을 못 봄). **최상위 구조 후보 1개를 절단에서 항상
    # 보존**해 매 라운드 구조 후보가 평가되게 보장 → 필요한 구조가 있으면 그 라운드(또는 LA2 frontier)에서
    # 발견·채택된다. early 체인은 나머지 슬롯으로 계속 진행(보존 1칸 비용만). early_active=False면 미적용.
    # codex impl-review R2 HIGH: 보존 슬롯이 *이미 시도된(tried)* 구조 후보 — 특히 ceiling-exempt라 재제안되는
    # 비개선 천장 후보 — 에 독점되면 차하위 *필요* 구조가 여전히 굶는다. 보존 대상 = **아직 안 써본(untried)
    # 최상위 구조 후보**로 한정 → 시도돼 실패한 구조는 다음 라운드 보존에서 빠지고(tried=exclude), fresh 구조가
    # 슬롯을 받는다. untried 구조가 없으면(전부 시도됨) 보존 안 함(새로 평가할 fresh 구조 없음 = 헛 롤아웃 방지).
    top_struct = next((c for c in cands
                       if (c["action"].get("trigger") or {}).get("type") == "ant_reaches_x"
                       and c["label"] not in exclude), None)
    if top_struct is None or top_struct in cands[:max_n]:
        return cands[:max_n]                       # untried 구조 없음 or 이미 head에 포함 → 절단 그대로
    return [top_struct] + [c for c in cands if c is not top_struct][:max_n - 1]


def _note_w(notes: dict, sid: str) -> int:
    """스테이지 비고에 이 스킬 언급이 있으면 우선순위 가중(비구속 힌트)."""
    if notes and sid in notes:
        return 1
    return 0


def _selfcheck_preserve() -> tuple[bool, str]:
    """codex impl-review R2 회귀 단위 검증(엔진 불요) — early_active 시 구조-후보 보존 슬롯이 *tried* 후보
    (ceiling-exempt라 재제안되는 비개선 천장 후보)에 독점되지 않고 **untried 최상위 구조**를 보존하는지
    propose 후보 랭킹을 직접 단언. 시나리오: 구조 후보 A=(10,5) 천장有·물·고가중 / B=(3,5) 천장無·저가중,
    early 체인 활성(plan에 climber early arm) → 둘 다 early boost로 절단될 가중. (1) A untried → 보존=A.
    (2) A tried(exclude) → 보존=B(A 독점 차단, R2 fix). R1 동작이면 (2)에서 A가 나와 FAIL → 회귀 박제."""
    metas = {"blocker": {"routing": "reverse", "category": "ANT_ARMED"},
             "climber": {"routing": "up", "category": "ANT_ARMED"}}
    inventory = {"blocker": 2, "climber": 5}
    layout = {"cell_size": 48, "occupied": {(10, 2)}, "candy": (10, 1), "home": (1, 9), "hazard": {}}
    diag = {"candy_hp": 5, "picked_total": 1, "ant_count": 5,
            "near_candy": {"dist": 1 << 30, "cell": None, "dir": 0},
            "reverse_targets": [
                {"cell": (10, 5), "dir": 1, "backpath": [(10, 5)], "to_water": True, "count": 2},   # A 고가중·천장
                {"cell": (3, 5), "dir": 1, "backpath": [(3, 5)], "to_water": False, "count": 1},    # B 저가중·무천장
            ]}
    early_plan = [{"skill": "climber", "target": {"mode": "ant", "select": "spawn_index", "spawn_index": 3},
                   "trigger": {"type": "immediate"}}]   # early_active=True
    a_label, b_label = "blocker@10,5:max_xge", "blocker@3,5:max_xge"
    r1 = propose(layout, diag, inventory, metas, notes={}, exclude=set(), max_n=6, plan=early_plan)
    if not r1 or r1[0]["label"] != a_label:
        return False, "A untried인데 보존 선두가 A 아님: %s" % (r1[0]["label"] if r1 else None)
    r2 = propose(layout, diag, inventory, metas, notes={}, exclude={a_label}, max_n=6, plan=early_plan)
    if not r2 or r2[0]["label"] != b_label:
        return False, "A tried인데 보존 선두가 B(untried) 아님(독점 미차단): %s" % (r2[0]["label"] if r2 else None)
    return True, "preserve OK (A untried→A, A tried→B)"
