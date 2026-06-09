# Phase A (campaign-infra) — Impl Stage Adversarial Review

> 정책: CLAUDE.md impl stage — CRITICAL/HIGH 1건이라도 나오면 반드시 수정(defer 금지).
> codex 재리뷰 전 **자체 적대적 리뷰 사이클**(impl stage 한정)을 clean(HIGH 0)까지 돌린 뒤 codex 실행.
> codex 정식 리뷰 = 사용자가 `/codex:adversarial-review` 입력(모델 직접 트리거 불가).

## Self-Review Round 1 (2026-06-09)

자체 적대적 리뷰(codex 동일 기준: CRITICAL/HIGH/MEDIUM/LOW + hypothetical + cross-doc + dead branch + signal arity 등).

### [HIGH-S1] PauseMenu 0-인자 핸들러가 1-인자가 된 request_stage_select에 직접 연결 — 런타임 에러 + 메뉴 미닫힘
- `scripts/ui/PauseMenu.gd:52` `EventBus.request_stage_select.connect(_force_hide)`. campaign-50에서 `request_stage_select`가 `(chapter: int)` 시그널이 되었는데 `_force_hide()`는 0-인자 → Godot 4는 emit 시 `Method expected 0 argument(s), but called with 1` 에러를 내고 콜백을 **호출하지 않는다**. 결과: ChapterSelect→StageSelect 진입마다 에러 스팸 + PauseMenu가 강제로 닫히지 않아 새 화면 위 잔존(실제 동작 버그). 같은 파일 line 53-55가 `request_play_stage`에 대해 이미 동일 문제를 래퍼로 우회하고 있었음 — 회귀 패턴 일치.
- **실증**: `SceneFlowChapterFlowTest`에서 `request_stage_select.emit(2)` 시 stderr에 `ERROR: Error calling from signal 'request_stage_select' to callable: 'PauseMenu.gd::_force_hide': Method expected 0 argument(s), but called with 1` 확인(테스트는 screen state만 봐서 PASS였으나 에러는 발생).
- **수정**: `_on_request_stage_select(_chapter: int)` 래퍼 추가 + `request_stage_select.connect(_on_request_stage_select)`로 교체. 신규 0-인자 `request_chapter_select`는 `_force_hide`에 직접 연결(arity 일치). 재실행 시 에러 소멸 + `PauseMenuSmokeTest`/`test_PauseMenu`/`PauseStageFreezeOrthogonalityTest`/`SceneFlowChapterFlowTest` 전부 PASS.

### 검토했으나 HIGH 아님(기록)
- **ScreenState enum 중간 삽입**(CHAPTER_SELECT를 MAIN_MENU와 STAGE_SELECT 사이) → STAGE_SELECT(2→3)/STAGE(3→4) 정수값 변동. grep 결과 전 호출부가 symbolic(`sf.ScreenState.STAGE_SELECT`)이고 정수 리터럴 비교 0 + ScreenState 영속화 0 → 안전.
- **next_unlocked_stage → Play가 씬 없는 stage를 가리킬 가능성**: Campaign은 씬 존재를 모름(SceneFlow가 published 게이트). 미저작 stage면 `request_play_stage`가 fail-closed(push_error + no-op). Phase A는 10씬 전부 존재 → 미발생. 향후 ComingSoon 중간 stage 도입 시 재검토(B+). 크래시 0이라 HIGH 아님.
- **CampaignManifest.last_stage_id(등재 기준) vs SceneFlow.LAST_STAGE_ID(published 기준) 발산 가능성**: 마지막 stage 씬 부재 시 갈림. 현재 전부 존재 → 동일(GameFlowTest 3자 수렴 가드가 단언). last-stage UI는 LAST_STAGE_ID(published) 기준이라 UX 정확. HIGH 아님.
- **ChapterSelect headless quit 시 "2 resources still in use"**: CButton.boop tween in-flight 종료 아티팩트(기존 다수 UI 테스트 동일). 비치명·테스트 한정.

### MEDIUM/LOW (defer 가능 — 비치명 stale 주석)
- `scripts/core/Strings.gd:130` 주석에 `menu_layout.tres` 잔존(폐기된 파일). 비기능 주석. TDD guard(test_Strings 스텁 부재)로 즉시 편집 차단 — `phase01-deferred.md` 후보.
- `scripts/ui/atoms/StageSlotCard.gd:18` 주석 "menu_layout.tres slot의 display_name"(caller 미설정으로 의미 이동). 비기능. TDD guard 차단.

→ **Self-Review Round 1 verdict: HIGH-S1 수정 후 clean (HIGH 0).** 회귀 스윕 24종+ 전부 PASS.

### 검증 (자체 리뷰 시점)
- verify 6종 ALL PASS: CampaignManifestTest / CampaignUnlockOrderTest / SceneFlowChapterFlowTest / ChapterSelectFlowTest / GameFlowTest(수렴+A·B·C) / CampaignS1ClearTest.
- 회귀: StageSelectUnlock / StageSelectStars / SceneFlowStageScan / SceneFlowScreenState / SceneFlowSwapNoStaleEmit / SceneFlowLastStagePredicate / MainMenuNav / MainMenuContinueGuard / SceneFlowEmitContract / SceneFlowBootBypass / Bgm SceneFlow / Pause 3종 / StageDialog Esc·LastStageTitle / ComingSoon / Esc / Save 4종 / StageGuideControllerPresence(10) / StageSlotCardState / StringsTable / TitleSceneInput — 전부 PASS.

→ 자체 리뷰 clean → codex 정식 impl-stage 리뷰 진행(아래 Round 1).

## Round 1 (정식 — codex /adversarial-review, working-tree, 2026-06-09)

**verdict: needs-attention** — MEDIUM 1, CRITICAL 0, **HIGH 0**.

- **[MEDIUM]** Published-stage 캐시가 라이브 Campaign 매니페스트와 발산 가능 (`SceneFlow.gd:36-63`). `ensure_stage_scan()`이 `PUBLISHED_STAGE_IDS`/`LAST_STAGE_ID`를 **별도 `ResourceLoader.load(MANIFEST_PATH)`**로 1회 스냅샷하는데, 이후 네비게이션은 `Campaign.next_stage_id()`/Campaign autoload 언락을 쓴다 → 매니페스트 reload/`_test_set_manifest` 후 `load_next_stage()`가 한 매니페스트로 next를 계산하고 stale `PUBLISHED`로 거부하거나 stale `LAST_STAGE_ID`를 노출하는 split-brain. 매니페스트=단일 SoT 재배치 워크플로우가 단일 진리원에 의존.
  - 권고: published/next/last를 한 매니페스트 스냅샷으로 통일. `ensure_stage_scan()`을 `Campaign.manifest()` 경유로 + `Campaign._load_manifest()`/`_test_set_manifest()`가 호출하는 invalidation/re-scan 추가, 또는 매니페스트 파생 static 캐시 제거.

> 정책: impl stage는 verdict clean(needs-attention 해소)까지 수정·재리뷰. MEDIUM이지만 **매니페스트=단일 SoT라는 설계 핵심 보증을 직접 훼손**하는 구조적 결함(자체 R1에서 "두 로드 경로"로 인지했으나 production 무발생으로 과소평가) → **수정**(defer 아님).

### Round 1 대응 (수정 완료, 2026-06-09) — codex 권고 채택
- `SceneFlow.ensure_stage_scan`: `ResourceLoader.load(MANIFEST_PATH)` → **`Campaign.manifest()` 단일 소스**(autoload가 보유한 *그* 인스턴스). `MANIFEST_PATH` const 제거(경로 소유권은 Campaign).
- `SceneFlow.invalidate_stage_scan()` static 추가(`_stage_scan_done=false` 토글만 — 비재귀).
- `SceneFlow.load_next_stage`: 선두에서 `ensure_stage_scan()` 호출 → next_stage_id와 PUBLISHED 게이트가 *같은* 스냅샷.
- `Campaign._load_manifest`/`_test_set_manifest`: 끝에서 `SceneFlow.invalidate_stage_scan()` 호출 → 매니페스트 (재)설정이 다음 스캔에 즉시 반영.
- **회귀 테스트 추가**(codex Next steps): `SceneFlowChapterFlowTest` 케이스(6) — 스캔 이후 `_test_set_manifest([2,1])` 재배치 → `LAST_STAGE_ID==1` + `load_next(2)→1` 단언(stale 스냅샷 split-brain 없음).

## Self-Review Round 2 (수정 후, 2026-06-09)
단일 SoT 수정에 대한 자체 적대적 리뷰.
- **순환 호출 검토**: SceneFlow.ensure_stage_scan→Campaign.manifest()(읽기, SceneFlow 미호출), Campaign._load_manifest/_test_set_manifest→SceneFlow.invalidate_stage_scan(bool 토글, Campaign 미호출). invalidate는 ensure를 부르지 않음 → **무한재귀/사이클 0**.
- **init 순서**: Campaign._ready→_load_manifest→SceneFlow.invalidate_stage_scan(class_name static, 인스턴스 불요). SceneFlow static var는 전부 리터럴(엔진 싱글톤 미접근) → Campaign._ready 시점 SceneFlow 참조 안전. ensure_stage_scan은 항상 autoload 이후 진입점에서만 호출(MainMenu standalone 포함 Campaign 가용).
- **dangling**: `MANIFEST_PATH`는 Campaign.gd 자신만 보유(SceneFlow 참조 0, grep 확인).
- **fail-closed 보존**: Campaign.manifest() null/무효 → published 비움 + push_error(기존과 동일).
- **회귀 스윕**: SceneFlow 계열 + Save/Stage/Pause/Bgm 17종 재실행 ALL PASS, 시그널/파스 에러 0.

→ **Self-Review Round 2 verdict: clean (HIGH 0).**

## Round 2 (정식 — codex /adversarial-review, working-tree, 2026-06-09)

**verdict: approve** — material findings 0, ship-blocking defect 0.

> "The signal arity migration, manifest-based published gate, chapter routing, and deleted MenuLayout callers appear consistently updated from the inspected diff and repository search. No material findings."
> Next steps: 병합 전 Godot verify suite 실행(권고) — **이 working tree에서 verify 6종 ALL PASS 확인 완료**.

→ **impl-stage 리뷰 루프 종결 (codex approve = clean).** verify 6종 최종 ALL PASS. 다음 = `execute.py complete 1` + 커밋(`phase A`/conventional). campaign-50은 Notion 매핑 없음(동기화 스킵).
