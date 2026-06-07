#!/usr/bin/env python3
"""Phase 2 (new-user-onboarding) one-shot: AffordanceGlowController 노드를 9개 stage 씬의
World/PlacementPreview 옆(sibling)에 주입한다. PlacementPreview와 동일 toolbar/terrain 경로 사용.
멱등 — 이미 주입된 씬은 건너뛴다."""
import re
import sys
from pathlib import Path

GLOW_UID = "uid://c6lel1jb3ls2g"
EXT_ID = "99_glow"
EXT_LINE = (
    f'[ext_resource type="Script" uid="{GLOW_UID}" '
    f'path="res://scripts/world/AffordanceGlowController.gd" id="{EXT_ID}"]\n'
)
NODE_BLOCK = (
    '\n[node name="AffordanceGlowController" type="Node2D" parent="World"]\n'
    f'script = ExtResource("{EXT_ID}")\n'
    'toolbar_path = NodePath("../../SkillToolbar")\n'
    'terrain_path = NodePath("../Terrain")\n'
)

stages = [Path(f"scenes/stages/Stage0{i}.tscn") for i in range(1, 10)]


def process(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if "AffordanceGlowController" in text:
        return "skip (already wired)"

    lines = text.splitlines(keepends=True)

    # 1) PlacementPreview ext_resource 라인 뒤에 glow ext_resource 삽입.
    ext_idx = next(
        (i for i, l in enumerate(lines)
         if l.startswith("[ext_resource") and "PlacementPreview.gd" in l),
        None,
    )
    if ext_idx is None:
        return "ERROR: PlacementPreview ext_resource not found"
    lines.insert(ext_idx + 1, EXT_LINE)

    # 2) PlacementPreview node 블록 끝(다음 [node]/[ 섹션 직전)에 glow 노드 블록 삽입.
    pp_idx = next(
        (i for i, l in enumerate(lines)
         if l.startswith('[node name="PlacementPreview"')),
        None,
    )
    if pp_idx is None:
        return "ERROR: PlacementPreview node not found"
    end = pp_idx + 1
    while end < len(lines) and not lines[end].startswith("["):
        end += 1
    # end = PlacementPreview 블록 직후(다음 섹션 시작 줄). 그 앞에 노드 블록 삽입.
    lines.insert(end, NODE_BLOCK)

    path.write_text("".join(lines), encoding="utf-8")
    return "wired"


def main() -> int:
    rc = 0
    for s in stages:
        if not s.exists():
            print(f"{s}: MISSING")
            rc = 1
            continue
        result = process(s)
        print(f"{s}: {result}")
        if result.startswith("ERROR"):
            rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
