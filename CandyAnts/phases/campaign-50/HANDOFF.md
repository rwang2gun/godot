# campaign-50 — 세션 핸드오프 (2026-06-10)

> **다음 세션 재개 SoT.** 5챕터×10=50스테이지 캠페인 재설계. **Phase A(인프라) 완료**(`e704b0e`) · **Phase B1(ch1-front) 콘텐츠 완성·커밋**(stage11 `0af3192` + stage12~14·발행 `73d4da7`).

## 0.1 한 줄 상태 (2026-06-10 — Phase B1 콘텐츠 완성)
브랜치 `campaign-50-ch1-front`. **신규 스테이지 11~14 전부 저작 + 매니페스트 Ch1 `[1,11,12,13,14,2]` 발행 + Strings + 가드 2종(StageIdentity/ClearedPreservation) + 회귀 갱신 5종.** verify 14종 + 인접 회귀 ALL PASS. **다음 = ①사용자 수동 검증(인게임 Ch1 slot2~5 플레이) → ②`/codex:adversarial-review`(사용자 트리거) → ③`execute.py campaign-50 complete 2`.** B1 명시 defer: stage02 이름 rename("오르막")은 B2(plan MEDIUM-2).
- **코어 발견(레벨 저작 규칙 추가)**: ①Home은 *좌향 빈손* 개미를 흡수→3s 후 spawn_direction으로 재방출(respawn 펌프) ②candy 픽업 시 자동 `flip()` → **candy를 home 너머(역방향)에 두는 배치 불가**. 해법 = **spawn≠home 패턴**(AntSpawner.spawn_position은 씬 독립): 무리를 home·candy *오른쪽*에서 출발시켜 blocker 반전으로 candy 유도. S12/S13/S14 전부 이 패턴.
- **플랜 선식별 누락 회귀 2건**: ChapterSelectFlowTest(Ch1 전체클리어 케이스)·MainMenuNavTest(next_unlocked=11) — 라이브 매니페스트 하드코딩은 C-1/C-2/H-1 외에도 존재했음. 갱신 완료.
- **Ch1 파라미터 고정 지침 (사용자 결정 2026-06-10, 설계 §2.2)**: candy_hp=5 고정 + total_ants=5+영구 소비 설치물 수(여분 0) + 소비형 인벤토리=필요 수 그대로. S11~S14 적용·재검증 완료(클리어=5/5). **stage01(total 8)·stage02(total 7) 정합화는 B2 sweep**(rename과 동일 묶음).
- **Ch1 스킬 역할 렌즈 (사용자 방향, 2026-06-10 논의)**: 위험 돌파=blocker(수평 격리)·floater(수직 하강) / **climber=구한 사탕을 들고 올라오는 회수 도구**. 원형 2종 — 하강 진입형(분지: 진입 공짜·귀환 climber, S1·S13) vs 상승 진입형(메사: 진입 climber·귀환 floater, S2·S14). B2 저작 시 이 문법 적용(설계 문서 박제는 B2 착수 전 후보).

## 0.2 (구) 한 줄 상태 (2026-06-09 — Phase A 완료·커밋)
브랜치 `campaign-50`. **Phase A(campaign-infra) 완료 + 커밋 `e704b0e phase 1: campaign-infra`.** plan stage 리뷰 종결(Round 2 HIGH 0) + impl stage 리뷰 종결(**codex Round 2 verdict=approve**, 자체리뷰 2라운드 clean — `reviews/phase01-impl-review.md`). verify 6종 + 회귀 24종+ ALL PASS. **다음 = 신규 스테이지 콘텐츠 저작(Phase B1~): `Stage%02d.tscn` 작성 + `campaign_manifest.tres` 챕터 `stage_ids`에 append.** Phase B+ 정의는 metadata에 추가 필요(현재 phase 1만). 설계 SoT=`docs/CAMPAIGN_50_DESIGN.md`.

### Phase A 인프라 (커밋됨 — 재사용 진입점/규약)
- **매니페스트 SoT**: `data/campaign_manifest.tres`(`CampaignManifest`). 재배치·챕터배치 = 배열 편집. 파생/언락=`Campaign` autoload.
- **SceneFlow 규약**: published/LAST/Next는 **반드시 `Campaign.manifest()` 단일 SoT** 경유(별도 ResourceLoader 두 번 로드 금지 — split-brain, codex impl R1 MED). 매니페스트 변경 시 `Campaign`이 `SceneFlow.invalidate_stage_scan()` 호출.
- **UI 흐름**: MainMenu→ChapterSelect(`scenes/ui/ChapterSelect.tscn`)→StageSelect(챕터별 슬롯)→Stage.
- **시그널**: `request_chapter_select`(0-arg) / `request_stage_select(chapter:int)`. 1-arg 시그널은 PauseMenu 등에서 0-arg 핸들러 직접 연결 금지(arity 에러 — 인자흡수 래퍼 사용).
- **함정**: 신규 `class_name` 추가/삭제 후 `--headless --editor --quit`로 클래스 캐시 재생성([[godot-class-cache-regen]]).

### 구현 요약 (working tree, 2026-06-09)
- `EventBus.gd`: `request_chapter_select`(0-arg) 신설 + `request_stage_select(chapter:int)`로 시그니처 변경.
- `SceneFlow.gd`: published/LAST_STAGE_ID/load_next를 menu_layout→**CampaignManifest**로 교체(static은 ResourceLoader 직접 로드, load_next는 `Campaign.next_stage_id`). `ScreenState.CHAPTER_SELECT`(중간 삽입 — 전부 symbolic 참조라 안전) + `go_to_chapter_select`/`go_to_stage_select(chapter)`(인스턴스에 current_chapter 주입) + 핸들러 2종.
- `ChapterSelect.{gd,tscn}` 신설(5 챕터 카드 LOCKED/PLAYABLE/CLEARED, `chapter_state()` 테스트 시ーム).
- `StageSelect.gd`: `current_chapter` + `Campaign.stage_ids_in_chapter`, Campaign 언락 기반 슬롯, Back/ESC→`request_chapter_select`, Title=챕터명. display_name 슬롯소스 제거.
- `MainMenu.gd`: Play→`Campaign.next_unlocked_stage()`, StageSelectBtn→`request_chapter_select`, Continue 가드→`Campaign.is_stage_unlocked`.
- `Campaign.gd`: `is_chapter_unlocked` 1-based 가드(`<1`/`>count` 거부 — codex R2 MED-1).
- `PauseMenu.gd`: `request_stage_select`를 인자흡수 래퍼(`_on_request_stage_select`)로 연결(HIGH-S1 fix) + `request_chapter_select`→`_force_hide`.
- 삭제(git rm): `MenuLayout.gd(.uid)` · `data/menu_layout.tres` · `MenuLayoutResourceTest.{gd,uid,tscn}`.
- 테스트 신규: `CampaignUnlockOrderTest`·`SceneFlowChapterFlowTest`·`ChapterSelectFlowTest`(+기존 `CampaignManifestTest`). 갱신: `GameFlowTest`(3자 수렴 수용검사)·`StageSelectUnlockTest`(챕터화 재작성)·`SceneFlowStageScanTest`/`SceneFlowScreenStateTest`/`BgmSceneFlowTest`/`MainMenuNavTest`(시그니처·라우팅).
- 문서: `ADR-014`(매니페스트) · `DOMAIN_MAP §3.0`(매니페스트 인덱스 + Stage10 행 + menu_layout 참조 제거) · 플랜/리뷰 로그 갱신.
- **환경 함정**: 신규 `class_name`(ChapterSelect) 추가 + MenuLayout 삭제 후 `--headless --editor --quit`로 `.godot/global_script_class_cache.cfg` 재생성 필수(안 하면 "Could not find type" 파스에러로 줄줄이 fail). 잔여 stale 주석 2건(Strings.gd:130 / StageSlotCard.gd:18 menu_layout) = TDD guard로 즉시편집 차단 → deferred 후보.

## 1. 확정 설계 (docs/CAMPAIGN_50_DESIGN.md — SoT)
- 5챕터×10스테이지. 스킬 3+3+2+2 누적 언락: Ch1 climber/blocker/floater · Ch2 bridge/builder/sand_mound · Ch3 basher/digger · Ch4 cutter/leaf_jump(여기서 10종 학습완성) · Ch5 신규0·종합.
- 상위 챕터는 하위 스킬 누적 사용. 복층: 새 코어 없이 데이터 저작(§2.5), 수직어휘 챕터별 성장, **Ch1 복층=계단식 열린단만**. 여백 구간=water(§2.2.1).
- **캠페인 매니페스트(§5.0)**: 캠페인 순서/챕터배치 ↔ 씬id 분리. 재배치=배열 편집(파일 rename 0). → 기존 S1~S10 재번호 불필요(§4).
- 9개 확정 결정은 설계 §1.

## 2. 실제 캠페인 = 10스테이지 (DOMAIN_MAP/§0.6 표는 stale)
| id | 이름 | 스킬 | 배치 챕터 |
|---|---|---|---|
| 1 첫 나들이 | climber | Ch1 |
| 2 절벽 아래로 | climber+floater+blocker | Ch1 |
| 3 웅덩이 넘기 | bridge | Ch2 |
| 4 높은 곳에 닿으려면 | builder | Ch2 |
| 5 과자 사다리 | sand_mound+floater | Ch2 |
| 6 숨겨진 사탕 | digger+climber | Ch3 |
| 7 벽 너머로 | basher | Ch3 |
| 8 귀찮은 식물들 | cutter+leaf_jump | Ch4 |
| 9 고지로! | bridge+basher+blocker+sand_mound | Ch5 |
| 10 보물찾기! | builder+digger+cutter+leaf_jump+climber | Ch5 |
- 초기 매니페스트 `[1,2][3,4,5][6,7][8][9,10]` → 전역 순서 [1..10] 보존, LAST_STAGE_ID=10(GameFlowTest 일치), 회귀 최소.

## 3. Phase A 플랜 (phases/campaign-50/phase01-campaign-infra.md)
범위: CampaignManifest + Campaign autoload + SceneFlow(published/Next/CHAPTER_SELECT) + ChapterSelect 화면 + StageSelect/MainMenu 챕터화 + menu_layout 폐기 + ADR-014. **신규 스테이지 콘텐츠 저작 없음**(B1부터).

### 이미 작성된 스캐폴딩 (working tree)
- `scripts/core/CampaignManifest.gd` — 리소스+헬퍼(ordered/chapter_of/next/position/first/last, is_valid). **1-based 챕터 번호**, sid<=0 거부(codex MED-2).
- `data/campaign_manifest.tres` — 5챕터 초기 데이터.
- `scripts/core/Campaign.gd` — autoload, 언락/순서 파생(is_stage_unlocked/is_chapter_unlocked/chapter_stars/next_unlocked_stage). `_test_set_manifest` seam.
- `project.godot` — `Campaign` autoload 등록(SaveData 뒤).
- `tests/CampaignManifestTest.{gd,tscn}` — is_valid/헬퍼/0·음수 케이스. **⚠ 아직 godot 실행 미검증**(스모크 안 돌림).
- `tests/test_{Campaign,CampaignManifest,ChapterSelect}.gd` — TDD Guard 스텁.

### 아직 안 한 것 (Round 2 clean 후)
- `EventBus.gd`: `request_chapter_select` 시그널 + `request_stage_select`에 chapter(1-based) 인자.
- `SceneFlow.gd`: published=씬∩manifest, LAST_STAGE_ID=manifest 마지막, load_next=manifest.next, `ScreenState.CHAPTER_SELECT`+go_to_chapter_select. (static ensure_stage_scan은 autoload 대신 ResourceLoader로 manifest 직접 로드.)
- `scenes/ui/ChapterSelect.tscn`+`scripts/ui/ChapterSelect.gd` (신규, 5 카드, 1-based).
- `StageSelect.gd`: menu_layout→manifest.stage_ids_in_chapter(현재챕터), Back→ChapterSelect.
- `MainMenu.gd`: Play→Campaign.next_unlocked_stage, StageSelect버튼→request_chapter_select.
- menu_layout 폐기: `MenuLayout.gd`+`data/menu_layout.tres` 삭제, caller/test 이관(StageSelect/SceneFlow/MainMenu/StageSelectUnlockTest/MenuLayoutResourceTest/SceneFlowStageScanTest).
- 신규 테스트: CampaignUnlockOrderTest, SceneFlowChapterFlowTest, ChapterSelectFlowTest. 갱신: GameFlowTest(last=10 수용검사), StageSelectUnlock.
- `docs/ADR.md` ADR-014, `docs/DOMAIN_MAP.md` 매니페스트 인덱스.
- verify: `phase01-campaign-infra.md` frontmatter의 verify 커맨드 6종 PASS.

## 4. 리뷰 상태 (phases/campaign-50/reviews/phase01-plan-review.md)
- **Round 1 (정식 codex /adversarial-review) 완료**: HIGH 2 + MED 2 (CRITICAL 0). **전부 수정 완료**:
  - HIGH-1 last-stage 9→10 + 3자 수렴 수용검사 / HIGH-2 §5.1-5.2 MenuLayout 확장 폐기·caller 전수화 / MED-1 챕터 1-based 계약 / MED-2 is_valid sid<=0 거부.
- **Round 2 대기** = 재리뷰 필요.

## 5. ⚠ 다음 세션 첫 행동
1. `python scripts/execute.py campaign-50 validate` (세션 시작 1회).
2. **Round 2 적대적 리뷰**: codex `/adversarial-review`는 `disable-model-invocation`이라 **모델이 직접 트리거 불가** → **사용자가 슬래시 명령 입력**하면 그 턴에 로드되어 모델이 node companion 백그라운드 실행. (Round 1이 이 방식으로 정상 동작.) 인자는 phase01 리뷰 파일/직전 세션 제안 참조.
   - 지침(CLAUDE.md)엔 "codex 리뷰 불가" 자동 우회 없음. 자체 적대적 리뷰는 **impl stage 한정**(plan stage 미적용, L29). 막히면 **사용자 보고·결정**(L27/L65 메타패턴).
3. Round 2 clean(HIGH 0) → SceneFlow/UI 구현 착수(§3 "아직 안 한 것"). HIGH 잔존 → 수정 후 Round 3(3라운드 cap).
4. **권장**: 구현 전 `CampaignManifestTest` 스모크 1회(아직 미검증). `GODOT_BIN` 지정 필요(메모리 godot-binary-location).

## 6. 환경 노트
- GODOT_BIN: `C:\Users\code1\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe` (run_test.py CANDIDATES 불일치 — 메모리 참조).
- TDD Guard: `scripts/{core,ant,skills,world,ui}/*.gd` 신규/수정 전 `tests/test_<stem>.gd` 존재 필요(스텁 가능).
- codex CLI 0.125.0 설치, companion: `~/.claude/plugins/cache/openai-codex/codex/1.0.4/scripts/codex-companion.mjs`.
- Notion: campaign-50은 notion-phase-ids.json 매핑 없음(동기화 스킵).
