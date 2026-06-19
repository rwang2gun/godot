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


def diagnose(trace: dict, layout: dict, candy_hp: int) -> dict:
    """관측 궤적에서 실패를 진단. 반환:
      picked_total, fall_edges(낙하 직전 발판 가장자리+방향), near_candy(미픽업 개미의 candy 최근접).
    **낙하 가장자리** = 개미가 발판을 벗어나 아래로 떨어진(물이든 하위 표면이든) 지점. 개미는 막히기 전엔
    방향을 안 바꾸므로, 그 가장자리 직전 x에 벽(blocker)을 놓으면 반전한다 — 반전이 개미를 사다리/candy
    쪽으로 돌려보내 (a) 물·추락사 회피 (b) 상승 라우팅(반대편 사다리로 유도)을 동시에 해결한다."""
    candy = layout["candy"]
    occ = layout["occupied"]
    def supported(cx: int, cy: int) -> bool:
        return (cx, cy + 1) in occ            # 바로 아래 셀이 solid = 발판에 받쳐짐

    fall_edges: dict[tuple, int] = {}       # (col,row,dir) → count
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
        # 낙하 가장자리: '받쳐진 셀(cur)'에서 '안 받쳐진 셀(nxt)'로 내려가거나 수평 진입(= 발판 끝을 밟고
        # 허공/물로 나감). cur가 막을 지점. 등반(cy 감소)은 제외. 개미는 막기 전엔 안 도므로 cur 직전
        # x에서 벽을 세우면 반전 → 물·추락 회피 + 반대편 사다리로 상승 유도.
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
    # 빈도 desc, 그다음 하위 표면(cy 큰 것) 먼저 — 스폰 레벨의 낙하부터 고친다.
    edges = sorted(fall_edges.keys(), key=lambda k: (-fall_edges[k], -k[1]))
    return {
        "picked_total": picked_ants,
        "fall_edges": edges,
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


# 낙하피해(기절사) 임계 — 게임 Ant.STUN_FALL_CELLS=5칸. floater면 면역(트레이스론 구분 불가 → 근사).
FALL_STUN_CELLS = 5


def _max_fall_run(ss: list) -> int:
    """궤적 내 최대 연속 수직 낙하 칸수(같은 cx, cy 연속 +1)."""
    best = 0
    i, n = 0, len(ss)
    while i < n - 1:
        if ss[i + 1][1] == ss[i][1] and ss[i + 1][2] == ss[i][2] + 1:
            run, k = 1, i + 1
            while k + 1 < n and ss[k + 1][1] == ss[k][1] and ss[k + 1][2] == ss[k][2] + 1:
                k += 1
                run += 1
            best = max(best, run)
            i = k
        else:
            i += 1
    return best


def count_retired(trace: dict, layout: dict) -> dict:
    """리타이어한 개미를 **원인별로 구별**해 카운트. 회수 실패하고 죽은 개미만(저장·생존 제외):
      water = 물/끈끈이(hazard) 또는 발판 x-범위 밖(맵 이탈해 빠짐)에서 종료.
      fall  = **낙하피해(stun death)**: FALL_STUN_CELLS(5)칸 이상 연속 낙하 + 집 미도달, 물 아님(S14 전멸).
    반환 {"water":w, "fall":f, "total":w+f}. (물 먼저 분류 → 물에 빠진 낙하는 water로 셈.)"""
    hazard = layout["hazard"]
    occ = layout["occupied"]
    home = layout.get("home")
    if occ:
        xs = [c for (c, _r) in occ]
        xmin, xmax = min(xs) - 2, max(xs) + 2
    else:
        xmin, xmax = -(1 << 30), (1 << 30)
    water = fall = 0
    for si in sorted({int(k) for k in trace.keys()}) if trace else []:
        ss = _samples(trace, si)
        if not ss:
            continue
        cx, cy = ss[-1][1], ss[-1][2]
        ended_home = home is not None and abs(cx - home[0]) <= 1 and abs(cy - home[1]) <= 1
        if (cx, cy) in hazard or cx < xmin or cx > xmax:
            water += 1
        elif not ended_home and _max_fall_run(ss) >= FALL_STUN_CELLS:
            fall += 1
    return {"water": water, "fall": fall, "total": water + fall}


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


def propose(layout: dict, diag: dict, inventory: dict, metas: dict,
            notes: dict, exclude: set, max_n: int) -> list[dict]:
    """다음 개입 후보를 랭킹 반환. 각 후보 = {"action": v1액션, "label": str}.
    우선순위: ① 물 진입을 막는 반전(blocker 등 routing=reverse) — 가장 흔한 치명적 실패.
              ② 픽업했으나 귀환 부족 → 무장 up(climber 등)으로 귀로 확보(타이밍: 회수 완료 후).
    notes(스테이지 비고)는 우선순위 가중만(비구속)."""
    cs = layout["cell_size"]
    by_r = _skills_by_routing(inventory, metas)
    cands: list[dict] = []

    # ① 낙하 차단(반전) — 낙하 가장자리 직전 x에서 개미 반전(물·추락 회피 + 사다리 쪽 상승 유도).
    # **x 변형**(off=0,1,2칸): 반전점을 가장자리에서 한두 칸 당겨 **하강 낙하 컬럼을 비운다**(carrying
    # 귀환 개미가 그 블로커에 막혀 무한루프 빠지는 것 회피, 사용자 S12 통찰). 엔진이 갇힘 없이 saved
    # 최대인 변형을 고른다.
    sel_cmp = {1: ("max_x", "ge"), -1: ("min_x", "le")}
    for sid in by_r.get("reverse", []):
        for (pcx, pcy, d) in diag["fall_edges"]:
            sel, cmp = sel_cmp[1 if d > 0 else -1]
            y_min, y_max = _band(cs, pcy)
            for off in (0, 1, 2):
                col = pcx - d * off
                label = "%s@r%d:%s%s%d" % (sid, pcy, sel, cmp, col)
                if label in exclude:
                    continue
                action = {"skill": sid,
                          "target": {"mode": "ant", "select": sel, "y_min": y_min, "y_max": y_max},
                          "trigger": {"type": "ant_reaches_x", "cmp": cmp, "x": (col + 0.5) * cs}}
                cands.append({"action": action, "label": label, "_w": _note_w(notes, sid) * 4 + (2 - off)})

    # ①' 방어 대응(floater 등 routing=safe_fall) — 낙하 가장자리에 정착자를 두어 지나는 개미가 **안전
    # 낙하**(낙하사 회피). 반전과 달리 개미를 *살려서 아래로* 보낸다(candy가 아래 있고 floater 보유 시 핵심).
    # blocker와 같은 select+ant_reaches_x. **대응 지점 한두 타일 전(off)** 에서 발화해 여유 확보(사용자:
    # -2타일 필요 — 정확히 가장자리면 타이밍이 늦어 현실적 클리어 불가).
    for sid in by_r.get("safe_fall", []):
        for (pcx, pcy, d) in diag["fall_edges"]:
            sel, cmp = sel_cmp[1 if d > 0 else -1]
            y_min, y_max = _band(cs, pcy)
            for off in (0, 1, 2):
                col = pcx - d * off
                label = "%s@r%d:%s%s%d" % (sid, pcy, sel, cmp, col)
                if label in exclude:
                    continue
                action = {"skill": sid,
                          "target": {"mode": "ant", "select": sel, "y_min": y_min, "y_max": y_max},
                          "trigger": {"type": "ant_reaches_x", "cmp": cmp, "x": (col + 0.5) * cs}}
                cands.append({"action": action, "label": label, "_w": _note_w(notes, sid) * 4 + (2 - off)})

    # ② 무장 up(climber 등) — 타이밍 두 가지 모두 후보로 내고 엔진이 고른다(사용자 통찰):
    #   early(스폰 직후 개미별 무장): S13처럼 일찍 줘도 무방하고 늦으면 시간초과인 경우.
    #   late(회수 완료 picked_ge 후): S14처럼 일찍이면 벽에서 반전 대신 등반→무한루프인 경우.
    # 귀로 단계(전 사탕 회수됨)면 climber를 최우선으로(귀환 확보), 아니면 후순위(상승은 blocker 우선).
    cnt = diag["candy_hp"]
    return_phase = diag["picked_total"] >= cnt > 0
    base = 100 if return_phase else 1
    for sid in by_r.get("up", []):
        if str((metas.get(sid) or {}).get("category", "")) != "ANT_ARMED":
            continue   # 무장형만(설치형 up=sand_mound는 cell 대상, ① 경로)
        for si in range(diag.get("ant_count", 0)):     # early: 개미별 즉시 무장
            label = "%s@early:si%d" % (sid, si)
            if label in exclude:
                continue
            action = {"skill": sid, "target": {"mode": "ant", "select": "spawn_index", "spawn_index": si},
                      "trigger": {"type": "immediate"}}
            cands.append({"action": action, "label": label, "_w": base + _note_w(notes, sid)})
        for n in range(1, cnt + 1):                      # late: 회수 완료 후 무장
            label = "%s@afterpick%d" % (sid, n)
            if label in exclude:
                continue
            action = {"skill": sid, "target": {"mode": "ant", "select": "max_x"},
                      "trigger": {"type": "picked_ge", "n": n}}
            cands.append({"action": action, "label": label, "_w": base - 1 + _note_w(notes, sid)})

    cands.sort(key=lambda c: -c["_w"])
    return cands[:max_n]


def _note_w(notes: dict, sid: str) -> int:
    """스테이지 비고에 이 스킬 언급이 있으면 우선순위 가중(비구속 힌트)."""
    if notes and sid in notes:
        return 1
    return 0
