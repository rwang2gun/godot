---
name: ch1-front
duration_estimate: 14400
verify: python scripts/run_test.py tests/CampaignManifestTest.tscn && python scripts/run_test.py tests/CampaignUnlockOrderTest.tscn && python scripts/run_test.py tests/StageSelectUnlockTest.tscn && python scripts/run_test.py tests/StringsTableTest.tscn && python scripts/run_test.py tests/StageIdentityTest.tscn && python scripts/run_test.py tests/CampaignClearedPreservationTest.tscn && python scripts/run_test.py tests/CampaignS1ClearTest.tscn && python scripts/run_test.py tests/CampaignS11ClearTest.tscn && python scripts/run_test.py tests/CampaignS12ClearTest.tscn && python scripts/run_test.py tests/CampaignS13ClearTest.tscn && python scripts/run_test.py tests/CampaignS14ClearTest.tscn && python scripts/run_test.py tests/CampaignS12NoBlockerTest.tscn && python scripts/run_test.py tests/CampaignS14NoFloaterTest.tscn && python scripts/run_test.py tests/GameFlowTest.tscn
large_change_ok: false
sot: docs/CAMPAIGN_50_DESIGN.md
sot_aux: [data/campaign_manifest.tres, scripts/core/Strings.gd, scripts/core/SceneFlow.gd, scripts/world/StageLayoutBuilder.gd, scenes/entities/hazards/Water.tscn, docs/DOMAIN_MAP.md]
---

# Phase B1: ch1-front (Ch1 Stage slot 2~5 저작)

## 목표
CHAPTER 1(기초)의 **slot 2~5 신규 4 스테이지**를 저작해 climber·blocker·floater 3종 스킬을 도입한다.
기존 stage01(첫 나들이)=slot1·stage02(오르막)=slot6은 재사용·재배치만(콘텐츠 무변경, B1 범위는 매니페스트 삽입까지).

## 확정 결정 (설계 §3·§4·§5.0, 사용자 정렬 2026-06-09)
- **scene_id 배정 (불변 정체성)**: 신규는 다음 빈 id 11~14. 기존 1·2 재사용.
  > **scene_id ≠ 캠페인 순번 (LOW-1)**: 테스트명 `CampaignS11*`은 *불변 scene_id 11*을 뜻하며 "캠페인 11번째"가 아니다. 설계 §3의 "Stages 11-20"(Ch2 순번)과 혼동 금지 — 본 phase 11~14는 Ch1 slot2~5의 씬 id.

  | slot | scene_id | 이름 | 신규/사용 스킬 | 해저드 | 출처 |
  |---|---|---|---|---|---|
  | 1 | 1 | 첫 나들이 | climber | — | 기존 stage01 (무변경) |
  | 2 | **11** | 담을 넘어 | climber | — | **신규** |
  | 3 | **12** | 낭떠러지 끝 | **blocker(NEW)** | water | **신규** |
  | 4 | **13** | 방향 전환 | blocker · climber | water | **신규** |
  | 5 | **14** | 높은 곳에서 | **floater(NEW)** | — | **신규** |
  | 6 | 2 | **절벽 아래로** (현 이름 유지) | climber · floater · blocker | — | 기존 stage02 재배치만 |

  > **stage02 이름 (MEDIUM-2)**: StageSlotCard는 `Strings.stage_name()`이 SoT → slot6은 현재 이름 "절벽 아래로"로 표시된다. §3 시트 컨셉명 "오르막" rename은 **B2로 명시 defer**(B1은 stage02 콘텐츠·이름 무변경).

- **매니페스트 재배치**: `data/campaign_manifest.tres` Ch1 `stage_ids` `[1, 2]` → **`[1, 11, 12, 13, 14, 2]`** (1과 2 사이 삽입).
  → slot6에 stage02가 자동 안착(고아 없음). 다른 챕터 배열 무변경. B2에서 `[..., 2, 15, 16, 17, 18]` append.
- **별점**: 전역 규칙 고정(`Scoring.compute_stars`). per-stage star_thresholds 필드 없음(schema v3) — 저작 시 무관.
- **파라미터 가이드(§2.2, 실측 조정)**: Ch1 hp4~5 / ants는 hp보다 여유 / time 90~110s.
- **여백=물(§2.2.1)**: 각 스테이지 플레이 영역 밖 도달 가능 빈 공간(바닥 아래·좌우 바깥·치명 갭)은 `water`로 채운다.
- **기절 임계(레벨 저작 규칙, 2026-06-02 실증)**: floater 학습용 의도 낙하는 **≥6칸**(정확히 5칸은 grace 프레임으로 임계 미발동). slot5는 ≥6칸 낙하로 저작.

## 신규 스테이지 컨셉 (정밀 셀 좌표는 저작 시 확정 — §3 노트)
정밀 지오메트리는 구현 시 실측으로 확정한다. 아래는 컨셉·스킬·필수성 계약.

> **공통 계약 (Round 1 반영)**
> - **왕복 동선 (HIGH-2)**: 모든 스테이지는 *픽업 후 180° 귀환*까지 성립해야 한다. 영구 설치물(blocker)이 막는 분기는 사탕·집 동선과 **분리된 막다른 위험 분기**여야 하며, Home·Candy는 blocker 같은 쪽에 둔다 → 운반자가 blocker에 튕겨 hazard로 빠지거나 Home에서 멀어지지 않는다. ClearTest는 `saved ≥ candy_hp` (= 귀환 성립)를 단언.
> - **해저드 = 씬 인스턴스 (MEDIUM-3)**: water는 `Water.tscn`(Area2D, HazardBase가 `_ready`에서 셀 등록)을 **씬에 인스턴스**해야 발화한다. `hazard_map` 딕셔너리만으로는 런타임 무발화 — 치명 갭·여백 셀마다 Water 노드 배치를 acceptance에 포함.
> - **필수성 negative (HIGH-3 / R2-HIGH-2)**: 각 negative는 `saved < candy_hp`(실패) 단언 + **짝 ClearTest(`saved ≥ hp`)가 맵 가용성 보장** → "개미가 사탕에 못 가서 실패"한 맵 버그를 necessity로 오인하지 않는다. **⚠ `lost`(=ScoreSystem.lost_pieces)는 *운반 중 사탕 손실(carrier death)*만 카운트** — 빈손 개미가 water에 빠지면 `AdriftState`가 `has_candy` false면 `candy_piece_lost`를 emit하지 않아 `lost==0`이다. 따라서:
>   - **carrier-death형 (floater id14)**: 운반 개미가 귀환 중 낙하 기절 → `picked>0 ∧ lost>0 ∧ saved<hp`.
>   - **pickup-전 hazard형 (blocker id12)**: 빈손 개미가 픽업 전 익사 → `saved<hp` (lost는 0일 수 있음). 익사 관측이 필요하면 result.lost가 아니라 water 진입/개미 소멸을 직접 단언.

### id11 · 담을 넘어 (slot2) — climber 심화
- 컨셉: 평지 직선 경로 중앙에 **3칸 높이 벽**. climber로 반복 등반해 Candy 도달·귀환.
- params(잠정): total_ants 6 / candy_hp 4 / time 90s / available=[climber] / inventory={climber:6} / release 30.
- 필수성: climber 없으면 벽에서 flip → Candy 미도달(no_more_ants).
- 템플릿: stage01 트리오 복사(climber-only 구조 동형).

### id12 · 낭떠러지 끝 (slot3) — blocker 도입(NEW)
- 컨셉: 사탕·집 동선과 **분리된 막다른 water 구덩이 분기**. 무보정 시 무리가 분기로 진행해 빠져 lost. **blocker를 분기 입구에 배치**해 무리를 반전시켜 안전 경로의 Candy로 유도(공통 계약 §왕복 동선).
- params(잠정): total_ants 6 / candy_hp 4 / time 100s / available=[blocker, climber] / inventory={blocker:1, climber:4} / release 30.
- 해저드: water(구덩이 + 여백) — Water.tscn 인스턴스(공통 계약 §해저드).
- 필수성(`CampaignS12NoBlockerTest`): blocker 미사용 → 빈손 개미 익사로 `saved<candy_hp`(빈손 익사라 `lost`는 0 가능 — 공통 계약 §필수성 negative). 짝 ClearTest가 맵 가용성 보장.
- 템플릿: stage02 트리오 복사(water+blocker 인벤토리) 후 지오메트리 단순화.

### id13 · 방향 전환 (slot4) — blocker 충돌-반전 유도
- 컨셉: **갈래길** — 한쪽은 water(즉사), blocker 충돌-반전으로 무리를 안전 갈래(필요 시 climber 등반)로 보낸다.
- params(잠정): total_ants 6 / candy_hp 4 / time 100s / available=[blocker, climber] / inventory={blocker:1, climber:4} / release 30.
- 해저드: water.
- 필수성: blocker 미사용 시 무리가 위험 갈래로 진행 → 실패(별도 negative는 선택, essential 세트에서 제외 가능).
- 템플릿: id12 또는 stage02 복사.

### id14 · 높은 곳에서 (slot5) — floater 도입(NEW)
- 컨셉: 고지대 Candy. 귀환 시 **≥6칸 낙하** 구간 → 무보정 시 착지 기절(lost). **floater로 안전 강하** 학습.
- params(잠정): total_ants 6 / candy_hp 4 / time 100s / available=[floater, climber] / inventory={floater:6, climber:2} / release 30.
- 필수성(`CampaignS14NoFloaterTest`): floater 미사용 → `picked>0`(사탕 회수) ∧ ≥6칸 낙하 기절 `lost>0` ∧ `saved<candy_hp`.
- 템플릿: stage02 트리오 복사(floater 인벤토리 보유). 낙하 구간 ≥6칸 보장.

## 변경 대상
**신규 (각 스테이지 = 트리오 + 테스트)**
- `data/stage_layouts/stage11_layout.tres` ~ `stage14_layout.tres` (지오메트리, 신규 uid)
- `data/stages/stage11.tres` ~ `stage14.tres` (params, id 11~14)
- `scenes/stages/Stage11.tscn` ~ `Stage14.tscn` (기존 트리오 복사 후 layout/stage repoint + Home/Candy/Camera/Spawner 좌표·Water 인스턴스 갱신)
- `tests/CampaignS11ClearTest.{gd,tscn}`, `CampaignS12ClearTest.{gd,tscn}`, `CampaignS13ClearTest.{gd,tscn}`, `CampaignS14ClearTest.{gd,tscn}` (각 `saved≥candy_hp`)
- `tests/CampaignS12NoBlockerTest.{gd,tscn}` (blocker 필수성), `tests/CampaignS14NoFloaterTest.{gd,tscn}` (floater 필수성) — 공통 계약 §필수성 negative 준수
- `tests/StageIdentityTest.{gd,tscn}` (**H-4**), `tests/CampaignClearedPreservationTest.{gd,tscn}` (**M-1**)

**수정 — 회귀 테스트 갱신 (Round 1 C-1/C-2/H-1 반영, 깨질 테스트 선식별)**
- `data/campaign_manifest.tres` — Ch1 stage_ids `[1,2]` → `[1,11,12,13,14,2]`
- `scripts/core/Strings.gd` — `stage.s11.name`~`stage.s14.name` 추가(표 이름).
- `tests/CampaignManifestTest.gd` (**C-1 / R2-HIGH-1**) — 하드코딩 파생 기대값 **전수** 갱신: `ordered_stage_ids` `[1..10]`→`[1,11,12,13,14,2,3,4,5,6,7,8,9,10]`, Ch1 `[1,2]`→`[1,11,12,13,14,2]`, `next_stage_id(1)` `2`→`11`, `next_stage_id(14)`==`2`(신규), `position_of(10)` `10`→`14`. (구현 시 파일 grep으로 단언 전수 확인 — 누락 0.)
- `tests/GameFlowTest.gd` (**C-2**) — Scenario A: Stage01 클리어 후 Next = **id11**(이전 id2)로 단언 갱신. Scenario B(last-stage)·C 무변경(LAST=id10 불변).
- `tests/StageSelectUnlockTest.gd` (**H-1**) — Ch1 케이스 재작성: 6 실제 + 4 placeholder = 10칸. stage1만 cleared 시 기대 `[CLEARED, PLAYABLE, LOCKED, LOCKED, LOCKED, LOCKED, COMING_SOON×4]`. placeholder는 `slot_state==COMING_SOON` ∧ `stage_id==0`까지 단언(**LOW-2**).
- `tests/StringsTableTest.gd` — **테스트 코드 변경 불요**(published stage_name 동적 루프 §7). 단 위 `Strings.gd`의 `stage.s11~s14.name` 키 추가는 **필수**(루프가 published id 11~14에 비어있지 않은 이름 요구) — **LOW-1(R2)**.

**신규 가드 테스트 상세**
- `StageIdentityTest` (**H-4**): id 11~14에 대해 `stageNN.tres.id == NN` ∧ `StageNN.tscn`이 로드하는 StageData.id == NN ∧ 11~14 중복 id 0. copy/repoint 오참조(예: Stage11.tscn이 stage02.tres 참조, stage11.tres가 id=2) silent 발행 차단.
- `CampaignClearedPreservationTest` (**M-1 / R2-MEDIUM-1**): 두 단언 분리 — (a) **보존**: id2 cleared 기록 → manifest `[1,11,12,13,14,2]` 적용 → id2 여전히 cleared ∧ slot6 = **CLEARED**(cleared가 playable보다 우선, `_resolve_slot_state`). (b) **언락 재계산**: id2 미클리어 + id14 cleared → slot6 = **PLAYABLE**. ADR-014 cleared 보존 + 언락 재도출 실증.

## 검증 방법 (verify 프론트매터)
1. **매니페스트/언락 회귀**: CampaignManifestTest, CampaignUnlockOrderTest, StageSelectUnlockTest (Ch1 슬롯 수 6 실제 + 4 placeholder = 10, 언락 체인 1→11→12→13→14→2).
2. **신규 클리어**: CampaignS11~S14ClearTest (saved≥candy_hp, lost 적정).
3. **필수성(negative)**: CampaignS12NoBlocker(빠짐→실패), CampaignS14NoFloater(기절→실패).
4. **이름**: StringsTableTest (published stage_name 누락 0).
5. **기존 회귀 무파손**: CampaignS1ClearTest, GameFlowTest(A·B·C — Scenario B last-stage 술어는 LAST_STAGE_ID=매니페스트 마지막=id10 불변).
6. **수동 검증**: 게임 실행 → ChapterSelect→Ch1(기초)→slot2~5 플레이로 각 스킬 학습 곡선·난이도 확인.

## 회귀 주의 (사전 식별)
- **LAST_STAGE_ID 불변**: Ch1에 삽입해도 전역 마지막은 Ch5 id10(보물찾기). SceneFlow last-stage 술어·GameFlow ScenB 무영향.
- **stage02 cleared 보존**: 재배치(slot2→slot6)는 ordering만 변경, SaveData cleared/stars 보존(ADR-014).
- **stage02 언락 변경**: 이전=stage01 클리어 시(slot2). 이후=id14 클리어 시(slot6). 의도된 변화(오르막은 중반).
- **placeholder padding**: slot7~10은 매니페스트 미등재 → StageSelect가 stage_id=0 placeholder("임시")로 채움(이미 구현). B2에서 실제 등재.
- **신규 svg/png 없음**: 신규 스테이지는 기존 타일/엔티티 에셋 재사용 → `--import` 부트스트랩 불요(class_name 신규 0). 단 신규 가드 테스트가 `class_name`을 추가하면 부트스트랩.
- **깨질 회귀 선식별 (C-1/C-2/H-1)**: CampaignManifestTest·GameFlowTest ScenA·StageSelectUnlockTest는 매니페스트 순서 변경으로 **반드시 깨진다** → 위 "변경 대상 수정"에 명시 갱신 포함(구현 시 동시 수정).
- **기절 임계 stale 주석 (MEDIUM-4)**: `tests/CampaignS2NoFloaterTest.gd`의 "5칸" 주석은 stale(실측 ≥6 필요). id14는 ≥6칸으로 저작하고 그 가정 재사용 금지.
