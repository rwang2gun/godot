---
name: map-editor-slope-tiles
date: 2026-05-17
track: map-editor
status: implemented
---

# Slope Tile Types

## 배경

경사면 레벨을 만들 수 있도록 기존 solid-only 플랫폼 칸에 타일 타입을 얹었다. 방향 타입은 `slope_right`, `slope_left` 기준으로 잡았다.

## 변경

- `scripts/core/StageLayoutData.gd`
  - `tile_map: Dictionary` 추가.
  - 기존 `platform_cells`는 호환용으로 유지.
- `scripts/world/StageLayoutBuilder.gd`
  - `tile_map`이 있으면 우선 사용하고, 없으면 기존 `platform_cells`를 solid로 변환.
  - `solid`는 `RectangleShape2D`.
  - `slope_right`, `slope_left`는 `CollisionPolygon2D` 삼각형 충돌체.
  - 경사 타일은 `Polygon2D` 삼각형 visual로 표시.
- `addons/candyants_level_tool/level_tool_dock.gd`
  - Brush 선택 추가: `Solid`, `Slope Right`, `Slope Left`, `Erase`.
  - 작은 preview와 큰 grid editor window 모두 선택 브러시로 칠하기 지원.
  - grid preview에서 solid는 사각형, slope는 삼각형으로 표시.
  - 텍스트 포맷 확장:
    - 기존 `x,y,length`는 solid로 유지.
    - `x,y,length,slope_right`
    - `x,y,length,slope_left`
  - `slop_right`, `slop_left`도 입력 호환으로 받아 `slope_right`, `slope_left`로 정규화.

## 예시

```text
0,27,20
20,27,1,slope_right
21,26,1,slope_right
35,25,1,slope_left
36,26,1,slope_left
37,27,10
```

## 검증

실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:

- exit code 0
- 플러그인 및 GDScript 파싱/로딩 성공
- AppData/editor cache 저장 실패 메시지는 Codex sandbox 제한으로 유지

## 남은 과제

- 실제 플레이에서 개미가 slope collision 위를 자연스럽게 걷는지 플레이테스트.
- slope 전용 쿠키 아트 타일 추가.
- slope brush 단축키 또는 toolbar icon 개선.
