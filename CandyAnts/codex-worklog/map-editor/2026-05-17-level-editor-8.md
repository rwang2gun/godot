---
name: map-editor-load-save-existing-stages
date: 2026-05-17
track: map-editor
status: implemented
---

# Load/Save Existing Stages

## 배경

사용자가 Stage01~03을 레벨디자인 툴로 편집하고 싶다고 요청했다. 기존 툴은 새 스테이지 생성 중심이어서 기존 stage data/layout을 불러오고 덮어 저장하는 흐름이 필요했다.

## 변경

- `addons/candyants_level_tool/level_tool_dock.gd`
  - `Load Stage` 버튼 추가.
  - `Save Stage` 버튼 추가.
  - `Create Stage`는 기존처럼 새 stage만 생성하고, 이미 존재하면 막는다.
  - `Save Stage`는 현재 Stage ID의 파일들을 덮어쓴다.

## 동작

Stage ID를 1, 2, 3으로 바꾸고 `Load Stage`를 누르면:

- `res://data/stages/stageXX.tres`를 읽어 기본 수치/스킬을 채운다.
- `res://data/stage_layouts/stageXX_layout.tres`가 있으면 읽는다.
- layout 파일이 아직 없으면 Stage01~03용 기본 layout을 생성해서 화면에 표시한다.

편집 후 `Save Stage`를 누르면:

- `res://data/stages/stageXX.tres`
- `res://data/stage_layouts/stageXX_layout.tres`
- `res://scenes/stages/StageXX.tscn`

을 현재 툴 상태로 저장한다.

## 주의

`Save Stage`는 기존 Stage scene을 새 layout-builder 기반 scene으로 다시 저장한다. 기존 수동 플랫폼 노드는 대체된다.

## 검증

실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:

- exit code 0
- 플러그인 및 GDScript 파싱/로딩 성공
- AppData/editor cache 저장 실패 메시지는 Codex sandbox 제한으로 유지
