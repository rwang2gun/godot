#!/usr/bin/env python3
"""3-tier 지형 레이아웃 생성기 (docs/TERRAIN_TILE_RULES.md §7 "확장 절차" 박제).

Stage 1에서 락다운한 surface / solid / background 3-tier 지형 구조를
나머지 stage layout(.tres)에 적용한다.

핵심 불변식 (TERRAIN_TILE_RULES §3):
  - `solid`만 충돌(StaticBody2D + Terrain occupancy). 기존 solid cell은 한 칸도
    옮기거나 지우지 않는다 → 충돌 geometry/퍼즐/헤드리스 테스트 전부 불변.
  - `surface` / `background`는 시각 전용(충돌 없음). 순수 가산 레이어.
  - 엔티티(home/candy/spawn)는 이미 solid 한 칸 위(= surface row)에 정렬돼 있어
    좌표 변경이 필요 없다 (Stage 1 컨벤션과 동일).

깊이(bottom row 30)는 Stage 1과 동일 — 뷰포트 1080 하단까지 초콜릿 내부가 채워진다.

Usage:
    python scripts/tools/build_stage_3tier_layout.py          # stage02/03 .tres 재작성
    python scripts/tools/build_stage_3tier_layout.py --print   # 미리보기만
"""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
LAYOUT_DIR = ROOT / "data" / "stage_layouts"

BOTTOM_ROW = 30          # Stage 1과 동일한 내부 채움 최하단 (뷰포트 1080 하단)
SCRIPT_UID = "uid://xi30okhe70kg"   # StageLayoutData.gd
SCRIPT_ID = "1_xqg42"


def _r(a: int, b: int) -> range:
    """포함 범위 [a, b]."""
    return range(a, b + 1)


def _cols(*spans: range) -> list[int]:
    out: list[int] = []
    for s in spans:
        out.extend(s)
    return out


# ---------------------------------------------------------------------------
# Stage 정의 — 각 stage의 3-tier 구조를 명시적으로 기술.
#   solid:      충돌 cell (기존 layout에서 그대로 보존하는 집합)
#   surface:    걷는 면 위에 얹는 시각 크러스트 (solid 바로 위 한 줄)
#   background: 비충돌 초콜릿 내부 채움
#
#   builder 자동 추론(§3): solid 위가 surface면 베이스=under_surface,
#   solid 위가 solid면 베이스=interior(background) 텍스처. 따라서 흙벽처럼
#   여러 줄 쌓인 solid는 background tile 없이도 초콜릿 내부로 렌더된다.
# ---------------------------------------------------------------------------

def stage02() -> dict[str, str]:
    """모래 다리 — 바닥(row22) + 떠 있는 캔디 발판(row17, cols15-28).

    발판은 공중에 떠 있어야 한다: ants가 발판 밑(floor)을 지나 x≈870(col18)에서
    builder 다리를 올린다 (Stage02HeadlessTest TRIGGER_X). 갭을 background로
    메우면 퍼즐이 깨지므로 발판은 얇은 밑면(row18) 한 줄만 둔다.
    """
    tiles: dict[str, str] = {}
    # 바닥 (지면) — 깊은 내부 채움
    for x in _r(3, 28):
        tiles[f"{x},21"] = "surface"
        tiles[f"{x},22"] = "solid"
        for y in _r(23, BOTTOM_ROW):
            tiles[f"{x},{y}"] = "background"
    # 떠 있는 캔디 발판 — 얇은 쿠키 선반
    for x in _r(15, 28):
        tiles[f"{x},16"] = "surface"
        tiles[f"{x},17"] = "solid"
        tiles[f"{x},18"] = "background"   # 얇은 밑면 lip (갭 미침범)
    return tiles


def stage03() -> dict[str, str]:
    """흙을 깎다 — 바닥(row22) + 흙벽 기둥(cols12-16, rows17-21) + 좌측 step(2,21).

    흙벽은 basher 대상이므로 rows17-21을 solid 그대로 유지(빌더가 자동으로
    crust(16)+under(17)+초콜릿(18-21) 렌더). 바닥 surface는 흙벽이 차지하는
    cols12-16을 제외한다.
    """
    tiles: dict[str, str] = {}
    wall_cols = set(_r(12, 16))
    # 바닥 (지면)
    for x in _r(3, 28):
        if x not in wall_cols:           # 흙벽이 row21을 점유하는 칸은 surface 제외
            tiles[f"{x},21"] = "surface"
        tiles[f"{x},22"] = "solid"
        for y in _r(23, BOTTOM_ROW):
            tiles[f"{x},{y}"] = "background"
    # 흙벽 기둥 (basher 대상) — solid 보존 + 상단 crust
    for x in _r(12, 16):
        tiles[f"{x},16"] = "surface"
        for y in _r(17, 21):
            tiles[f"{x},{y}"] = "solid"
    # 좌측 step (2,21) — 보존 + 시각 보강 (떠 보이지 않게 아래 채움)
    tiles["2,20"] = "surface"
    tiles["2,21"] = "solid"
    for y in _r(22, BOTTOM_ROW):
        tiles[f"2,{y}"] = "background"
    return tiles


# (file_uid, home, candy, camera, spawn_direction, alternate, builder)
STAGES = {
    "stage02_layout.tres": dict(
        uid="uid://b2candyants02ly",
        home=(5, 21), candy=(25, 16), camera=(15, 19),
        spawn_direction=1, alternate=False, build=stage02,
    ),
    "stage03_layout.tres": dict(
        uid="uid://b3candyants03ly",
        home=(5, 21), candy=(25, 21), camera=(15, 19),
        spawn_direction=1, alternate=True, build=stage03,
    ),
}


def _sort_key(k: str) -> tuple[int, int]:
    x, y = k.split(",")
    return (int(x), int(y))


def render_tres(spec: dict) -> str:
    tiles: dict[str, str] = spec["build"]()
    hx, hy = spec["home"]
    cx, cy = spec["candy"]
    kx, ky = spec["camera"]
    lines = [
        f'[gd_resource type="Resource" script_class="StageLayoutData" format=3 uid="{spec["uid"]}"]',
        "",
        f'[ext_resource type="Script" uid="{SCRIPT_UID}" path="res://scripts/core/StageLayoutData.gd" id="{SCRIPT_ID}"]',
        "",
        "[resource]",
        f'script = ExtResource("{SCRIPT_ID}")',
        "cell_size = 48",
        f"home_cell = Vector2i({hx}, {hy})",
        f"candy_cell = Vector2i({cx}, {cy})",
        f"camera_cell = Vector2i({kx}, {ky})",
        f"spawn_direction = {spec['spawn_direction']}",
        f"spawn_direction_alternate = {str(spec['alternate']).lower()}",
        "tile_map = {",
    ]
    keys = sorted(tiles.keys(), key=_sort_key)
    for i, k in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        lines.append(f'"{k}": "{tiles[k]}"{comma}')
    lines.append("}")
    return "\n".join(lines) + "\n"


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--print", action="store_true", dest="preview",
                    help="파일에 쓰지 않고 stdout 미리보기")
    args = ap.parse_args()
    for name, spec in STAGES.items():
        content = render_tres(spec)
        if args.preview:
            print(f"===== {name} ({content.count(chr(10))} lines) =====")
            print(content)
            continue
        out = LAYOUT_DIR / name
        out.write_text(content, encoding="utf-8", newline="\n")
        n_tiles = content.count('": "')
        print(f"wrote {out.relative_to(ROOT)}  ({n_tiles} tiles)")


if __name__ == "__main__":
    main()
