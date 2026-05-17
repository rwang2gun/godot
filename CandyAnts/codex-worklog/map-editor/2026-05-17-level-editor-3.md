---
name: map-editor-grid-preview
date: 2026-05-17
track: map-editor
status: implemented
---

# Level Editor Grid Preview

## 핸드오프
- 사용자가 맵 에디터를 GUI 형태로 계속 작업해달라고 요청했다.
- `codex-worklog/map-editor/STATUS.md`의 다음 작업은 60x34 grid preview 컨트롤 추가였다.

## 산출물
- `addons/candyants_level_tool/level_tool_dock.gd`에 `GridPreview` 커스텀 `Control`을 추가했다.
- 기존 `Platform Runs` 텍스트 입력은 유지하고, 아래에 스크롤 가능한 60x34 모눈 GUI를 추가했다.
- 좌클릭/드래그로 플랫폼 칸을 추가하고, 우클릭/드래그로 지울 수 있게 했다.
- GUI에서 편집한 플랫폼 칸은 `x,y,length` run 텍스트로 다시 압축되어 `Platform Runs`에 반영된다.
- 텍스트 입력을 직접 수정하거나 템플릿을 바꾸면 grid preview도 다시 동기화된다.
- Home/Candy/Camera 위치는 각각 H/C/K 마커로 표시된다.

## 결정
- 1차 GUI 전환은 플랫폼 칸 편집에 집중했다.
- Home/Candy/Spawner 배치 모드는 다음 단계로 남겼다.
- 기존 텍스트 입력 방식은 삭제하지 않고 GUI와 양방향 동기화되는 fallback/정밀 입력 수단으로 유지했다.

## 통합 노트
- 편집 대상 파일: `addons/candyants_level_tool/level_tool_dock.gd`
- 레이아웃 데이터 구조(`StageLayoutData`)와 stage 생성 흐름은 변경하지 않았다.
- grid preview는 현재 60 columns x 34 rows, preview cell 16px 기준이다.
- Camera 마커는 Candy의 C와 충돌하지 않도록 K로 표기했다.

## 검증
실행:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

결과:
- exit code 0
- 플러그인 및 GDScript 파싱/로딩 성공
- 기존 AppData/editor cache 저장 실패 메시지는 Codex 샌드박스 제한으로 유지

## 남은 과제
- Home/Candy/Spawner 배치 모드 추가
- 마커 클릭/드래그 이동
- 기존 스테이지 layout 불러오기/수정
- Save Layout과 Create Stage 분리
- Playtest Stage 버튼 추가
