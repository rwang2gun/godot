# Phase 7 (input-mode-polish, 재조정) — Impl-stage Adversarial Review

> status.json id 7 (파일명 phase06-input-mode-polish.md). 재조정 Option A 구현.
> 변경: 3 신규 테스트 + Strings.gd guide.badge.* 모드 중립화 + STAGE_GUIDE_PLAN §2.6.1/markers + REVISION §6.

## Round 1 (codex)

Target: working tree diff
Verdict: needs-attention — **HIGH 0** + MEDIUM 2

- [MEDIUM] OnboardingIntegrationTest bypasses real paged-card UI + SceneFlow seam
  (hand-connects intro_dismissed, calls private _on_next_pressed/_on_dismiss_pressed) → can false-pass
  if real card buttons hidden/disabled/disconnected or SceneFlow wiring broken.
  Rec: instantiate Main.tscn, set SceneFlow._test_force_intro=true, load_stage(1), drive visible
  PageRoot buttons (NextBtn/StartBtnP), assert real SceneFlow pending-stage begins + intro pause-block release.
- [MEDIUM] Fallback guard hard-coded 1..9 + silently skips missing guides → if a later published
  stage has missing/empty-pages guide, test passes while invariant false.
  Rec: derive checked IDs from campaign SoT (PUBLISHED_STAGE_IDS / MenuLayout), fail on missing/empty.

### R1 수정 (impl 정책: HIGH 0이나 clean verdict 목표 + 둘 다 실제 커버리지 강화라 defer 없이 수정)
- **M1**: OnboardingIntegrationTest를 **실 Main.tscn + SceneFlow E2E**로 재작성. `$Main` 임베드 →
  `_test_force_intro=true` + `load_stage(1)` → 실 카드(`_scene_flow._intro_card`)의 **가시 버튼**
  (NextBtn ×2 / StartBtnP, visible+enabled 단언 후 `pressed.emit`) 구동 → 실 `SceneFlow._on_intro_dismissed`
  begin 배선 + **InputRouter 인트로 pause-block acquire(표시 중)/release(dismiss 후)** 단언 → 어포던스
  적격 → 스킬 trait. PASS: `card(pages=3)→btn dismiss→begin→glow=5→trait`.
- **M2**: 하드코딩 1..9 → `SceneFlow.PUBLISHED_STAGE_IDS` 파생. 불변식 = **guide 존재 ⟹ pages
  non-empty**(guide 부재 → placeholder, (b)가 카피-free 입증이라 허용; S9 미저작 케이스 수용). 신규
  published 스테이지가 empty-pages guide 출하 시 자동 fail. PUBLISHED 비면(fail-closed) 명시 fail.

## Self-Review Round 1 (clean)
재조정 구현 + R1 수정 결과물을 codex 기준으로 자체 적대적 리뷰:
- OnboardingIntegrationTest: 실 SceneFlow 배선·가시 버튼·pause-block까지 단언 → 모사 false-pass 경로
  소멸. "수동"은 `_test_force_intro`(헤드리스 스킵 우회 필연)+`pressed.emit`(표준 테스트 클릭 모사)뿐.
  _fail이 잔존 pause-block 정리. run_test 프로세스 격리로 time_scale/전역 누수 없음.
- M2: PUBLISHED SoT 파생 → 드리프트 가드. guide-exists⟹pages 조건이 *_desc 미도달까지 함의.
- 문서: 배지 mandate 6개 사이트 전부 마커/우선권(§2.6.1) 처리. §2.2 L136(ASCII)은 L147 마커가 커버.
- **HIGH/CRITICAL 0** → codex 재리뷰 진행.

## Round 2 (codex)

Verdict: needs-attention — **HIGH 0** + MEDIUM 1

- [MEDIUM] Published stages can silently ship with no guide (StageIntroCardFallbackTest.gd) — blanket
  "missing guide = safe" allowance means a future published stage accidentally omitting its guide passes
  while users get only placeholder; contradicts "campaign guides require authored pages".
  Rec: fail on missing guide for published stages except an explicit documented allowlist (e.g. S9);
  assert allowlisted stages render only placeholder; align STAGE_GUIDE_PLAN/phase06 wording.

### R2 수정
- `_GUIDELESS_ALLOWLIST=[9]`(REVISION §3 — S9 피날레 무가이드 의도) 도입. published 스테이지:
  allowlist면 guide 부재여야(=placeholder, (b)가 입증), 그 외는 **guide 존재+로드+pages non-empty
  필수(누락도 fail)**. 신규 무가이드 published = fail. 문구 정렬: phase06 (a) bullet + STAGE_GUIDE_PLAN §2.6.1.

## Self-Review Round 2 (clean)
- allowlist 명시 + SoT(PUBLISHED_STAGE_IDS) 파생 → 실수 누락 차단 + S9 의도 예외 문서화. guide-exists⟹
  pages 불변식이 *_desc 미도달 함의. 신규 무가이드/empty-pages published 자동 fail. 문구 3곳 정렬.
- **HIGH/CRITICAL 0** → codex Round 3.

## Round 3 (codex)

Verdict: needs-attention — **HIGH 0** + MEDIUM 1

- [MEDIUM] Published page copy can regress to mode-specific/blank while guard passes
  (StageIntroCardFallbackTest) — guard only checked pages non-empty, not GuidePage title/body content.
  A published guide could keep pages non-empty but ship empty body_key, missing Strings key, or body
  text with retired mode verb (탭); card renders it, tests don't fail → contradicts §2.6.1 mode-neutral.
  Rec: validate every GuidePage title_key/body_key (non-empty registered Strings keys, resolved
  non-empty, no retired mode verbs).

### R3 수정
- StageIntroCardFallbackTest (a)에 **GuidePage 카피 가드** 추가: 비-allowlist published guide의 모든
  page에 대해 title_key·body_key가 비어있지 않음 + 등록(Strings.t≠key) + 해석 텍스트 non-empty + 모드
  동사(클릭/탭/버튼) 미포함. helper `_check_page_copy`. 기존 S1~S8 카피는 전부 깨끗(사전 grep 확인) → PASS.
  image_path 단언은 §2.6.1(모드 중립 카피)과 직교 + 카드가 graceful 처리 + 병렬 아트 트랙이라 제외.

## Self-Review Round 3 (clean)
- §2.6.1 "카드 본문 모드 중립" 불변식이 이제 실제 사용자 카피(GuidePage title/body) 레벨에서 강제됨.
  빈/미등록/모드 동사 카피가 published guide로 출하되면 자동 fail. title+body 둘 다 요구(codex 명시 +
  기존 전부 충족). **HIGH/CRITICAL 0** → codex Round 4.

## Round 4 (codex) — 실 프로덕션 버그 발견

Verdict: needs-attention — **HIGH 0** + MEDIUM 1 (실 프로덕션 correctness 버그)

- [MEDIUM/실버그] guide-null fallback이 stale 페이징 카드 콘텐츠를 렌더(StageIntroCard.gd:146-153).
  guide==null 분기가 _pages/_page_root/_image_wrap/_dots를 리셋하지 않고 숨은 VBox만 갱신 후 return.
  실 캠페인: S8(페이징) → S9(allowlist 무가이드)가 같은 카드 재사용 → S9에 S8 페이지(스크린샷) 노출.
  fresh-card 테스트라 이 stateful 전이 미exercise → false-pass.
  Rec: guide-null 분기에서 페이징 상태/UI 리셋 + paged→null 재사용 회귀 테스트 추가.

### R4 수정 (프로덕션 코드)
- `StageIntroCard.gd` guide==null 분기: `_use_single_card()`(_pages=[]·_page_index=0·_vbox 표시·
  _page_root 숨김) + `_clear_children(_image_wrap)`/`_clear_children(_dots)` 추가 → paged→null 전이 시
  stale 페이징 잔재 제거.
- `StageIntroCardFallbackTest` (d) stateful 재사용 회귀: 같은 카드에 S1(3페이지) 표시 → id=0 재표시 →
  page_count==0 + PageRoot.visible==false + VBox.visible + goal==placeholder 단언.
- **prove-it 검증**: fix 없이 (d)가 `page_count 3 != 0 (stale 페이지 잔존)`으로 정확히 fail → 테스트 teeth + 버그 실재 입증. fix와 함께 PASS. 카드 스위트(Render/Show/Fallback/GuideInputMode/Onboarding) 전부 green.

## Self-Review Round 4 (clean)
- 모든 카드 전이(paged→null / null→paged / paged→paged / single)가 정합하게 리셋됨. 첫 표시(무이전)도
  _use_single_card() 멱등. 카드 스위트 회귀 0. **HIGH/CRITICAL 0** → codex Round 5.

## Round 5 (codex) — APPROVE

Verdict: **approve** — no material findings.
> "The guide-null branch now resets paging state and visible subtree before rendering placeholder
> content, and the fallback test covers published-guide presence/pages/copy plus the stateful
> paged-to-null reuse regression that exposed the production bug."

### Impl-stage 종결
- codex 5라운드(R1~R4 needs-attention HIGH 0 + 실 finding 수정 → R5 approve) + 자체리뷰 4회.
- 진행 finding: seam 모사→실 E2E / 하드코딩→SoT 파생 / missing-guide→allowlist / pages→GuidePage 카피
  검증 / **guide-null 페이징 미리셋 실버그 수정(prove-it)**. 전부 HIGH 0, 정책상 clean verdict 달성.
