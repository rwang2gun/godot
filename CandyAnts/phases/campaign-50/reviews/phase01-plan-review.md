# Phase A (campaign-infra) — Plan Stage Adversarial Review

> 정책: CLAUDE.md plan stage — CRITICAL/HIGH 발견 시 최대 2회 수정+재리뷰(3라운드 cap).
> 정식 리뷰 = 사용자가 데스크톱 앱에서 `/codex:adversarial-review` 실행(모델은 `disable-model-invocation`이라 직접 호출 불가).

## (비공식) 사전점검 — codex:rescue 경로
`/codex:adversarial-review`(review-only)와 `codex:rescue`(write-capable)는 권한·목적이 달라 동일시 불가 → 이 rescue 출력은 **참고용 사전점검**으로만 둔다. HIGH 5건 보고(last-stage 9→10·챕터 index·menu_layout SoT 등). 정식 Round 1과 대조용.

## Round 1 (정식 — codex /adversarial-review, working-tree, 2026-06-09)

**verdict: needs-attention** — HIGH 2, MEDIUM 2, CRITICAL 0.

- **[HIGH-1]** 플랜이 초기 매니페스트 캠페인 엔드포인트를 잘못 기술 (`phase01-campaign-infra.md:105`). [1..10]·LAST_STAGE_ID=10이라면서 GameFlowTest 갱신은 'last = scene 9'. → Stage10이 published 엔드포인트에서 누락돼 last-stage Next/menu fallback 회귀.
  - 권고: GameFlowTest 'last = scene 10' + `CampaignManifest.last_stage_id()`==`SceneFlow.LAST_STAGE_ID`==`GameFlowTest.LAST_STAGE_ID`==10 수용검사.
- **[HIGH-2]** 설계 §5.0(매니페스트가 menu_layout published 대체) vs §5.1-5.2(MenuLayout 10→50 확장 + stage_id==i+1 + SaveData 선형 헬퍼) 모순 (`CAMPAIGN_50_DESIGN.md:261-276`). stale 산문이 아니라 *캠페인순서==씬id 결합을 재도입* → 하이브리드 출하 위험.
  - 권고: 구 MenuLayout 확장/SaveData 선형 bullet을 §5.0으로 supersede 명시 삭제, menu_layout 이탈 caller/test 전수 나열한 단일 매니페스트 경로로 교체.
- **[MEDIUM-1]** 챕터 index 계약이 0-based 플랜 텍스트 vs 1-based 구현 분리 (`phase01-campaign-infra.md:56-57`). ChapterSelect가 0을 넘기면 첫 챕터가 언락처럼 보이나 stage_ids_in_chapter(0)=빈 결과 → 진입점 빈 상태 회귀.
  - 권고: 전 공개 API 1-based 통일, 0=not-found 전용. 챕터1 선택→StageSelect [1,2] 렌더 테스트.
- **[MEDIUM-2]** `CampaignManifest.is_valid`가 0/음수 씬 id 허용 (`CampaignManifest.gd:30-35`). 0은 API 전역 not-found sentinel → 충돌. 0 포함 매니페스트가 first_stage_id 등으로 흘러듦.
  - 권고: sid<=0 거부 + 0/음수 테스트 케이스.

### Round 1 대응 (수정 완료, 2026-06-09)
- **HIGH-1** → 플랜 §테스트 갱신: "last = 씬 10" + 3자 수렴(=10) 수용검사 추가.
- **HIGH-2** → 설계 §5.1-5.2 전면 재작성: 구 MenuLayout 확장·SaveData 선형 폐기 배너 + menu_layout 이탈 caller/test 전수(SceneFlow/StageSelect/MainMenu/StageSelectUnlock/MenuLayoutResource/SceneFlowStageScan) 단일 경로화.
- **MEDIUM-1** → 플랜 §2 챕터 번호 계약 1-based 명시(0=not-found), ChapterSelect 0 미전달 가드 테스트 요구.
- **MEDIUM-2** → `CampaignManifest.is_valid`에 `sid <= 0` 거부 추가 + `CampaignManifestTest`에 0·음수 케이스 추가.

→ **Round 2 재리뷰 대기** (사용자가 `/codex:adversarial-review` 재실행). clean(HIGH 0) 시 구현 재개.

## Round 2 (정식 — codex /adversarial-review, working-tree, 2026-06-09)

**verdict: needs-attention** — MEDIUM 2, CRITICAL 0, **HIGH 0**.

> 정책(CLAUDE.md plan stage): CRITICAL/HIGH 0이고 MEDIUM/LOW만 남으면 어느 라운드에서든 plan 내 처리 또는 명시 defer로 **종결**. → Round 2에서 HIGH 0 = **plan stage 적대적 리뷰 루프 종결**(Round 3 불요). 남은 MEDIUM 2건은 아래대로 닫음.

- **[MEDIUM-1]** `Campaign.is_chapter_unlocked()`가 `chapter_num <= 1`이라 챕터 0/음수도 unlocked 처리 (`Campaign.gd:61-70`). 1-based 계약(0=not-found)에 위배 — 0-based 인덱스가 새면 `stage_ids_in_chapter(0)`=빈 결과로 빈 StageSelect 회귀.
  - 권고: `chapter_num < 1` 및 `> chapter_count()` 거부 후 챕터1 특례. `is_chapter_unlocked(0)==false` + 챕터1 여전히 언락 회귀.
- **[MEDIUM-2]** Phase verify 커맨드가 미존재 테스트 씬 참조 (`phase01-campaign-infra.md:4`) — `CampaignUnlockOrderTest/SceneFlowChapterFlowTest/ChapterSelectFlowTest.tscn` 부재로 verify 실패.
  - 권고: 씬 작성 후 verify 유지 또는 작성 전까지 verify에서 제외.

### Round 2 대응 (2026-06-09)
- **MEDIUM-1 → 즉시 수정 완료**: `Campaign.is_chapter_unlocked`에 `chapter_num < 1 or > _manifest.chapter_count()` fail-closed 거부 추가, 챕터1 특례는 `== 1`로 좁힘. 매니페스트 헬퍼(`stage_ids_in_chapter`/`chapter_title`/`chapter_theme`)는 이미 동일 가드 보유 → 일관. `CampaignUnlockOrderTest`에 `is_chapter_unlocked(0)==false`·음수·`>count` 거부 + 챕터1 언락 회귀 케이스 추가(구현 단계).
- **MEDIUM-2 → 의도된 plan-stage 상태(defer 아님, 구현 단계 해소)**: 해당 3 테스트 씬은 본 Phase A *구현 산출물*이며 완료 기준(§완료 기준·테스트 계획 "신규")에 포함. plan stage엔 아직 미작성이 정상 — 구현 중 작성되면 verify 통과. verify frontmatter는 불변 유지(완료 시점 계약).

→ **plan stage 종결.** 다음 = Phase A 구현 착수(SceneFlow/EventBus/ChapterSelect UI + 신규/갱신 테스트).
