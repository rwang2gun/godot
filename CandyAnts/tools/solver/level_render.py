#!/usr/bin/env python3
"""level_render — StageLayoutData(.tres)를 파싱해 레벨을 SVG로 그린다.

지형(solid/plant/cookie/sand_mound/…), 위험(water/sticky), 집·사탕·개미 시작점을
격자 그림으로 렌더링하고, 해(solution)의 각 액션을 그 위에 오버레이한다:
  - cell 타깃 스킬  → 해당 칸에 번호 핀
  - ant 타깃 스킬   → 트리거 x 위치에 세로선 + y-밴드 하이라이트
  - analysis.json 이 있으면 실제 발동 픽셀 좌표(target_pos)에 점을 찍는다.

found_viewer.py 가 import 해서 카드마다 SVG를 심는 데 쓴다.
"""
from __future__ import annotations

import re
from pathlib import Path

CELL = 48  # px per cell (StageLayoutData.cell_size, 전 스테이지 고정)

# 타일/위험 종류별 색 (채움, 테두리)
TILE_COLORS = {
    "solid":       ("#6b4a2f", "#4d3420"),
    "ground":      ("#7a5334", "#573a24"),
    "plant":       ("#3f7d3a", "#2c5a29"),
    "plant_solid": ("#356b30", "#244a20"),
    "cookie":      ("#d9a441", "#a97c2c"),
    "sand_mound":  ("#cdae6b", "#a68a4e"),
    "background":  ("#241c14", "#241c14"),
}
HAZARD_COLORS = {
    "water":  ("#2f6fd8", "#5a94ec"),
    "sticky": ("#8a7a2f", "#b3a04a"),
}
# 스킬별 오버레이 색
SKILL_COLOR = {
    "blocker": "#ff5d5d", "climber": "#5db4ff", "floater": "#b98cff",
    "bridge": "#ffb454", "slideR": "#5ee0a0", "slideL": "#5ee0a0",
    "basher": "#ff8a3d", "cutter": "#ff6fae", "leaf_jump": "#8ce05e",
    "sand_mound": "#e0c05e", "digger": "#c98a5a",
}


def _find_block(text: str, key: str) -> str | None:
    """`key = { ... }` 블록의 중괄호 안 내용을 반환."""
    m = re.search(rf"{re.escape(key)}\s*=\s*{{", text)
    if not m:
        return None
    i = m.end()
    depth = 1
    start = i
    while i < len(text) and depth:
        c = text[i]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        i += 1
    return text[start:i - 1]


def _parse_cell_map(block: str) -> dict[tuple[int, int], str]:
    out: dict[tuple[int, int], str] = {}
    for cx, cy, kind in re.findall(r'"(-?\d+),(-?\d+)"\s*:\s*"([a-z_]+)"', block):
        out[(int(cx), int(cy))] = kind
    return out


def _parse_vec2i(text: str, key: str) -> tuple[int, int] | None:
    m = re.search(rf"{re.escape(key)}\s*=\s*Vector2i\((-?\d+),\s*(-?\d+)\)", text)
    return (int(m.group(1)), int(m.group(2))) if m else None


def parse_layout(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    cs_m = re.search(r"cell_size\s*=\s*(\d+)", text)
    tile_block = _find_block(text, "tile_map") or ""
    haz_block = _find_block(text, "hazard_map") or ""
    return {
        "cell_size": int(cs_m.group(1)) if cs_m else CELL,
        "tiles": _parse_cell_map(tile_block),
        "hazards": _parse_cell_map(haz_block),
        "home_cell": _parse_vec2i(text, "home_cell"),
        "candy_cell": _parse_vec2i(text, "candy_cell"),
    }


def parse_spawn(tscn_path: Path) -> tuple[float, float] | None:
    """.tscn 의 Spawner 노드 spawn_position(Vector2) 픽셀 좌표."""
    if not tscn_path.exists():
        return None
    text = tscn_path.read_text(encoding="utf-8")
    m = re.search(r'name="Spawner".*?spawn_position\s*=\s*Vector2\(([-\d.]+),\s*([-\d.]+)\)',
                  text, re.DOTALL)
    return (float(m.group(1)), float(m.group(2))) if m else None


def _esc(s) -> str:
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def render_svg(layout: dict, actions: list[dict], spawn=None,
               resolved: list | None = None) -> str:
    """레벨 + 액션 오버레이 SVG 문자열."""
    cs = layout["cell_size"]
    tiles = layout["tiles"]
    hazards = layout["hazards"]

    # 경계 계산 (모든 셀 + 마커 + 액션 x)
    xs, ys = [], []
    for (cx, cy) in list(tiles) + list(hazards):
        xs += [cx, cx + 1]; ys += [cy, cy + 1]
    for mk in (layout["home_cell"], layout["candy_cell"]):
        if mk:
            xs += [mk[0], mk[0] + 1]; ys += [mk[1], mk[1] + 1]
    if not xs:
        xs, ys = [0, 10], [0, 10]
    min_cx, max_cx = min(xs), max(xs)
    min_cy, max_cy = min(ys), max(ys)
    # 픽셀 경계 (트리거 x / spawn 포함)
    x0, x1 = min_cx * cs, max_cx * cs
    y0, y1 = min_cy * cs, max_cy * cs
    for a in actions:
        tr = a.get("trigger", {})
        if tr.get("type") == "ant_reaches_x" and "x" in tr:
            x0 = min(x0, tr["x"]); x1 = max(x1, tr["x"])
    if spawn:
        x0 = min(x0, spawn[0]); x1 = max(x1, spawn[0])
        y0 = min(y0, spawn[1]); y1 = max(y1, spawn[1])
    pad = cs
    vb_x, vb_y = x0 - pad, y0 - pad
    vb_w, vb_h = (x1 - x0) + 2 * pad, (y1 - y0) + 2 * pad

    p = [f'<svg viewBox="{vb_x:.0f} {vb_y:.0f} {vb_w:.0f} {vb_h:.0f}" '
         f'class="level" preserveAspectRatio="xMidYMid meet" '
         f'xmlns="http://www.w3.org/2000/svg">']
    p.append(f'<rect x="{vb_x:.0f}" y="{vb_y:.0f}" width="{vb_w:.0f}" height="{vb_h:.0f}" fill="#0d2340"/>')

    # 배경 타일 먼저, 그 위 지형
    def draw_cells(cells, colormap, faint=False):
        for (cx, cy), kind in sorted(cells.items()):
            fill, stroke = colormap.get(kind, ("#555", "#333"))
            op = ' opacity="0.5"' if faint else ""
            p.append(f'<rect x="{cx*cs}" y="{cy*cs}" width="{cs}" height="{cs}" '
                     f'fill="{fill}" stroke="{stroke}" stroke-width="1.5"{op}/>')

    bg = {k: v for k, v in tiles.items() if v == "background"}
    solid = {k: v for k, v in tiles.items() if v != "background"}
    draw_cells(bg, TILE_COLORS, faint=True)
    draw_cells(hazards, HAZARD_COLORS)
    draw_cells(solid, TILE_COLORS)

    def cell_center(mk):
        return (mk[0] * cs + cs / 2, mk[1] * cs + cs / 2)

    # 집 · 사탕 · 시작점 마커
    if layout["candy_cell"]:
        cxp, cyp = cell_center(layout["candy_cell"])
        p.append(f'<circle cx="{cxp:.0f}" cy="{cyp:.0f}" r="{cs*0.38:.0f}" fill="#ff5aa8" stroke="#fff" stroke-width="2"/>')
        p.append(f'<text x="{cxp:.0f}" y="{cyp+cs*0.7:.0f}" class="mk">사탕</text>')
    if layout["home_cell"]:
        cxp, cyp = cell_center(layout["home_cell"])
        p.append(f'<rect x="{cxp-cs*0.34:.0f}" y="{cyp-cs*0.34:.0f}" width="{cs*0.68:.0f}" height="{cs*0.68:.0f}" rx="4" fill="#5ee08a" stroke="#fff" stroke-width="2"/>')
        p.append(f'<text x="{cxp:.0f}" y="{cyp+cs*0.7:.0f}" class="mk">집</text>')
    if spawn:
        sx, sy = spawn
        p.append(f'<path d="M {sx:.0f} {sy-cs*0.34:.0f} L {sx+cs*0.32:.0f} {sy+cs*0.28:.0f} L {sx-cs*0.32:.0f} {sy+cs*0.28:.0f} Z" fill="#ffcf5a" stroke="#fff" stroke-width="2"/>')
        p.append(f'<text x="{sx:.0f}" y="{sy+cs*0.8:.0f}" class="mk">시작</text>')

    # 액션 오버레이
    resolved = resolved or []
    undrawn: list[str] = []  # 공간 좌표가 없어 그리지 못한 액션 (예: picked_ge 트리거)
    for i, a in enumerate(actions, 1):
        skill = a.get("skill", "")
        col = SKILL_COLOR.get(skill, "#ffffff")
        tgt = a.get("target", {})
        tr = a.get("trigger", {})
        # 실제 발동 픽셀(analysis) 우선
        rpos = None
        if i - 1 < len(resolved):
            rpos = resolved[i - 1]

        if tgt.get("mode") == "cell" and tgt.get("cell"):
            cx, cy = tgt["cell"]
            px, py = cx * cs + cs / 2, cy * cs + cs / 2
            p.append(f'<rect x="{cx*cs:.0f}" y="{cy*cs:.0f}" width="{cs}" height="{cs}" fill="none" stroke="{col}" stroke-width="3"/>')
            p.append(f'<circle cx="{px:.0f}" cy="{py:.0f}" r="11" fill="{col}" stroke="#000" stroke-width="1.5"/>')
            p.append(f'<text x="{px:.0f}" y="{py+4:.0f}" class="pin">{i}</text>')
            p.append(f'<text x="{px:.0f}" y="{cy*cs-6:.0f}" class="alab" fill="{col}">{_esc(skill)}</text>')
        else:
            # ant 타깃: 트리거 x 세로선 + y밴드
            x = tr.get("x") if tr.get("type") == "ant_reaches_x" else None
            if rpos:
                x = rpos[0]
            if x is not None:
                y_lo = tgt.get("y_min", vb_y)
                y_hi = tgt.get("y_max", vb_y + vb_h)
                p.append(f'<line x1="{x:.0f}" y1="{vb_y:.0f}" x2="{x:.0f}" y2="{vb_y+vb_h:.0f}" stroke="{col}" stroke-width="2" stroke-dasharray="6 4" opacity="0.85"/>')
                if tgt.get("y_min") is not None:
                    p.append(f'<rect x="{x-cs*0.5:.0f}" y="{y_lo:.0f}" width="{cs}" height="{y_hi-y_lo:.0f}" fill="{col}" opacity="0.22"/>')
                yb = rpos[1] if rpos else (y_lo + y_hi) / 2
                p.append(f'<circle cx="{x:.0f}" cy="{yb:.0f}" r="11" fill="{col}" stroke="#000" stroke-width="1.5"/>')
                p.append(f'<text x="{x:.0f}" y="{yb+4:.0f}" class="pin">{i}</text>')
                p.append(f'<text x="{x:.0f}" y="{vb_y+16:.0f}" class="alab" fill="{col}">{_esc(skill)}</text>')
            else:
                # x·cell 둘 다 없음 (예: picked_ge 트리거) → 캡션으로만 표기
                when = "사탕 획득 시" if tr.get("type") == "picked_ge" else ""
                sel = {"max_x": "가장 앞선", "min_x": "가장 뒤쳐진"}.get(tgt.get("select"), "")
                undrawn.append(f'{i}. {_esc(skill)} → {sel} 개미' + (f' ({when})' if when else ''))

    for j, cap in enumerate(undrawn):
        ty = vb_y + 18 + j * 20
        p.append(f'<text x="{vb_x+10:.0f}" y="{ty:.0f}" class="cap">{cap}</text>')

    p.append('</svg>')
    return "\n".join(p)
