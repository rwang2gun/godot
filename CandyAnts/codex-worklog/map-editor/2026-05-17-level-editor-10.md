---
name: map-editor-runtime-tile-visibility-fix
date: 2026-05-17
track: map-editor
status: implemented
---

# Runtime Tile Visibility Fix

## 배경

Stage01에서 레벨 에디터로 타일을 배치했지만 실제 플레이 화면에 플랫폼이 보이지 않았다.

## 원인

- `stage01_layout.tres`에는 타일 데이터가 저장되어 있었다.
- `Stage01.tscn`에는 `StageLayoutBuilder` 노드가 빠져 있어서 런타임에서 타일을 생성하지 않았다.
- `StageLayoutBuilder`가 에디터 preview에서 `layout.cell_to_world()`를 호출했는데, `StageLayoutData`가 editor placeholder로 로드되면 메서드 호출이 막혀 오류가 났다.

## 변경

- `scenes/stages/Stage01.tscn`
  - `World/StageLayoutBuilder` 노드 추가.
  - `res://data/stage_layouts/stage01_layout.tres` 연결.
- `addons/candyants_level_tool/level_tool_dock.gd`
  - 생성/저장 시 `StageLayoutBuilder` owner를 강제 지정.
  - 저장 전 builder의 `build()`를 호출하고 하위 노드 owner도 재지정.
- `scripts/world/StageLayoutBuilder.gd`
  - `layout.cell_to_world()` 호출 제거.
  - builder 내부에서 cell 좌표를 직접 world 좌표로 계산.
  - `layout.cell_size` 타입을 명시적으로 `int` 캐스팅.

## 검증

실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:

- exit code 0
- `StageLayoutBuilder` 파싱 및 editor preview 오류 해소
- AppData/editor cache 저장 실패 메시지는 Codex sandbox 제한으로 유지
