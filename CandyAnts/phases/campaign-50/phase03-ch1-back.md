---
name: ch1-back
duration_estimate: 14400
verify: python scripts/run_test.py tests/CampaignManifestTest.tscn && python scripts/run_test.py tests/CampaignUnlockOrderTest.tscn && python scripts/run_test.py tests/StageSelectUnlockTest.tscn && python scripts/run_test.py tests/StringsTableTest.tscn && python scripts/run_test.py tests/CampaignS15ClearTest.tscn && python scripts/run_test.py tests/CampaignS16ClearTest.tscn && python scripts/run_test.py tests/CampaignS17ClearTest.tscn && python scripts/run_test.py tests/CampaignS18ClearTest.tscn && python scripts/run_test.py tests/GameFlowTest.tscn
large_change_ok: false
sot: docs/CAMPAIGN_50_DESIGN.md
sot_aux: [data/campaign_manifest.tres, scripts/core/Strings.gd, scripts/core/SceneFlow.gd, scripts/world/StageLayoutBuilder.gd, scenes/entities/hazards/Water.tscn, docs/DOMAIN_MAP.md]
---

# Phase B2: ch1-back (Ch1 Stage slot 7~10 + 캡스톤)

> **B1 완료 후 상세화.** 본 파일은 분해 골격이며, 진입(`next`) 시 §3 시트 기준으로 정밀 컨셉을 확정한다.

## 목표
CHAPTER 1의 **slot 7~10 신규 4 스테이지**(누적 조합 + 캡스톤)를 저작해 Ch1을 10스테이지로 완성한다.

## 확정 결정 (설계 §3·§4)
- **scene_id**: 신규 id 15~18.

  | slot | scene_id | 이름(잠정) | 사용 스킬 | 해저드 |
  |---|---|---|---|---|
  | 7 | 15 | 두 길 | blocker · floater | water |
  | 8 | 16 | 물웅덩이 사이 | climber · blocker | water |
  | 9 | 17 | 좁은 발판 | climber · blocker · floater | water |
  | 10 | 18 | **개미 언덕 (캡스톤)** | climber · blocker · floater | water |

- **매니페스트 append**: Ch1 `[1,11,12,13,14,2]` → **`[1,11,12,13,14,2,15,16,17,18]`** (10슬롯 완성).
- **캡스톤(slot10)**: Ch1 종합 — 다층 지형, 3종 정밀 운용, 타이트한 별3(전역 규칙이라 지오메트리·인벤토리·시간으로 난이도).
- **Ch1 복층 규칙(§2.5.3)**: "계단식 열린 단(ledge)"만 — climber 열린 벽면 + floater 하강. 천장 막힌 밀폐 방 금지.

## 변경 대상 (B1과 동형)
- `stage15~18` 트리오(layout/stage/scene) + `CampaignS15~S18ClearTest` + 캡스톤 negative.
- `campaign_manifest.tres` Ch1 append. `Strings.gd` stage.s15~s18.name.

## 검증 방법
- 신규 4 클리어 + 캡스톤 필수성 + 매니페스트/언락/Strings 회귀 + GameFlow + Ch1 전체(slot1~10) 언락 체인.
- 수동: ChapterSelect→Ch1 10슬롯 전부 플레이, Ch1 클리어 시 Ch2 언락 확인(`is_chapter_unlocked(2)`).
