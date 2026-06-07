---
name: guide-card-ui-restructure
duration_estimate: 5400
verify: python scripts/run_test.py tests/StageGuideDataRenderTest.tscn && python scripts/run_test.py tests/StageIntroCardShowTest.tscn && python scripts/run_test.py tests/StringsTableTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [scripts/ui/StageIntroCard.gd, scenes/ui/StageIntroCard.tscn, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 5b: guide-card-ui-restructure

## 목표
인트로 카드 가독성 향상 — **문단 간 명시적 줄바꿈(공백)**으로 정보 그룹을 시각 분리. 현재는 문단 간격이 좁아 가독성↓(사용자 피드백 2026-06-07). Phase 5/`cc9903f`에서 카드 자동 확대·≥22pt·단일 라인은 이미 완료, 본 phase는 **세로 간격(레이아웃)만** 재구성.

## 배경 (Phase 5에서 완료된 것 — 건드리지 말 것)
- 카드 콘텐츠 기반 자동 확대(`_resize_to_content`): show_intro 후 1프레임 뒤 `_main.get_combined_minimum_size` 측정 → Card custom_minimum_size + caPop pivot. 폭 캡 [560, 1080]. **스페이서 높이도 get_combined_minimum_size에 포함되므로 간격 추가 시 카드 높이가 자동 성장** — 추가 작업 불요.
- 본문 라벨 autowrap OFF(각 카피 한 줄). 폰트 목표 24 / 스킬명 24 / 설명·해저드 22.
- inspector(goal_text/skill_desc_texts/hazard_texts/shown_skill_ids/badge_labels)는 raw Strings 반환 — 표시 변형과 분리. **유지 필수**(render/drift 테스트가 직접 대조).

## 요청 레이아웃 (사용자 SoT, 2026-06-07)
```
타이틀                       ← Title (display_name)
스테이지 소개                ← Goal (목표 카피)
(2줄 공백)
스킬 1 정보                  ← 스킬1 헤더 (아이콘 + 라벨 + 입력모델 배지)
스킬 1 사용 방법             ← 스킬1 설명
(1줄 공백)                   ← 스킬 사이
스킬 2 정보                  ← 스킬2 헤더
스킬 2 사용 방법             ← 스킬2 설명
(2줄 공백)
[시작]   [건너뛰기]          ← ButtonRow
```
- **해저드 배치(설계 결정 필요)**: 위 예시엔 해저드 없음. 제안 = 스킬 목록 뒤 **1줄 공백 → 해저드 → 2줄 공백 → 버튼**. (해저드 없는 스테이지는 해저드+선행 1줄 공백 숨김, 스킬→2줄 공백→버튼 직결.) 구현 전 확정.

## 구현 방향 (이번 세션 탐색 — 채택 권장)
**명시적 스페이서 Control**로 구간별 가변 간격(VBox 균일 separation으론 불가):
- VBox `separation = 0`으로 두고, 사이사이 `Control(custom_minimum_size = Vector2(0, gap))` 스페이서 삽입.
- 간격 토큰(픽셀, 22pt 기준 1줄 ≈ 30px): `_GAP_TITLE_GOAL ≈ 8`(소제목 톤, 타이틀+소개 한 묶음) / `_GAP_2LINE ≈ 60`(소개→스킬, 스킬→버튼) / `_GAP_1LINE ≈ 30`(스킬 사이, 스킬→해저드) / 스킬 내부 헤더→설명 ≈ 6(타이트).
- **SkillList/HazardList 노드는 유지**(child_count = 스킬/해저드 수 = render 테스트 의존). 스킬 사이 1줄 공백 = `SkillList.separation ≈ 30`. 큰 공백(2줄)·해저드 선행 공백은 **메인 VBox의 스페이서 Control**로(SkillList 밖).
- 씬 노드 순서(레이아웃 = 문서 순): Title → SpacerTG → Goal → SpacerGS(2줄) → SkillList(sep 30) → SpacerSH(1줄, 해저드시만 visible) → HazardList → SpacerHB(2줄) → ButtonRow.
- 스페이서 + HazardList visibility는 `_bind_content`에서 토글(해저드 유무, 가이드 null fallback 시 스킬/해저드/큰공백 숨김).

## 변경 대상
- `scenes/ui/StageIntroCard.tscn`: VBox separation 0 + Spacer Control 4종(TG/GS/SH/HB) 삽입 + SkillList separation 30 / HazardList separation 조정.
- `scripts/ui/StageIntroCard.gd`: 간격 토큰 const + 스페이서 @onready 참조 + `_bind_content`에서 해저드 유무에 따라 SpacerSH/HazardList visibility 토글. (콘텐츠/inspector 로직 무변경.)
- (선택) `tests/StageIntroCardLayoutTest`: 스페이서 노드 존재 + 해저드 유무별 visibility 단언(빈 UI ↔ inspector 괴리 차단). render 테스트 SkillList child_count 단언은 유지.

## 검증 방법
- 카드 테스트 PASS: StageGuideDataRenderTest / StageIntroCardShowTest / StringsTableTest (+ HeadlessSkip / IntroPauseBlockOwnership 회귀).
- **시각 검증(필수)**: 헤드리스는 더미 렌더러라 뷰포트 캡처 불가 → **창모드 godot 직접 실행** + 캡처 씬에서 `get_viewport().get_texture().get_image().save_png("user://...")` → S1(1스킬 무해저드)·S3(1스킬+해저드)·S8(2스킬+해저드)로 문단 간격 육안 확인. (godot bin = `run_test.find_godot`, 출력 = `%APPDATA%/Godot/app_userdata/CandyAnts/`.)

## 수용 기준
- 타이틀·소개가 한 묶음, 소개→스킬 2줄 공백, 스킬 사이 1줄 공백, 스킬→버튼 2줄 공백(해저드 있으면 스킬→1줄→해저드→2줄→버튼)으로 시각 분리.
- 본문 전부 ≥20pt·단일 라인 유지(Phase 5 회귀 0).
- inspector raw 반환 유지 → render/drift 테스트 무영향.
- 카드 높이 자동 성장(스페이서 포함)으로 오버플로/클리핑 0.
