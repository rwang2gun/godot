---
name: map-editor-grid-window-visibility-fix
date: 2026-05-17
track: map-editor
status: implemented
---

# Grid Window Visibility Fix

## 배경

사용자가 큰 Grid Editor 창을 열었지만 toolbar만 보이고 편집 grid가 검은 빈 영역처럼 보인다고 보고했다.

## 변경

- `addons/candyants_level_tool/level_tool_dock.gd`
  - grid window의 root `VBoxContainer`에 full-rect anchors 적용.
  - toolbar에 horizontal expand flag 추가.
  - scroll container에 명시적 최소 높이 지정.
  - 큰 grid preview의 `size`를 `custom_minimum_size`로 명시 지정.
  - window open 시 `popup_centered()` 사용 및 grid redraw 강제.
  - grid 배경/선 대비를 올려 빈 화면처럼 보이는 문제 완화.

## 검증

실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:

- exit code 0
- 플러그인 및 GDScript 파싱/로딩 성공
- AppData/editor cache 저장 실패 메시지는 Codex sandbox 제한으로 유지
