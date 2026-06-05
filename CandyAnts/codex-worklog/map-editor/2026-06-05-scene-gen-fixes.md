---
name: map-editor-scene-gen-fixes
date: 2026-06-05
track: map-editor
status: implemented
---

# 2026-06-05 — 애드온 씬 생성 결함 3종 수정 + Stage01~03 복구 + 웹 에디터 제거

## 배경
사용자가 애드온(Godot dock)으로 Stage01~03을 재저작·저장한 뒤 게임 실행 시 증상 보고:
1. 스킬 선택 UI(SkillToolbar)가 안 뜸
2. Home(시작점)·Candy가 지형에서 떠 있고 개미가 캔디에 도달 못 함

조사 결과 **애드온 `_build_stage_scene`의 구조적 결함**이 원인. 저장 시점에 스킬 카운트가 0이라
.tres의 `available_skills`가 비었고, 빈 스킬 → 툴바 노드 생략까지 겹쳐 증상이 두 겹으로 나타났다.
(초기엔 별도 웹 에디터 `tools/map_editor/`를 원인으로 오진했으나, 씬에 박힌 Cell 노드가 애드온
`StageLayoutBuilder.build()` 출력과 일치 → 애드온이 실제 원인으로 확정.)

## 애드온 결함 3종 (근본 수정)
`addons/candyants_level_tool/level_tool_dock.gd` `_build_stage_scene`:

| 결함 | 증상 | 수정 |
|---|---|---|
| Home/Candy를 `cell_to_world`(셀 중심)에 배치 | 엔티티가 원점=바닥·충돌 위로 뻗는 구조라 셀 절반(24px) 떠 캔디 도달 불가 | `_cell_to_surface()` 헬퍼 추가 — Y를 `(cell.y+1)*cell_size`(셀 바닥=지면 표면)로. Home·Candy·Spawner에 적용 |
| `PlacementPreview` 노드 미생성 | 설치형 스킬(sand_mound/builder/bridge) ghost 미리보기 없음 | `_add_placement_preview()` — terrain 뒤에 항상 생성. `_toolbar==null`이면 `_process`가 null-guard로 무해 |
| `toolbar_path` 미설정 | StageRunner가 클리어 시 toolbar 비활성화 못 함 | `_add_skill_toolbar`에서 `root.toolbar_path = NodePath("SkillToolbar")` 연결 |

정상 동작하는 Stage04~06의 배치 공식(엔티티 Y=`(cell.y+1)*cell_size`, X=셀 중심)을 기준으로 맞춤.

## 일회성 복구 (이미 손상된 Stage01~03)
애드온이 찍은 기존 씬/데이터는 수동 복구:
- `data/stages/stage0{1,2,3}.tres` — 유실된 `available_skills`/`skill_inventory` 복원
  (S1 climber8/blocker1, S2 climber6/floater1, S3 bridge5). S3는 candy_hp/total_ants/release도 복원.
- `scenes/stages/Stage0{1,2,3}.tscn` — 빠진 `SkillToolbar`·`PlacementPreview`·`toolbar_path` ext_resource+노드 추가(가산만, 편집한 지형/좌표 보존). Home/Candy Y를 셀 바닥(480/192/480)으로, Spawner 472.5로 정렬.

## 웹 에디터 제거 (사용자 요청, 별건)
`tools/map_editor/`(Node 웹 에디터)는 9종 중 builder/blocker 2종만 지원해 스킬 유실 위험 → 사용자 요청으로 삭제.
`run_map_editor.bat`, `.gitignore` 항목, `docs/DOMAIN_MAP.md` 설명도 정리. 스테이지 편집은 Godot dock 단일화.

## 검증 (헤드리스, run_test.py 풀 부팅)
- 애드온 `_build_stage_scene` 직접 호출: home.y=480, candy.y=480, PlacementPreview 생성, SkillToolbar+toolbar_path 연결 확인.
- Stage01~03 인스턴스화: 툴바 슬롯 2/2/1 빌드, PlacementPreview·toolbar_path 정상.
- Candy 충돌 하단이 지면 표면(480/192/480)에 정확히 일치(`reach=true`) → 개미 도달 가능.
- 스킬 부여 프로브: 개미 스폰 후 SKILL_ASSIGN → 인벤토리 차감(`ASSIGN OK`). (사용자측 부여 불가 증상은 Godot import 캐시 갱신으로 해소.)

## 다음 작업 영향
- STATUS "다음 작업"의 *Home/Candy/Spawner 배치 모드*는 여전히 유효(에디터 내 마커 드래그 이동). 이번 건 생성 시 좌표 보정만.
- 신규 스테이지 저장도 이제 toolbar/placement/지면정렬이 자동 보장됨.
