# 2026-05-17 Level Editor Worklog

## Summary

CandyAnts 레벨디자인 툴의 1차 기반을 추가했다. 현재 상태는 완성형 비주얼 에디터가 아니라, Godot 에디터 플러그인에서 스테이지 기본 데이터와 모눈 좌표 기반 플랫폼 레이아웃을 생성하는 초기 버전이다.

## Paths

- `addons/candyants_level_tool/`
  - Godot 에디터 플러그인 본체.
  - 하단 패널 `CandyAnts Level`과 `Project > Tools > CandyAnts Level Tool` 메뉴로 접근하도록 구성.
- `data/stage_layouts/`
  - 스테이지별 모눈 좌표 레이아웃 리소스 저장 위치.
- `scripts/core/StageLayoutData.gd`
  - `cell_size`, `platform_cells`, `home_cell`, `candy_cell`, `camera_cell`, spawn 방향 정보를 담는 리소스.
- `scripts/world/StageLayoutBuilder.gd`
  - `StageLayoutData`의 좌표 목록을 실제 `StaticBody2D` 충돌체와 쿠키 타일 스프라이트로 생성.
- `scripts/core/StageData.gd`
  - `layout: Resource` 필드를 추가해 스테이지 데이터가 레이아웃 리소스를 참조할 수 있게 함.

## Implemented

- `addons/candyants_level_tool` 경로에 플러그인 유지.
- 스테이지 생성 시 아래 파일을 함께 만들도록 설계.
  - `res://data/stages/stageXX.tres`
  - `res://data/stage_layouts/stageXX_layout.tres`
  - `res://scenes/stages/StageXX.tscn`
- 플랫폼 입력을 `x,y,length` 형식으로 받는 텍스트 기반 모눈 배치 방식 추가.
  - 예: `0,27,60`은 x=0, y=27부터 가로 60칸 플랫폼.
- 템플릿 선택 시 기본 플랫폼 run 텍스트가 채워지도록 구성.
- Godot headless editor 실행으로 플러그인과 새 스크립트 컴파일 확인.

## Important Fix

처음에는 `StageData.gd`와 `StageLayoutBuilder.gd`가 `StageLayoutData` 타입을 직접 참조했다. Claude/Godot 쪽 스크립트 캐시가 새 `class_name StageLayoutData`를 아직 등록하지 못하면 `StageLayoutData`를 찾을 수 없다는 오류가 날 수 있어서, export 타입을 `Resource`로 낮춰 캐시 순서 의존성을 줄였다.

## Current State

현재 레벨 에디터는 "텍스트 좌표 입력형 스테이지 생성기" 단계다. 모눈을 마우스로 클릭해서 편집하는 완성형 에디터는 아직 아니다.

## Not Done Yet

- 기존 스테이지 불러오기/수정.
- 모눈 preview UI.
- 클릭/드래그 플랫폼 배치.
- 지우개, 선 긋기, 사각형 채우기 같은 편집 도구.
- Home/Candy/Spawner 배치 모드.
- Save Layout과 Create Stage 분리.
- Playtest Stage 버튼.
- 기존 `Stage01~03`의 layout 구조 마이그레이션.
- 게임의 스테이지 선택/진행 흐름에 새 스테이지 자동 등록.

## Recommended Next Step

다음 작업은 `addons/candyants_level_tool` 내부에 grid preview 컨트롤을 추가하는 것이다. 먼저 60x34 정도의 고정 모눈을 그리고, 왼쪽 클릭으로 플랫폼 칸 토글, 드래그로 연속 배치, 오른쪽 클릭으로 지우기를 붙이면 텍스트 입력기에서 실제 레벨 에디터로 넘어갈 수 있다.

## Verification

Ran:

```text
D:\Godot_v4.6.2-stable_win64_console.exe --headless --path D:\claude\godot\CandyAnts --editor --quit
```

Result:

- Plugin/scripts compiled.
- Remaining AppData/editor cache errors are from the sandbox blocking Godot user config/cache writes, not from the level editor scripts.
