---
name: campaign-infra
duration_estimate: 14400
verify: python scripts/run_test.py tests/CampaignManifestTest.tscn && python scripts/run_test.py tests/CampaignUnlockOrderTest.tscn && python scripts/run_test.py tests/SceneFlowChapterFlowTest.tscn && python scripts/run_test.py tests/ChapterSelectFlowTest.tscn && python scripts/run_test.py tests/GameFlowTest.tscn && python scripts/run_test.py tests/CampaignS1ClearTest.tscn
large_change_ok: true
sot: docs/CAMPAIGN_50_DESIGN.md
sot_aux: [scripts/core/SceneFlow.gd, scripts/core/SaveData.gd, scripts/core/MenuLayout.gd, scripts/ui/StageSelect.gd, scripts/ui/MainMenu.gd, docs/DOMAIN_MAP.md, docs/ADR.md]
---

# Phase A: campaign-infra (캠페인 매니페스트 + 챕터 UI)

## 목표
50스테이지 / 5챕터 캠페인의 **인프라 골격**을 세운다. 핵심은 **CampaignManifest**(캠페인 순서·챕터 배치 ↔ 씬 id 분리) 도입과 그 위의 **챕터 선택 UI** + **매니페스트 기반 언락/Next**. 이 Phase 완료 시:
- 기존 S1~S9가 **씬 id 불변**(파일 rename 0)으로 5챕터에 그룹핑되어 동작.
- 스테이지 **재배치 = 매니페스트 배열 편집 한 번**(사용자 요청의 핵심).
- MainMenu → ChapterSelect → StageSelect(선택 챕터) → Stage 흐름 동작, 미등재 슬롯 잠김.
- 이후 챕터 Phase가 **신규 씬을 매니페스트 배열에 추가**만 하면 캠페인이 확장됨(ADR-008 누적).

> SoT: `docs/CAMPAIGN_50_DESIGN.md` §5.0(매니페스트)·§4(배치 맵)·§5.2~5.3(UI). 본 Phase는 **코어/UI 배선만** — 신규 스테이지 *콘텐츠 저작은 없음*(B1부터).

## 배경 (현 구조의 결합)
현재 *캠페인 순서 = 씬 id = 세이브 키*가 한 덩어리(코드 실측):
- `SceneFlow`: `STAGE_SCENES` = `Stage%02d.tscn` 1..99 스캔. `PUBLISHED_STAGE_IDS` = 씬 ∩ `menu_layout.available`. `load_next_stage` = `_current_stage_id + 1`. `LAST_STAGE_ID` = max published.
- `SaveData.is_unlocked(N)` = `N==1 OR (N-1).cleared` (선형 ±1 산술).
- `MenuLayout`: 정확히 10슬롯(`EXPECTED_LENGTH=10`), `stage_id == i+1` 불변식. `StageSelect`가 이 10슬롯을 평면 GridContainer로 렌더.
- `MainMenu`: Play→`request_play_stage(1)`, Continue→`last_played`, StageSelect 버튼→`request_stage_select`(평면 10슬롯).

→ 챕터 그룹핑·스테이지 재배치를 하려면 씬 재번호가 강제되어 테스트·배선이 줄줄이 깨진다(설계 §4 리스크). 본 Phase가 그 결합을 끊는다.

## 설계 — 신규/변경 대상

### 1. CampaignManifest 리소스 (신규)
- **`scripts/core/CampaignManifest.gd`** (`class_name CampaignManifest extends Resource`)
  - `@export var chapters: Array[Dictionary] = []` — `chapters[c] = { "title": String, "theme": String, "stage_ids": Array[int] }`. `stage_ids` = 그 챕터 씬 id를 **순서대로** 나열(재배치 = 배열 편집).
  - 파생 헬퍼 (모두 chapters에서 계산, 별도 상태 없음 = 단일 SoT):
    - `ordered_stage_ids() -> Array[int]` — 전 챕터 평탄화(캠페인 전역 순서).
    - `chapter_of(scene_id) -> int` — 0=미등재.
    - `stage_ids_in_chapter(chapter_idx) -> Array[int]`.
    - `next_stage_id(scene_id) -> int` — 전역 순서상 다음, 없으면 0.
    - `position_of(scene_id) -> int` — 전역 1-based 위치, 미등재 0.
    - `first_stage_id() -> int`, `last_stage_id() -> int`.
    - `chapter_count() -> int`, `chapter_title(idx)`, `chapter_theme(idx)`.
    - `is_valid() -> bool` — chapters 비어있지 않음 + 각 챕터에 title/theme/stage_ids 키 + stage_ids 정수 배열 + **전역 중복 씬 id 없음**(같은 씬이 두 챕터에 등장 금지) + stage_ids 비어있지 않은 챕터가 1개 이상.
- **`data/campaign_manifest.tres`** (신규) — 초기 데이터 = **기존 10씬을 현재 순서 그대로 5챕터에 그룹핑**(순서 보존 = 최소 교란). 실측 스킬 도입 순서와 정합(climber→floater/blocker→bridge→builder→sand_mound→digger→basher→cutter/leaf_jump, 10종 stage8까지 도입, 9·10=콤보):
  - Ch1 "기초" theme=basics: `[1, 2]` — 첫 나들이(climber) · 절벽 아래로(climber+floater+blocker)
  - Ch2 "건설" theme=building: `[3, 4, 5]` — 웅덩이 넘기(bridge) · 높은 곳에 닿으려면(builder) · 과자 사다리(sand_mound+floater)
  - Ch3 "파괴" theme=destruction: `[6, 7]` — 숨겨진 사탕(digger+climber) · 벽 너머로(basher)
  - Ch4 "장치·숙련" theme=devices: `[8]` — 귀찮은 식물들(cutter+leaf_jump)
  - Ch5 "종합" theme=mastery: `[9, 10]` — 고지로!(콤보) · 보물찾기!(콤보)
  - ⟹ `ordered_stage_ids()` = `[1,2,3,4,5,6,7,8,9,10]` = **현재 선형 순서와 동일**(언락/Next/LAST_STAGE_ID=10 불변 = GameFlowTest 일치, 회귀 최소). 챕터 경계만 추가. 신규 스테이지는 B1~F2에서 각 챕터 배열에 append(기존 스테이지는 챕터 내 위치만 자연 이동).

### 2. Campaign 헬퍼 (신규, 언락/순서 파생의 단일 진입점)
- **`scripts/core/Campaign.gd`** — autoload(`project.godot [autoload]` 등록, SaveData 의존하므로 그 **이후** 로드 순서). 매니페스트를 1회 load + 캐시.
  - `manifest() -> CampaignManifest`.
  - `is_stage_unlocked(scene_id) -> bool` = `scene_id == manifest.first_stage_id()` **OR** `SaveData`가 `prev = (ordered에서 scene_id 직전)`을 cleared. (±1 산술 폐지 — manifest 순서 기준.) 미등재 씬은 false.
  - **챕터 번호 계약 = 1-based (CRITICAL, codex R1 MED-1)**: 모든 공개 챕터 API(Campaign·CampaignManifest)·UI·EventBus는 1-based(Ch1=1 … Ch5=5). `0`은 *미등재/not-found 전용* sentinel. (구현 `CampaignManifest`/`Campaign` 이미 1-based — 본 플랜 텍스트를 그에 맞춰 정정.) ChapterSelect가 0을 넘기지 않도록 테스트로 가드(챕터1 선택 → StageSelect가 [1,2] 렌더).
  - `is_chapter_unlocked(chapter_num) -> bool` = `chapter_num <= 1` OR 직전 *비어있지 않은* 챕터의 `last_stage_id` cleared. (빈 챕터는 skip해 그 앞으로 거슬러 — 데드 게이트 방지.)
  - `chapter_stars(chapter_num) -> int` = Σ SaveData stars of stage_ids_in_chapter(chapter_num).
  - `next_unlocked_stage() -> int` — Play 버튼용(첫 미클리어 = 진행 이어가기). 전부 클리어면 first.
  - **fail-closed**: manifest null/무효면 빈 매니페스트로 취급(캠페인 닫힘, 크래시 금지) — SceneFlow 정책과 동형.
- **SaveData는 순수 저장 유지** — `is_unlocked`(±1 선형) 호출부를 Campaign로 이관(아래 4). SaveData 자체는 cleared/stars 저장만, ordering 무지(ADR 디커플링 보존). `SaveData.is_unlocked`는 **deprecate 표기 후 잔존**(테스트/외부 참조 안전) 또는 호출부 0 확인 후 제거 — 호출부 grep으로 결정.

### 3. SceneFlow 변경 (매니페스트 SoT 교체 + 챕터 화면)
- `ensure_stage_scan()`의 (2) published 계산을 **menu_layout → manifest**로 교체:
  - `PUBLISHED_STAGE_IDS` = `scenes` ∩ `manifest.ordered_stage_ids()`(=등재된 씬만, 파일 존재 확인). `LAST_STAGE_ID` = manifest 순서상 마지막 *published* 씬. **fail-closed 유지**(manifest 무효 시 published 비움 + push_error).
- `load_next_stage()` = `Campaign.manifest().next_stage_id(_current_stage_id)` 사용. 0이면 last-stage clear → `go_to_main_menu()`(기존 동작 보존).
- **`ScreenState.CHAPTER_SELECT` 추가** + `go_to_chapter_select()`(`_swap_screen(load(CHAPTER_SELECT_SCENE)…)`). `CHAPTER_SELECT_SCENE := "res://scenes/ui/ChapterSelect.tscn"` 상수.
- EventBus: `request_chapter_select` 시그널 신설 + `_on_request_chapter_select` 핸들러(→ go_to_chapter_select). BGM은 메뉴 계열이라 `_swap_screen`이 자동으로 menu emit(기존 분기 재사용).
- `request_play_stage` trust boundary(published 게이트)·`_on_stage_result`의 `== LAST_STAGE_ID` 등치 검사는 **불변**(manifest 기반 LAST_STAGE_ID로 자연 동작).

### 4. UI — ChapterSelect 신설 + StageSelect/MainMenu 변경
- **`scenes/ui/ChapterSelect.tscn` + `scripts/ui/ChapterSelect.gd`** (신규)
  - 5개 챕터 카드(아톰 재사용: `StageSlotCard` 패턴 차용한 `ChapterCard` 신규 아톰, 또는 기존 카드 재사용 + 라벨). 카드 상태: LOCKED(`Campaign.is_chapter_unlocked`=false) / PLAYABLE / CLEARED(챕터 전 스테이지 cleared). 챕터 별점 `chapter_stars/(스테이지수×3)` 표시.
  - 선택 → 현재 챕터 컨텍스트 설정 후 `EventBus.request_stage_select.emit(chapter_idx)`(시그널에 chapter 인자 추가) 또는 StageSelect에 chapter를 전달하는 별도 시그널.
  - BackBtn/ESC → `request_main_menu`. 패드 포커스 초기화(기존 패턴).
- **`StageSelect.gd` 변경** — 챕터 컨텍스트 인식:
  - `menu_layout.tres` 로드 제거 → `Campaign.manifest().stage_ids_in_chapter(current_chapter)` 로 슬롯 생성(가변 개수, 10 고정 아님). `current_chapter`는 진입 시 주입(시그널 인자 or 화면 전이 컨텍스트).
  - 슬롯 상태: `_resolve_slot_state`를 manifest/Campaign 기반으로 — available(=manifest 등재 && 씬 존재) / cleared / `Campaign.is_stage_unlocked` / locked. ComingSoon = manifest 등재됐으나 씬 파일 부재(미저작 placeholder)일 때.
  - BackBtn/ESC → `request_chapter_select`(MainMenu 아님).
  - TotalStars는 유지하되 챕터 별점도 헤더에 표기 가능(선택).
- **`MainMenu.gd` 변경**:
  - Play → `Campaign.next_unlocked_stage()`(첫 미클리어 = 진행 이어가기; manifest.first 폴백).
  - StageSelect 버튼 → `request_chapter_select`(ChapterSelect 진입). (기존 `request_stage_select` 직행 폐지.)
  - Continue → `last_played`(불변), 단 가드의 published 검사는 manifest 기반으로 자연 동작.

### 5. menu_layout 폐기/이관
- `MenuLayout.gd`·`data/menu_layout.tres`·`MenuLayoutResourceTest`는 manifest가 포섭 → **제거 또는 manifest로 리다이렉트**. 호출부(`StageSelect`, `SceneFlow.ensure_stage_scan`, `MainMenu._refresh_continue_state` 간접) 전수 교체 후 삭제. `StageSelectUnlock`·`SceneFlow*` 테스트는 manifest 버전으로 갱신.

### 6. ADR 추가
- **ADR-014**: 캠페인 매니페스트 — 캠페인 순서/챕터 배치를 씬 id에서 분리. 결정/이유/트레이드오프(매니페스트 무효 시 fail-closed, 중복 씬 id 금지)·관련(ADR-008 누적, SceneFlow SoT).

## 변경 파일 요약
| 종류 | 파일 |
|---|---|
| 신규 | `scripts/core/CampaignManifest.gd`, `data/campaign_manifest.tres`, `scripts/core/Campaign.gd`, `scenes/ui/ChapterSelect.tscn`, `scripts/ui/ChapterSelect.gd`, (필요 시 `scenes/ui/atoms/ChapterCard.tscn`) |
| 변경 | `scripts/core/SceneFlow.gd`(published/next/CHAPTER_SELECT), `scripts/core/EventBus.gd`(request_chapter_select + request_stage_select chapter 인자), `scripts/ui/StageSelect.gd`(챕터 컨텍스트), `scripts/ui/MainMenu.gd`(Play/StageSelect 라우팅), `project.godot`([autoload] Campaign), `docs/ADR.md`(ADR-014), `docs/DOMAIN_MAP.md`(§3 매니페스트 인덱스) |
| 제거 | `scripts/core/MenuLayout.gd`, `data/menu_layout.tres` (호출부 이관 후) |

## 테스트 계획 (신규 + 갱신)
**신규**:
- `tests/CampaignManifestTest` — is_valid(정상/중복 씬 id/빈 챕터 거부), ordered_stage_ids 순서, chapter_of/next_stage_id/position_of/first/last 경계(미등재=0).
- `tests/CampaignUnlockOrderTest` — first 항상 unlocked, prev cleared 시 next unlocked(±1 아닌 manifest 순서), 챕터 게이팅(직전 챕터 last cleared 시 다음 챕터 열림), 빈 챕터 skip. **+ 챕터 1-based 가드(codex R2 MED-1): `is_chapter_unlocked(0)==false`·음수·`>chapter_count()` 거부, 챕터1은 여전히 언락.**
- `tests/SceneFlowChapterFlowTest` — go_to_chapter_select 전이, request_chapter_select 라우팅, load_next_stage가 manifest 순서 추종(예: 매니페스트 재배치 시 Next 변경), LAST_STAGE_ID = manifest 마지막.
- `tests/ChapterSelectFlowTest` — 챕터 카드 상태(잠김/플레이/클리어), 선택→StageSelect(해당 챕터 슬롯), Back→MainMenu.
**갱신**:
- `GameFlowTest` — last-stage 판정을 manifest 기반으로. **초기 manifest에서 last = 씬 10**(Ch5=[9,10] 마지막). Next-disabled + menu fallback 유지. **수용 검증(acceptance)**: `CampaignManifest.last_stage_id()` == `SceneFlow.LAST_STAGE_ID` == `GameFlowTest.LAST_STAGE_ID` == **10** (셋 다 10으로 수렴 — codex R1 HIGH-1). GameFlowTest Scenario B(load_stage(10)→강제 clear→Next disabled)는 무변경으로 통과해야.
- `StageSelectUnlock` — manifest/Campaign 기반 슬롯 상태로 재작성.
- `MenuLayoutResourceTest` — 제거 또는 CampaignManifestTest로 대체.
- `SceneFlow*`(Boot/EmitContract 등) — CHAPTER_SELECT 추가에 따른 영향 점검.
**회귀 (큐레이트, 무파손 확인)**:
- S1~S9 Clear/Neg(CampaignS1~ ... 씬 경로 참조라 불변), SaveData×N, Scoring, Hud, SceneFlow 2종, PauseMenu/Esc.

> 검증: `python scripts/run_test.py <scene>`. headless `--script` 한계로 런타임 검증은 씬 테스트(run_test.py)로(MEMORY: headless-script-harness-limits).

## 엣지 케이스 / 사전 방어 (codex 적대적 리뷰 선제 대응)
1. **세이브 호환**: 기존 save.cfg는 stage_id 키 cleared/stars 저장 — 불변. 언락은 *런타임 파생*(Campaign)이라 schema bump·마이그레이션 불요. 초기 manifest가 순서를 보존하므로 기존 진행도 그대로 유효.
2. **manifest 재배치 시 언락 재계산**: 매니페스트 순서가 바뀌면 "다음/언락"이 바뀌지만 cleared 데이터는 보존 → 진행도 손실 0(언락만 재도출). 의도된 동작(테스트로 단언).
3. **미저작 placeholder 씬**: manifest에 등재됐으나 `StageNN.tscn` 파일 부재 → published에서 제외(SceneFlow fail-closed) + StageSelect는 ComingSoon 표시. load 시도해도 `load()` null 가드(기존)로 보호.
4. **빈 챕터 / 챕터 경계**: Ch5=[9] 같은 1-스테이지 챕터, 또는 향후 일시적 빈 챕터 — is_chapter_unlocked가 빈 챕터를 skip해 직전 비어있지 않은 챕터의 last로 거슬러 판단(데드 게이트 방지).
5. **중복 씬 id**: is_valid가 전역 중복 거부 → 한 씬이 두 챕터에 노출되는 모순 차단.
6. **autoload 순서**: Campaign는 SaveData/EventBus 이후 로드(의존). project.godot autoload 순서 명시.
7. **fail-closed 일관성**: manifest 누락/무효 → published 비움 + LAST_STAGE_ID=0 + 캠페인 닫힘(미공개 노출 < 닫힘). 기존 SceneFlow 정책 계승.
8. **dev stage(910~)**: manifest 미등재 → 자연 제외(기존 동작 유지, SceneFlow 직접 load_stage만).

## 완료 기준
- 신규/갱신 테스트 전부 PASS + 큐레이트 회귀 0.
- 게임 부팅 → MainMenu → ChapterSelect(5챕터, Ch1만 열림) → StageSelect(Ch1=[1,2]) → Stage1 클리어 → Next로 Stage2 → … 챕터 경계 넘어 진행 가능(수동 1회 verify).
- 매니페스트 배열 순서를 바꾸면 Next/언락이 따라 바뀜을 테스트로 실증(재배치 기능 작동 증명).
- Phase 완료 직전 `/codex:adversarial-review` → verdict clean. Notion 상태 완료.

## 비범위 (이 Phase 아님)
- 신규 스테이지 *콘텐츠 저작*(B1부터). 본 Phase는 골격만 — 기존 9씬으로 흐름 검증.
- 카메라 follow/스크롤, 챕터별 BGM, 경사 램프(설계 §1 결정).
- 50슬롯 일괄 채움 — manifest는 등재된 만큼만 노출(점진 확장).
