# Phase 5 — guide-data-copy · impl review

## 변경 요약
- **`scripts/core/StageGuideData.gd`** (신규, Resource): 인트로 카드 문안 메타(STAGE_GUIDE_PLAN §2.4 B안). 필드 = `stage_id` / `goal_key` / `new_skill_ids: Array[String]` / `skill_desc_keys: Array[String]`(new_skill_ids와 1:1 평행) / `hazard_keys: Array[String]`. 카피 문자열 자체는 보관하지 않고 Strings key만(중앙화 규칙). 칩 라벨/아이콘/배지는 런타임 파생(Strings.skill_label · SkillToolbar.ICONS · SkillAffordance.category) → 칩 텍스트 중복 정의 0.
- **`data/guides/stage01~08_guide.tres`** ×8 (신규): §4 스테이지별 계획을 라이브 `available_skills`(SoT) 기준으로 반영.
  - S1 climber(③) / S2 floater(②)+기절 / S3 bridge(③)+소다물 / S4 builder(③) / S5 sand_mound(①, 첫 푯말) / S6 digger(①) / S7 basher(①) / S8 cutter(①)+leaf_jump(④)+끈끈이.
  - "신규" = 그 스테이지 **첫 등장** 스킬만(§5.1 "1장에 신규만"). 복습 스킬(S2 climber·S5 floater·S6 climber)은 카드 칩에서 생략.
- **`scripts/core/Strings.gd`**: `guide.sN.*`(목표/스킬설명/해저드 카피 22 key) + `guide.badge.{ant_armed,ant_settle,sign,device}`(입력모델 배지 4종, 카테고리당 1·스킬 공유). 배지 카피는 "개미 탭 / 땅 탭"으로 ②③↔①④ 2지선다를 앞세움(§0.8.4).
- **`scripts/ui/StageIntroCard.gd`**: placeholder → StageGuideData 바인딩. `show_intro`가 `stage_data.id`로 `data/guides/stage%02d_guide.tres`를 조회(`ResourceLoader.exists` graceful), 타이틀(display_name)·목표·스킬칩(아이콘+라벨+배지)·설명·해저드를 동적 렌더. 배지=`SkillAffordance.category_of(id)`→`_BADGE_KEYS`→Strings(어포던스/커서와 동일 카테고리 SoT). 가이드 없음(S9·로드실패)=타이틀+fallback 본문(카드 생략 톤). 검사 inspector 추가: `goal_text()`/`badge_labels()`/`skill_desc_texts()`/`hazard_texts()`. `shown_skill_ids()`는 가이드 new_skill_ids 미러.
- **`scenes/ui/StageIntroCard.tscn`**: Body 라벨 → Goal 라벨 + SkillList(VBox) + HazardList(VBox)로 재구성. 칩/해저드 행은 런타임 동적 생성.
- **`tests/StageGuideDataRenderTest.{gd,tscn}`** (신규): S1·S5·S8(입력모델 전환점 3종)에서 카드가 올바른 칩 수/배지/목표·설명 카피/해저드 수를 렌더. 배지·카피는 리터럴 아닌 Strings·SkillAffordance 파생과 대조(SoT 일치 보장) + SkillList 실제 자식 수 검사(빈 inspector ↔ 빈 UI 괴리 차단).
- **`tests/GuideSkillSubsetDriftGuardTest.{gd,tscn}`** (신규, CRITICAL 가드): 각 stageNN_guide의 new_skill_ids ⊆ stageNN.tres.available_skills + stage_id 일치 + desc/skill 1:1 + 모든 카피 key Strings 존재 + new skill SkillAffordance 카테고리 존재. §1 드리프트 재발을 카드 레벨에서 차단.
- **`tests/StringsTableTest.gd`**: GUIDE_KEYS 26종 존재 검사 + SKILL_IDS에 leaf_jump 추가.

## 핵심 설계 결정
- **가이드 조회 = id 경로 컨벤션**(`data/guides/stage%02d_guide.tres`). StageData 미수정(§2.4 A안 비대화 회피) + 경로락된 8개 stage tres 미수정. 누락 시 graceful null → 카드 생략 톤. 드리프트 가드/렌더 테스트가 같은 컨벤션으로 교차 검증.
- **칩 콘텐츠 단일 파생**: 라벨=Strings.skill_label, 아이콘=SkillToolbar.ICONS, 배지=SkillAffordance.category. 가이드 리소스는 "어떤 key" 메타만 → 칩 텍스트 이중 SoT 0.
- **배지 = 카테고리 SoT 파생**: 카드↔인게임 어포던스(Phase 2~3)가 동일 SkillAffordance.Category 어휘 공유(§0.8.4 "카드에서 배운 걸 글로우가 재확인").

## 검증
- **phase verify 3종 PASS**: StageGuideDataRenderTest / GuideSkillSubsetDriftGuardTest / StringsTableTest(18+26 guide+10 skill).
- **회귀 0**: StageIntroCardShowTest(id=1→guide 조회→shown=["climber"] 유지)·StageIntroCardHeadlessSkipTest·SceneFlowScreenState·SceneFlowLastStagePredicate·CampaignS1/S5/S8Clear·StageDialogShowResult 전부 PASS.
- **GameFlowTest Scenario B = 선재 실패**: `git stash -u`로 pristine HEAD에서도 동일 `await_signal timeout`(Stage09). Phase 5 무관(Scenario A=Stage01→02 인트로 경로 동일하게 PASS). 헤드리스라 카드 미표시 경로.

## 수용 기준 점검
- 카드 카피 100% Strings.gd(씬 하드코딩 0). ✓ (씬엔 빈 text·런타임 Strings.t만)
- S1~S8 가이드 new_skill_ids ⊆ 라이브 available_skills. ✓ (드리프트 가드 PASS)
- 입력모델 배지가 카테고리 SoT 파생(어포던스와 동일 어휘). ✓ (렌더 테스트가 category→badge 일치 단언)

## Self-Review Round 1 (자체 적대적)
가혹 기준(CRITICAL/HIGH/MEDIUM/LOW + hypothetical + cross-doc + dead branch + circular SoT)로 점검:
- **S2 blocker 카드 미노출 (설계 텐션, MEDIUM→문서화로 종결)**: §3.3은 blocker 첫 등장=S2로 표기하나 §4 S2 카드 계획은 floater만 신규로 명시(blocker copy 미제공). §0.7 exact-fit(7=hp5+floater+blocker)상 S2에서 blocker가 실제 소비됨 → 카드만 보면 blocker 학습 누락 가능. **결정: §4(per-stage 카드 SoT)를 권위로 따라 floater만 카드.** blocker는 ⓑ 인게임 어포던스(글로우=적격 개미)가 보완. 투기적 카피 신설(§4 미기재)은 SoT 발명이라 회피. → **사용자에게 가정 표면화**(아래 §보고). 코드 결함 아님.
- **id 경로 조회 graceful**: stage_data null·id≤0·파일 부재 → null → fallback. S9(가이드 없음) 비헤드리스 진입 시 타이틀+"곧 시작해요!"+시작 버튼(피날레 카드로 무해, §4 S9 "카드 생략 가능"과 모순 없음). 헤드리스는 SceneFlow가 카드 자체를 스킵.
- **드리프트 가드 ↔ 카드 런타임 정합**: 둘 다 동일 경로 컨벤션 + new_skill_ids 사용. 가드가 통과하면 카드도 동일 데이터로 렌더(렌더 테스트가 별도 실증). circular SoT 없음 — 가드는 stage.tres(독립 SoT)와 대조.
- **칩 1:1 평행 깨짐 방어**: desc_key 부족 시 카드는 빈 설명으로 안전 진행, 가드가 size 불일치를 fail. dead branch 아님(방어 + 가드 이중).
- **`_clear_children` 재진입**: show_intro 재호출(replay) 시 SkillList/HazardList 자식 queue_free+remove_child → 즉시 child_count 정확. 칩 누적 없음(렌더 테스트가 3 스테이지 연속 show로 실증).
- **Chip 배지 set-before-add**: `badge.value=` 설정 후 add_child → Chip setter가 not-in-tree면 값만 저장, _ready의 _apply_text가 반영(Chip 패턴). 빈 배지 0(렌더 테스트 badge 일치 PASS).
- **Body 노드 제거 영향**: grep 결과 Body 참조는 카드 스크립트 내부뿐(Goal로 교체). 외부(SceneFlow/테스트) 참조 0. StageIntroCardShowTest(ButtonRow/StartBtn 경로) PASS로 실증.
- **leaf_jump 라벨/카테고리**: Strings._SKILL_NAMES·SkillAffordance.SKILL_CATEGORY 둘 다 존재(DEVICE). S8 배지=device 렌더 테스트 PASS.
- **dead/이중 SoT**: 카드 콘텐츠는 가이드 메타+3 파생 SoT(Strings/ICONS/Affordance) 조합, 신규 이중 SoT 미도입.

**Self-Review Round 1 verdict: HIGH 0.** S2 blocker는 §4 SoT 준수 결정(가정 표면화 대상, 코드 결함 아님). codex 재리뷰로 진행.

---

## Round 1 (codex adversarial-review) — verdict: needs-attention (MEDIUM 1)

> 대상: working tree diff

**[medium] Drift guard allows first-use skills to disappear from the intro card** (GuideSkillSubsetDriftGuardTest.gd)
가드가 `new_skill_ids ⊆ available_skills`(단방향 subset)만 검사 → "첫 등장 스킬이 카드에서 빠지는" 반대 방향을 못 잡음. S2 실증: `stage02.tres`=[climber,floater,blocker]인데 `stage02_guide.tres`는 floater만 광고. blocker는 S2 첫 등장 + exact-fit(7=hp5+floater+blocker)상 실제 소비 → 설명 없는 첫 사용(튜토리얼 구멍) + 가드 통과.
권장: 각 stage의 available을 이전 stage들과 비교해 first-introduced를 계산하고 그것이 guide에 표현됐는지 단언 / 또는 명시적 omission 예외. 그 뒤 blocker를 S2 guide에 추가하거나 예외 처리.

→ 내 Self-Review Round 1에서 이미 동일 텐션을 MEDIUM으로 표면화. **사용자 결정(2026-06-07) = 카드에 blocker 추가**(권장안).

### Fix (Round 1 대응)
1. `stage02_guide.tres`: new_skill_ids=[floater, **blocker**], skill_desc_keys += `guide.s2.blocker_desc`.
2. `Strings.gd`: `guide.s2.blocker_desc` 신규 + StringsTableTest GUIDE_KEYS += 동일(27 guide keys).
3. **드리프트 가드 강화** (codex 핵심): (B) 첫 등장 완전성 `first_introduced(N)=available(N)−∪available(1..N-1) ⊆ new_skill_ids` 추가. seen union 누적. 단방향→양방향.
4. `docs/STAGE_GUIDE_PLAN.md §4 S2`: blocker 신규 추가 정정(§3.3/§0.7 일치, 정정 사유 박제).
5. **Prove-It**: blocker 임시 제거 시 가드 `exit 1` + "S2: 'blocker' first available here but NOT carded" → 복원 시 PASS. 강화 가드가 회귀를 실제로 잡음을 실증.

## Self-Review Round 2 (자체 적대적, fix 후)
- **양방향 가드 정합**: (A) new⊆available + (B) first_introduced⊆new. 8 스테이지 전부 통과. extra(복습 스킬 재카드)는 허용(§5.1은 soft guideline, 결함 아님) — 두 불변식이 올바른 경계.
- **first-use 계산 정확성**: GUIDE_STAGES [1..8] 순회하며 seen union을 **처리 후** 누적 → S(N) 판정 시 seen=∪(1..N-1) 정확. S2 first={floater,blocker}, S5 first={sand_mound}(floater 제외), S6 first={digger}(climber 제외) 등 수기 검산 일치.
- **S2 카드 2칩**: floater·blocker 둘 다 ANT_SETTLE → 동일 배지("개미 탭 → 정착"). 같은 입력모델 2종 병치 = §0.8.4 교육적으로 정상. 렌더 무결(_clear_children 재진입 + 2 child).
- **cross-doc**: §4 S2 정정 ↔ tres ↔ Strings ↔ 가드 4곳 동기화. circular SoT 없음(가드는 독립 stage.tres와 대조).
- **회귀**: StringsTableTest(27 guide)·드리프트·렌더 PASS. Phase-4 카드·SceneFlow·Campaign 무영향(데이터 추가만, 코어 무변경).

**Self-Review Round 2 verdict: HIGH 0.** codex 재리뷰로 진행.

---

## Round 2 (codex adversarial-review) — verdict: needs-attention (MEDIUM 1)

**[medium] Drift guard still allows review skills to be carded as new** (GuideSkillSubsetDriftGuardTest.gd)
가드가 (A) new⊆available + (B) first_introduced⊆new만 검사, 역방향 `new ⊆ first_introduced` 미검사. 미래 가이드가 S2에 climber를 신규로 되넣어도(available + 카테고리 + 카피 충족, floater/blocker가 first-use 완전성 충족) 가드 통과 → 복습 스킬을 신규 칩으로 렌더 = StageGuideData 계약/§5.1 "신규만" 위반. 가드가 회귀 장벽으로 약화.
권장: first_introduced를 명시 집합으로 계산해 new_skill_ids와 **집합 동등** 단언(또는 검증된 예외 리스트).

→ 내 Self-Review R2에서 "extra(복습 재카드) 허용"으로 합리화한 부분이 문서화된 계약과 불일치. codex 지적 타당 — 계약을 진짜 장벽으로.

### Fix (Round 2 대응)
- 가드 (C) 추가: `new_skill_ids ⊆ first_introduced`(복습 스킬 신규 카드 금지). (B)+(C) = **집합 동등** `new_skill_ids == first_introduced(N)`. 위반 시 "이미 등장(복습)" vs "available에 없음" 사유 구분 메시지.
- **Prove-It (C)**: S2 new에 climber(복습) 추가 → 가드 `exit 1` + "carded 'climber' is NOT first-introduced (이미 등장(복습)) — '신규만' 계약 위반!" → 복원 PASS. 8 스테이지 전부 집합 동등 충족(S5 floater·S6 climber 복습이 정확히 배제됨).

## Self-Review Round 3 (자체 적대적, fix 후)
- **집합 동등 = 정확한 계약**: (A) new⊆available(§1 live-drift 명명 가드, 고유 메시지) + (B)+(C) new집합==first_introduced집합. 세 검사 각각 distinct 진단 메시지. 8 스테이지 PASS + 양방향 Prove-It(누락·재카드) 둘 다 실증.
- **dup 방어**: new_skill_ids에 중복 id가 있으면? (C)는 통과하나 첫 등장은 dup 없음 → 칩 2개 렌더(시각 중복)뿐, 계약 위반 아님. 현 8 데이터 dup 0. (과도 방어 회피 — YAGNI.)
- **순서 독립성**: (B)(C)는 has() 기반 집합 비교라 new_skill_ids 순서 무관(카드 칩 순서는 데이터 순서 유지). 정합.
- **회귀**: verify 3종 PASS. 코어/씬/카드 로직 무변경(테스트 단언 강화 + S2 데이터 1행). Phase-4·SceneFlow·Campaign 무영향.

**Self-Review Round 3 verdict: HIGH 0.** codex 재리뷰로 진행.

---

## Round 3 (codex adversarial-review) — verdict: **approve** ✅

> Ship: round-3 드리프트 가드에 블로킹 finding 없음. 가드가 (첫 등장 누락 + 복습 스킬 신규 오카드) 양방향을 검사 → 의도한 집합 동등 계약이 S1~S8 라이브 available_skills 대조로 강제됨. No material findings.
>
> codex 제안(non-blocking): prove-it mutation을 문서화/자동화 유지 → 본 리뷰 §Round 1·2 Fix에 박제 완료.

**Impl-stage 적대적 리뷰 종결**: R1(MEDIUM, first-use 완전성)→fix+self-review → R2(MEDIUM, set 동등성 역방향)→fix+self-review → R3 **approve**. 매 codex 라운드 사이 자체 적대적 리뷰 1회 삽입(R1·R2·R3). verdict clean 달성.
