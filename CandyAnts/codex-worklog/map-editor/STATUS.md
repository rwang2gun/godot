# map-editor STATUS

## 목적
인게임/에디터 내 스테이지 맵 에디터 툴. Godot 에디터 플러그인 기반 long-running 트랙.

## 현재 상태 (2026-06-04 기준)
**텍스트 좌표 입력 + Grid preview + 별도 큰 Grid Editor 창 + slope tile 타입 + 전체 스킬/해저드/메타 저작** 단계.
플랫폼 칸은 GUI 모눈에서 직접 그리기/지우기(solid/slope_right/slope_left), 해저드(water/sticky)도 같은 모눈에서 페인팅 가능.
스킬은 SkillRegistry 등록 9종 전부를 횟수와 함께 설정하고, spawn 방향·theme·정착 cell·별 기준(star_thresholds)도 GUI로 편집한다.

### 2026-06-04 추가 (skills-hazards-meta)
- 스킬 9종(builder/blocker/climber/floater/sand_mound/bridge/basher/digger/cutter) × 횟수 SpinBox. distributor는 미등록이라 제외.
- 해저드 브러시(Water/Sticky) → `StageLayoutData.hazard_map`에 저장, 씬 생성 시 `Water_x_y`/`Sticky_x_y` 노드 인스턴스화.
- 메타 GUI: spawn dir(+1/-1)·alternate·theme(5종)·settlement cell(센티넬 -1,-1)·star override(off=글로벌 fallback).
- latent bug fix: `available_skills` 타입 명시 빈 배열 대입(Godot 4.6 Invalid assignment 회피).
- 미저장 변경(dirty) 표시: 콘텐츠 편집 시 제목 + 하단 패널 버튼에 `*`. Load/Save/Create 시 clean. 로드 중 suppress.
- 프로젝트 런처: `run_level_editor.bat` / `scripts/run_editor.py` — Godot 에디터로 프로젝트 열기(바이너리 재귀 탐색 폴백 포함).
- **새 스테이지 등록(2단계, codex 리뷰 반영)**: `SceneFlow`를 `STAGE_SCENES`(파일 존재 스캔, load_stage용)와 `PUBLISHED_STAGE_IDS`(씬 ∩ `menu_layout.tres` available, **캠페인 SoT**)로 분리. `LAST_STAGE_ID`·`load_next`·`_on_request_play_stage`·Continue는 published만. menu_layout 무효 시 **fail closed**. → 새 스테이지는 파일만 있으면 *로드 가능*, *캠페인 노출*은 menu_layout `available=true` 필요(미완성 스테이지 자동 노출 차단). 회귀 가드: `tests/SceneFlowStageScanTest`(Stage10 파일 추가해도 미노출+LAST 9 유지). 제약: 11번째 스테이지는 `MenuLayout.EXPECTED_LENGTH` 확장 필요. codex adversarial-review 3R→approve.
- 헤드리스 PASS: 데이터 20-assert + dirty 11-assert(임시 하니스, 사후 삭제) + SceneFlow/MainMenu/GameFlow/StageSelect 9개 씬 테스트 + 신규 SceneFlowStageScanTest. 세션 로그: [2026-06-04-skills-hazards-meta.md](2026-06-04-skills-hazards-meta.md).
- 이전 상태(2026-05-17): 텍스트 좌표 + Grid preview + 큰 Grid 창 + slope tile 타입까지.

### 산출물 위치
- 플러그인: `addons/candyants_level_tool/` (하단 패널 `CandyAnts Level` + `Project > Tools > CandyAnts Level Tool`)
- 레이아웃 데이터: `data/stage_layouts/`
- 리소스 스키마: `scripts/core/StageLayoutData.gd` (`cell_size`, `platform_cells`, `home_cell`, `candy_cell`, `camera_cell`, spawn 방향)
- 빌더: `scripts/world/StageLayoutBuilder.gd` (`StageLayoutData` → `StaticBody2D` + 쿠키 타일 sprite)
- 통합 지점: `scripts/core/StageData.gd`에 `layout: Resource` 필드 추가

### 동작 흐름
스테이지 생성 시 동시에 만들어지는 파일:
- `res://data/stages/stageXX.tres`
- `res://data/stage_layouts/stageXX_layout.tres`
- `res://scenes/stages/StageXX.tscn`

플랫폼 입력은 `x,y,length` 텍스트와 60x34 grid preview가 양방향 동기화된다.
- 텍스트 예: `0,27,60` = x=0, y=27에서 가로 60칸
- slope 텍스트 예: `20,26,1,slope_right`, `21,27,1,slope_left`
- GUI: 좌클릭/드래그 = 선택 Brush 칠하기, 우클릭/드래그 = 지우기
- Brush: `Solid`, `Slope Right`, `Slope Left`, `Erase`
- 큰 편집 창: `Open Grid Editor` 버튼으로 열며 24px cell 크기로 편집
- 배치 제한: Stage01 바닥 기준 `y=27`이 플랫폼 배치 최하단이며, `y=28` 아래는 GUI/텍스트 입력 모두 저장 제외
- 기존 스테이지 편집: Stage ID를 1~3으로 맞춘 뒤 `Load Stage`, 편집 후 `Save Stage`
- Home/Candy/Camera는 각각 H/C/K 마커로 표시

### 캐시 의존성 회피 (중요)
`StageData.gd`·`StageLayoutBuilder.gd`에서 `StageLayoutData` 타입을 직접 참조 시, 스크립트 캐시가 새 `class_name`을 등록 못 한 타이밍에 "타입을 찾을 수 없음" 오류 발생 가능 → export 타입을 `Resource`로 낮춰 순서 의존성 제거.

## 다음 작업
- Home/Candy/Spawner 배치 모드 추가 (마커 클릭/드래그 이동)
- 현재 grid에서 stage bounds/카메라 프레임 오버레이 표시
- 지우개, 선 긋기, 사각형 채우기
- Save Layout과 Create Stage 분리
- Playtest Stage 버튼 (이번 범위에서 제외됨)
- 해저드 배치를 바닥 아래(y>27)까지 허용 — 그리드 bounds 재작업 필요(현재 y≤27 제약 공유)
- 레거시 스테이지(03/08/09) 씬-only 해저드를 hazard_map으로 마이그레이션(현재 Load 시 미표시)
- StageSelect 그리드(`data/menu_layout.tres` 고정 10슬롯)에 새 스테이지 자동 노출 — SceneFlow 라우팅은 자동(2026-06-04)이나 선택 화면은 아직 수동
- ~~기존 `Stage01~03` layout 마이그레이션~~ — **데이터 레벨 완료** (2026-05-29). Stage01=commit `a4cc9d7`, Stage02/03=3-tier(surface/solid/background)로 재작성 (`scripts/tools/build_stage_3tier_layout.py` 생성기 + [worklog](../../worklog/2026-05/2026-05-29-stage-3tier-layout-migration.md)). 단, **에디터에는 아직 surface/background 브러시가 없어** 위 생성기로 hand-author했다. 에디터 기반 3-tier 저작을 하려면 brush + 자동 깊이 채움 추가 필요 (아래 신규 항목).
- **(신규)** 에디터에 `surface`/`background` tile 브러시 + 바닥 아래 자동 background 채움 추가 (3-tier 저작 지원)
- 스테이지 선택/진행 흐름에 새 스테이지 자동 등록

## 블로커
- 없음 (헤드리스 에디터 컴파일 통과. AppData/editor cache 쓰기 실패는 Codex 샌드박스 제한, 플러그인 동작과 무관)

## 세션 로그
- [2026-05-17-level-editor.md](2026-05-17-level-editor.md) — 1차 기반: 플러그인 골격 + StageLayoutData 리소스 + 텍스트 좌표 입력 빌더
- [2026-05-17-level-editor-2.md](2026-05-17-level-editor-2.md) — map-editor 트랙 기록 기준 정리 및 프로젝트 규칙 승격
- [2026-05-17-level-editor-3.md](2026-05-17-level-editor-3.md) — 60x34 grid preview GUI 추가, 플랫폼 draw/erase와 텍스트 양방향 동기화
- [2026-05-17-level-editor-4.md](2026-05-17-level-editor-4.md) — 별도 큰 grid editor window 추가, dock preview 축소 및 양방향 동기화 유지
- [2026-05-17-level-editor-5.md](2026-05-17-level-editor-5.md) — Stage01 바닥 기준 플랫폼 배치 하한선 적용 (`y <= 27`만 허용)
- [2026-05-17-level-editor-6.md](2026-05-17-level-editor-6.md) — `solid`, `slope_right`, `slope_left` tile_map 타입 추가 및 editor brush/preview/runtime collision 지원
- [2026-05-17-level-editor-7.md](2026-05-17-level-editor-7.md) — 큰 grid editor window의 grid visibility/layout 보정
- [2026-05-17-level-editor-8.md](2026-05-17-level-editor-8.md) — Stage01~03 등 기존 stage load/save 흐름 추가
- [2026-05-17-level-editor-9.md](2026-05-17-level-editor-9.md) — 기존 stage 저장 시 `Invalid parameter` 완화: resource path 명시 및 기존 StageData 갱신 방식 적용
- [2026-05-17-level-editor-10.md](2026-05-17-level-editor-10.md) — StageLayoutBuilder 누락/placeholder 메서드 호출 문제 수정으로 런타임 타일 표시 복구
