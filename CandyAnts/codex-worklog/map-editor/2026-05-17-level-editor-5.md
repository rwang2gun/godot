---
name: map-editor-stage01-ground-limit
date: 2026-05-17
track: map-editor
status: implemented
---

# Stage01 Ground Placement Limit

## 배경

HUD 작업과 병행 중인 현재 스테이지 기준에서, Stage01의 타일 배치 높이가 맵 에디터의 하한선이다. 이보다 아래쪽에는 플랫폼 타일을 배치하면 안 된다는 규칙을 사용자 요청으로 명시했다.

## 변경

- `addons/candyants_level_tool/level_tool_dock.gd`의 `GridPreview`에 `MAX_PLATFORM_ROW := 27` 추가.
- GUI grid에서 `y > 27` 영역은 어둡게 표시하고 빨간 경계선을 그린다.
- 좌클릭/드래그, 우클릭/드래그 모두 `y > 27` 영역에서는 동작하지 않는다.
- `Platform Runs` 텍스트 입력에서도 `y > 27` 플랫폼 cell은 저장 데이터에서 제외된다.
- dock/큰 grid window 안내 문구에 Stage01 ground limit 아래 행이 막힌다는 내용을 반영했다.

## 기준

- 현재 cell size 기본값은 32.
- Stage01 바닥 기준 `y=27`이 허용 가능한 최하단 플랫폼 행이다.
- 금지 시작 행은 `y=28`부터다.

## 검증

실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:

- exit code 0
- 플러그인 및 GDScript 파싱/로딩 성공
- AppData/editor cache 저장 실패 메시지는 Codex sandbox 제한으로 유지
