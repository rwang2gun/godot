---
name: input-mode-polish
duration_estimate: 7200
verify: python scripts/run_test.py tests/GuideInputModeCopyTest.tscn && python scripts/run_test.py tests/OnboardingIntegrationTest.tscn && python scripts/run_test.py tests/StageIntroCardFallbackTest.tscn
large_change_ok: false
sot: docs/STAGE_GUIDE_PLAN.md
sot_aux: [scripts/ui/InputHintLabel.gd, scripts/core/Strings.gd, phases/new-user-onboarding/REVISION_2026-06-07-new-user-onboarding.md]
---

# Phase 6: input-mode-polish (재조정 — 통합회귀 + 정합검증 + SoT 정합화)

## 재조정 배경 (2026-06-07, 사용자 승인 Option A · codex plan R1 반영)
원 스펙은 "카드 조작 카피를 입력모드별 **동적 분기**" + "카드 입력모델 배지 ↔ 인게임 글로우/커서
**시각 어휘 정합**"을 목표로 했고, 그 권위는 STAGE_GUIDE_PLAN §2.6 / §0.8 / §2 / §3.2였다.
그 사이 **가이드 카드가 페이지네이션+스크린샷 구조로 전면 개편**(`d2987b2`/`c60ed20`)되며 전제가
깨졌다. 실측:
- **S1~S8 전부 페이징 경로**(`stageNN_guide.tres`의 `pages` non-empty). 페이징 `_render_page`는
  제목+본문만 그리고 **입력모델 배지 칩을 표시하지 않는다** → SoT가 §2 L146/§3.2 L206에서 요구하는
  "각 스킬 칩에 입력모델 배지" 메커니즘이 카드에서 사라짐.
- 페이징 카드 본문(`page_*_body`)은 이미 **모드 중립 카피**("주면/사용하면/표지판을 세워두면").
- "탭"이 박힌 카피(`guide.badge.*`/`guide.sN.*_desc`)는 **단일 카드 경로(`_build_skill_row`)** 와
  inspector 전용. 단일 카드 경로는 `guide.pages.is_empty()`일 때만 도는 캠페인 **미사용** 경로.
- 인게임 조작 힌트는 `InputHintLabel`+`hint.mouse/pad/touch`로 **이미 모드 분기 완료**(Phase 8).

**codex plan R1 HIGH**: re-scope가 SoT를 갱신하지 않은 채 "superseded"라 선언 → 순환 증명(문서는
여전히 배지/카피를 요구하는데 phase는 green). **해소**: SoT(§2.6/§0.8/§2/§3.2) + REVISION 갱신을
**게이팅 수용 기준**으로 올린다(§아래 0절). 사용자는 Option A에서 **카드 배지 은퇴**를 명시 선택
(Option B "배지 재도입" 기각) — 본 phase는 그 결정을 SoT에 박제할 뿐 새 결정을 만들지 않는다.

따라서 본 phase = **(0) SoT 정합화(게이팅) + (1) 온보딩 통합 회귀 안전망 + (2) 어포던스 시각 어휘
Tokens/카테고리 SoT 고정 + (3) 죽은 단일카드 경로를 "지원되는 fallback"으로 소유**.

## 0. SoT 정합화 (★게이팅 — 테스트보다 먼저, 수용의 전제)
아래 문서 편집이 **완료·정확해야** GuideInputModeCopyTest/OnboardingIntegrationTest의 green이
"수용"으로 인정된다. (codex R1-HIGH)

**신 불변식(restate, STAGE_GUIDE_PLAN §2.6.1로 신설):**
> 입력모델(③무장/②정착/①푯말/④장치)은 두 채널이 가르친다 — (a) **페이징 인트로 카드**의
> 스크린샷+모드 중립 본문이 "어디에 무엇을 하는지"를 시각적으로 보여주고, (b) **인게임 어포던스**
> (글로우 대상 + 커서 모양)가 스킬 선택 시 상시 재확인한다. **조작 동사의 모드 분기**(클릭/탭/A버튼)는
> 인게임 `InputHintLabel`(`hint.*`)이 단독 책임진다. 인트로 카드 본문은 모드 중립이다.
> §2 초안의 "스킬 칩 입력모델 배지 칩"과 §2.6 초안의 "카드 조작 카피 모드 분기"는 페이지네이션
> 개편으로 **은퇴**한다. 배지 키(`guide.badge.*`)/카테고리 매핑은 inspector·legacy 단일카드 경로에만
> 잔존하며 모드 중립 카피로 유지된다. **단일카드 렌더 경로(스킬 칩)는 legacy·non-user-facing**이다 —
> 모든 캠페인 `stageNN_guide.tres`는 `pages` 저작이 필수이며(가드로 강제), guide==null인 경우는
> placeholder 본문(스킬 카피 0)만 보인다. 즉 어떤 사용자도 단일카드 스킬 카피에 도달하지 않는다.

**편집 대상(전부 게이팅):**
- `docs/STAGE_GUIDE_PLAN.md`: §2.6에 위 불변식을 §2.6.1로 추가 + §2.6 기존 "조작 카피 분기" 줄을
  "인게임 hint가 담당"으로 정정. §0.8(L83 "카드 배지와 같은 시각 어휘")·§2(L146 스킬 칩 배지)·
  §3.2(L206 "배지로 명시")에 **각 1줄 supersession 마커**(`→ §2.6.1 은퇴`) 삽입(원문 보존+마커).
- `phases/new-user-onboarding/REVISION_*.md` §6: phase 6 항목에 Option A 재조정 + 배지/카피 은퇴 박제.

## 범위 밖 (Deferred / Superseded)
- 카드 본문 조작 카피 모드 분기 — superseded(§2.6.1). 재도입 안 함.
- 카드 입력모델 배지 칩 재도입(Option B) — 사용자 기각. 배지 학습은 (a)스크린샷 (b)인게임 어포던스가 대체.
- `guide.sN.*_desc`의 "탭하면" 동사 모드 중립화 — **불요**(codex R2-M1 반영). 단일카드 경로를
  legacy·non-user-facing로 재분류 + "모든 캠페인 guide는 pages 필수" 가드로 **출하 콘텐츠에서 도달
  불가**가 됨 → desc는 어떤 사용자에게도 렌더되지 않음(inspector·테스트 전용). 따라서 stale 동사
  drift trap이 소멸(=defer 잔여 아님). desc 10문장 재작성 비용 회피.

## 변경 대상 (코드 변경 최소 — 문서·테스트 위주)
- **(0절 문서 편집 — 게이팅, 위 참조.)**
- `scripts/core/Strings.gd`: `guide.badge.{ant_armed,ant_settle,sign,device}` 4키를 **모드 중립**으로
  교정("개미 탭 → …" → "개미 선택 → …", "땅 탭 → …" → "땅 선택 → …"). render 테스트는 배지를
  `Strings.t(_BADGE_KEYS[cat])` 동일 소스와 대조(StageGuideDataRenderTest L67) → 값 변경 무파손 확인됨.
- `tests/GuideInputModeCopyTest.{gd,tscn}` (신규):
  - (a) `EventBus.input_mode_changed`로 `mouse`/`pad`/`touch` 구동 → `InputHintLabel.text`가 각
    `Strings.t("hint.mouse"/"hint.pad"/"hint.touch")`와 일치 + 3 카피 상호 상이.
  - (b) **어포던스 어휘 고정**: `AffordanceGlowController.ANT_GLOW_COLOR == Tokens.GRAPE_700`,
    `SURFACE_GLOW_COLOR == Tokens.MINT_500`(하드코딩 색 회귀 가드). 글로우 타깃이
    `SkillAffordance.glow_target_of`(카테고리 파생, 4 카테고리 대표 스킬)로 결정됨을 단언.
  - (c) **배지 드리프트 가드**: `guide.badge.*` 4키가 `_BADGE_KEYS` 카테고리 매핑과 1:1 존재 + 모드
    중립(어떤 키도 "클릭"/"A 버튼"/"탭" 모드 동사를 포함하지 않음) 단언.
- `tests/OnboardingIntegrationTest.{gd,tscn}` (신규 — **실씬 seam 통합**, codex R1-MEDIUM 반영):
  - 실제 `Stage01.tscn` instantiate(`auto_begin=false`=카드 대기) + 실제 `StageIntroCard` instantiate +
    **SceneFlow 배선 모사**로 `card.intro_dismissed → stage.begin` connect.
  - 카드 구동: `show_intro(stage.stage_data)` → `page_count()==3` → `_on_next_pressed`로
    `current_page()` 진행 → dismiss → `intro_dismissed` 1회 emit → **`stage.is_begun()` true + 실제
    개미 스폰**(begin 시그널 체인 입증).
  - 어포던스: `AffordanceGlowController`를 실제 stage의 toolbar·terrain에 연결, climber 선택
    (`_pending_skill_id`) → 실제 스폰 개미에 `eligible_ants("climber").size() > 0` + 글로우 메타 적용 →
    적격 개미에 `ClimberSkill.apply` 1회 → **trait 획득**(climber는 상태 전이 아닌 trait 기반:
    `has_trait("climber")` true + 적격성 소멸 `can_apply==false`) 단언.
  - **커버리지 경계 명시(주석)**: 부트 시 카드 auto-show 경로는 헤드리스 스킵(별도 커버:
    `StageIntroCardHeadlessSkipTest`) + begin 게이트 멱등은 `StageRunnerBeginGateTest`가 실씬 커버.
    본 테스트는 그 사이 **dismiss→begin→어포던스→스킬** seam을 실 노드로 묶는다(컴포넌트 직접 호출
    아님). 미커버: 실 입력 디바이스 이벤트 경로(InputModeTracker는 GuideInputModeCopyTest가 시그널로 커버).
- `tests/StageIntroCardFallbackTest.{gd,tscn}` (신규 — M2: legacy 경로 도달불가 보장 + 안전 degraded 잠금):
  - (a) **출하 콘텐츠 가드(핵심)**: `SceneFlow.PUBLISHED_STAGE_IDS`(캠페인 SoT) 파생. 불변식:
    명시 allowlist(`_GUIDELESS_ALLOWLIST=[9]`, REVISION §3 — S9 피날레 무가이드)만 guide 부재 허용
    (placeholder), **그 외 published 스테이지는 guide 존재+로드+`pages` non-empty 필수**(guide 누락도
    fail). 신규 published가 guide를 빠뜨리거나 pages 빈 guide를 출하하면 자동 fail(codex impl R2-M2).
  - (b) **user-facing degraded 경로**: guide==null(미저작 stage_data) → `goal_text()`=
    `guide.intro_body_placeholder` + SkillList/HazardList hidden + `shown_skill_ids()` 빈 배열
    (배지/칩 0) → 유일한 사용자 도달 fallback이 카피-free임을 입증.
  - (c) **legacy 경로 regression shape**(non-user-facing): 합성 `StageGuideData`(new_skill_ids 채움,
    `pages` 빈) → 단일카드 렌더 시 SkillList child = new_skill_ids 수 + 배지 텍스트 모드 중립. legacy
    렌더가 깨지지 않음을 가드(사용자 미도달이나 inspector 평행 보장).

## 검증 방법
- 3 신규 테스트 PASS (`run_test.py`, 풀프로젝트 부트).
- **통합 회귀(큐레이트 세트)**: S1~S9 Clear + 대표 neg(NoClimber/NoBridge/NoBuilder/NoDigger/
  NoBasher/NoCutter) + GameFlow + SceneFlow + 어포던스 스위트(TapTargetGlow*/CursorKind*/
  SkillAffordanceCategory) + 카드 스위트(StageGuideDataRender/StageIntroCardShow/StringsTable) green.
- **선재 red 동일성 기준**: memory 기준 full-suite 선재 실패(ClimberTrait mantle 경계 /
  DiggerFallThroughUpperAnt / DistributorSettle / FloaterTrait D3) + GameFlow ScenB(S9) 가능성은 본
  변경과 무관 — **변경 전/후 동일 결과면 회귀 아님**(impl 단계에서 before/after 대조 기록).

## 수용 기준
1. **(게이팅) SoT 정합**: STAGE_GUIDE_PLAN §2.6.1 신 불변식 추가 + §2.6/§0.8/§2/§3.2 supersession
   마커 + REVISION §6 박제 완료. 문서가 더는 카드 배지/카드 조작 카피 모드 분기를 요구하지 않음.
2. `GuideInputModeCopyTest` PASS: 3 모드 hint 분기 + 어포던스 색/타깃 Tokens·카테고리 고정 + 배지 모드 중립.
3. `OnboardingIntegrationTest` PASS: 실씬 카드 페이지→dismiss→begin(스폰)→어포던스 적격→스킬 전이.
4. `StageIntroCardFallbackTest` PASS: (a) 모든 캠페인 guide `pages` non-empty(단일카드 도달불가) +
   (b) guide-null placeholder 카피-free + (c) legacy pages-empty 렌더 shape 잠금.
5. **(게이팅) status.json 동기화**: phase frontmatter `verify`(3 테스트)와 `status.json`의 Phase 6
   verify가 정확히 일치(codex R2-M2). 비일치 시 자동화/리뷰어가 fallback 가드를 건너뛸 수 있음.
6. 큐레이트 회귀 0회귀(변경 전후 동일; 선재 red 동일성 입증).
7. 카드 UI 렌더 코드 무변경(존치) · 프로덕션 코드 변경 = Strings 배지 4키 모드 중립화 + (정합 가드가
   하드코딩 색 발견 시에만) 글로우/커서 교정(현재 0 예상).
