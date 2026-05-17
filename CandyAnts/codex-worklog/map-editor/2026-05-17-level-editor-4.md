---
name: map-editor-large-grid-window
date: 2026-05-17
track: map-editor
status: implemented
---

# Large Grid Editor Window

## 배경

사용자가 하단 패널 안의 grid preview가 너무 작아서 편집이 불편하다고 피드백했다. 방향성은 맞으므로 grid를 별도 큰 편집 창으로 분리했다.

## 변경

- `addons/candyants_level_tool/level_tool_dock.gd`에 `Open Grid Editor` 버튼 추가.
- 버튼을 누르면 `CandyAnts Grid Editor` 별도 `Window`가 열린다.
- 큰 창은 60x34 grid를 24px cell로 표시한다.
- 기존 dock 내부 preview는 12px cell의 작은 요약 preview로 축소했다.
- 작은 preview, 큰 editor window, `Platform Runs` 텍스트가 같은 platform cell 데이터를 공유한다.
- 어느 쪽에서 그리거나 지워도 `x,y,length` 텍스트와 두 preview가 동기화된다.

## 현재 조작

- 좌클릭/드래그: 플랫폼 칸 추가.
- 우클릭/드래그: 플랫폼 칸 삭제.
- H/C/K 마커는 Home/Candy/Camera 위치 표시.
- H/C/K 직접 드래그 이동은 아직 미구현. 현재는 dock의 cell spin 값으로 이동.

## 검증

실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:

- exit code 0
- 플러그인 및 GDScript 파싱/로딩 성공
- AppData/editor cache 저장 실패 메시지는 Codex sandbox 제한으로 유지

## 다음 작업

- 큰 창에서 H/C/K 마커 배치 모드 추가.
- 창 안에 Draw/Erase/Move Home/Move Candy/Move Camera 모드 버튼 추가.
- stage camera frame overlay 표시.
