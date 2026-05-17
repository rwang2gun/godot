---
name: map-editor-stage-save-fix
date: 2026-05-17
track: map-editor
status: implemented
---

# Existing Stage Save Fix

## 배경

Stage01을 Load한 뒤 저장할 때 `Failed to save res://data/stages/stage01.tres: Invalid parameter` 오류가 발생했다.

## 변경

- `addons/candyants_level_tool/level_tool_dock.gd`
  - 저장 전 `resource.take_over_path(path)`를 호출하는 `_save_resource()` helper 추가.
  - layout, stage data, packed scene 저장 모두 `_save_resource()`를 사용.
  - 기존 `stageXX.tres`가 있으면 새 `StageData`를 만들지 않고 기존 리소스를 로드해 값만 갱신.
  - `StageData.layout`은 저장된 `stageXX_layout.tres`를 다시 로드한 외부 리소스 참조로 설정.

## 검증

실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:

- exit code 0
- 플러그인 및 GDScript 파싱/로딩 성공
- 실제 버튼 저장은 Godot UI에서 재확인 필요
