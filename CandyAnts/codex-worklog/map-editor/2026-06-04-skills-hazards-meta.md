# 2026-06-04 — 레벨 에디터: 전체 스킬 + 해저드 배치 + 메타 필드

## 배경
사용자 요청: GUI 기반 레벨 에디터(시작/사탕 위치·타일·스킬+횟수·시간 제한 등). 기존 자산 점검 결과
`addons/candyants_level_tool/` 애드온이 이미 타일 페인팅·시작/사탕/카메라 마커·시간/개미/HP·Load/Save/Create를
구현하고 있어, **새로 만들지 않고 애드온을 확장**하기로 정렬(사용자 선택).

확정 범위(사용자 다중선택):
1. 전체 스킬 + 횟수 제한 UI (기존 builder/blocker 2종 하드코딩 → 등록된 9종)
2. 해저드 배치 (소다물 Water / 캐러멜 Sticky)
3. 메타 필드 (정착 cell · theme · star_thresholds · spawn 방향/alternate)

(플레이테스트 버튼은 제외)

## 변경 파일
- `scripts/core/StageLayoutData.gd` — `hazard_map: Dictionary` 필드 추가
  (key="x,y" → "water"|"sticky"). 런타임 빌더는 미사용, 에디터가 씬 생성 시 Water/Sticky 인스턴스를
  굽고 라운드트립(재로드)에 사용. 레거시 씬-only 해저드(Stage03/08/09)는 이 필드에 없어 Load 시 미표시.
- `addons/candyants_level_tool/level_tool_dock.gd`
  - GridPreview: `hazard_map` 저장/렌더(water=파랑·sticky=호박색 반투명) + `hazard_map_changed` 시그널.
    브러시가 Water/Sticky면 hazard_map에 칠하고, 우클릭/Erase는 tile·hazard 둘 다 지움. 정착 "S" 마커 렌더.
  - 스킬 UI: `SKILL_IDS`(9종) 데이터 기반 SpinBox. count>0 → available_skills + skill_inventory.
    **distributor는 SkillRegistry 미등록이라 의도적으로 제외** (넣으면 validate_stage 거부).
  - 메타: spawn dir OptionButton(+1/-1) · alternate CheckBox · theme OptionButton(5종) ·
    settlement enable CheckBox + X/Y(-1,-1 센티넬) · star override CheckBox + 3 SpinBox(off=글로벌 fallback).
  - 브러시 OptionButton(dock+큰 창)에 Water/Sticky 추가, `_selected_brush_tile_type()` 분기 확장.
  - `_build_layout_data`: hazard_map·spawn·theme·settlement 기록. (구 template 기반 spawn override 제거)
  - `_build_stage_data`: 9종 루프로 skill_inventory/available_skills, star_thresholds 기록.
  - `_load_stage`/`_apply_layout_data`: 위 필드 전부 역방향 로드.
  - `_build_stage_scene`: `_add_hazards`로 hazard_map → Water/Sticky 노드(`Water_x_y`/`Sticky_x_y`) 인스턴스화.

## 부수 수정 (latent bug)
`_build_stage_data`에서 `stage_data.available_skills = []` (untyped `[]` → `Array[String]` 속성 대입)이
Godot 4.6에서 `Invalid assignment` 런타임 에러. 타입 명시 빈 배열(`var empty_skills: Array[String] = []`)로 수정.
또한 `ResourceLoader.load(layout_path)`를 `ResourceLoader.exists` 가드 후 호출하도록 정리(없는 경로 noisy error 회피).

## 검증
- `--check-only` 파싱 통과.
- 헤드리스 1회성 하니스(`extends SceneTree`)로 dock 인스턴스화(+ `_ready` 수동 호출) 후:
  layout 빌드(theme/spawn/settle/hazard) · stage 빌드(스킬 8종, climber=0 제외, 횟수, stars) ·
  SkillRegistry.validate_stage 무에러 · 저장→재로드→apply 라운드트립 · 씬 생성(water 2 + sticky 1 노드)
  **20개 assert 전부 PASS**. 하니스 파일은 검증 후 삭제.
  - 주의: `--script` SceneTree 하니스에서는 노드 `_ready`가 자동 호출되지 않음 → dock/registry는 `_ready()` 수동 호출 필요.

## 후속 (같은 날, 사용자 요청 연쇄)

### 프로젝트 런처 (엔진 호출 편의)
- `scripts/run_editor.py` + `run_level_editor.bat` — 프로젝트를 Godot 에디터로 열어 레벨 dock 사용.
  Godot 탐색: GODOT_BIN → PATH → run_test.CANDIDATES → 흔한 폴더 재귀 스캔(console 빌드 우선).
  `--print`로 바이너리만 출력. `docs/DOMAIN_MAP.md` §3.1 진입점 갱신.

### 미저장(dirty) 표시
- `level_tool_dock.gd`: 콘텐츠 편집 시 제목 + 하단 패널 버튼(`candyants_level_tool.gd` 경유)에 `*`.
  Load/Save/Create 시 clean, 로드 중 `_suppress_dirty`로 오인 방지. `dirty_changed(bool)` 시그널로 플러그인이 버튼 텍스트 갱신.
- 검증: 헤드리스 시그널 수동 emit 11-assert PASS(임시 하니스 사후 삭제). 주의: 헤드리스 `--script`는 노드 `_ready`/`Range.value_changed` 자동 발화 안 함 → 수동 호출/emit로 검증.

### 새 스테이지 자동 등록 (SceneFlow 자동 스캔)
- `scripts/core/SceneFlow.gd`: `STAGE_SCENES` 하드코딩 dict(1~9) → `res://scenes/stages/Stage%02d.tscn` 자동 스캔.
  - static var + lazy `ensure_stage_scan()`(진입점 `_ready`/`load_stage`에서 호출). **static var 초기자에서 직접 스캔하면 클래스 로드 타이밍에 엔진 싱글톤 접근으로 C++ 크래시** → lazy 런타임 1회 스캔으로 회피.
  - export 안전: `DirAccess`(res:// 리매핑 취약) 대신 `ResourceLoader.exists` 프로빙(1..99). dev stage(910~) 자연 제외.
  - 정적 소스 테스트(`SceneFlowLastStagePredicateTest`)가 요구하는 `result["stage_id"] == LAST_STAGE_ID` 리터럴 유지.
- `scripts/ui/MainMenu.gd`: standalone 진입(SceneFlow._ready 미경유) 대비 `SceneFlow.ensure_stage_scan()` 호출 후 `STAGE_SCENES.has()`.
  - TDD Guard 훅이 `test_MainMenu.gd` 요구 → 프로젝트 컨벤션(`test_CButton.gd`류 스텁)대로 `tests/test_MainMenu.gd` 스텁 생성(실제 커버리지=MainMenuContinueGuardTest).
- 회귀 가드: `tests/SceneFlowStageScanTest.{gd,tscn}` — 1~9 반영 + 임시 Stage10 추가 시 rescan 자동 등록 + 정리 후 원복.
- **한계**: StageSelect 그리드는 `data/menu_layout.tres` 고정 10슬롯 기반 → 선택 화면 노출은 아직 수동(backlog).
- 검증: `MainMenuContinueGuardTest`(직전 RED→GREEN) 포함 SceneFlow/MainMenu/GameFlow/StageSelect 9개 + SceneFlowStageScanTest 전부 PASS.

## codex 적대적 리뷰 (사후, 2026-06-04)

`/codex:adversarial-review --base 7255f96`(2커밋) → 이후 working-tree 재리뷰. 3라운드 만에 clean.

- **R1 (needs-attention, HIGH)**: 파일 존재만으로 캠페인 routing 결정 → 미공개 StageNN.tscn이 menu_layout
  available 게이트를 우회해 Next로 노출되고 LAST_STAGE_ID(엔드포인트)를 이동.
- **R2 (needs-attention)**: HIGH = menu_layout 누락/무효 시 폴백이 fail-open(씬 전체 published). MEDIUM =
  `_on_request_play_stage`가 published 우회(중앙 trust boundary 누락).
- **R3 (approve, no material findings)**.

### 게이팅 수정 (hot-fix)
- `SceneFlow.gd`: 라우팅을 2단계로 분리.
  - `STAGE_SCENES` = 파일 존재 스캔(load_stage/replay/playtest용).
  - `PUBLISHED_STAGE_IDS` = `STAGE_SCENES ∩ menu_layout.tres available==true` = **캠페인 SoT**.
  - `LAST_STAGE_ID` = max(published). `load_next_stage`·`_on_request_play_stage`는 published만 허용.
  - **fail closed**: `layout is MenuLayout and layout.is_valid()` 아니면 published 비움(LAST_STAGE_ID=0).
- `MainMenu.gd`: Continue 가용성 `STAGE_SCENES` → `PUBLISHED_STAGE_IDS`.
- 회귀: `SceneFlowStageScanTest` 갱신 — Stage10.tscn 파일 추가해도 (slot10 unavailable) 캠페인 미노출 + LAST_STAGE_ID=9 유지.
- 검증: SceneFlow/MainMenu/GameFlow/StageSelect 11개 씬 테스트 PASS.

### 신규 출시(publish) 워크플로 + 제약
- 새 스테이지 **로드 가능**: `Stage%02d.tscn` 파일만 있으면 자동(씬 스캔).
- 새 스테이지 **캠페인 노출**: menu_layout.tres 해당 slot `available=true`로 설정(authored 게이트).
- **제약**: `MenuLayout.EXPECTED_LENGTH=10` → 슬롯 10번까지는 available 토글만, **11번째 스테이지는 menu_layout 슬롯 + EXPECTED_LENGTH 확장 필요**(기존 menu_layout 계약과 동일, StageSelect도 같은 제약).

## 알려진 한계 / 다음 작업
- 해저드 배치는 기존 그리드 placeable 영역(y≤27)과 동일 제약. 바닥 아래 물웅덩이(y>27)는 그리드 bounds 재작업 필요(기존 backlog).
- 레거시 스테이지(03/08/09)의 씬-only 해저드는 hazard_map에 없어 Load 시 그리드에 표시되지 않음(에디터 저작 스테이지만 라운드트립).
- 미커밋 상태(사용자 커밋 요청 대기).
