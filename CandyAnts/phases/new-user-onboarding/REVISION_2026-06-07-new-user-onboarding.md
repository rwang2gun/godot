# REVISION — new-user-onboarding (2026-06-07)

본 task의 범위·결정·근거 SoT. 설계 본문 SoT는 `docs/STAGE_GUIDE_PLAN.md`.

## 1. 배경 (첫 빌드 피드백)
대상 플레이어 = **초등학생·라이트 유저**. 첫 빌드 피드백 2건:
- **#1 "남는 개미가 역할이 없어 부정적"** — 레벨의 exact-fit 개미경제(`총마리 = candy_hp + 정착개미`)로 이미 해소(STAGE_GUIDE_PLAN §0.7). 본 task는 거스르지 않고 강화만.
- **#2 "스킬 배치·동작이 직관적이지 않다"** — 본 task의 주 타깃. 2-레이어로 해소: ⓐ 진입 인트로 카드 ⓑ 인게임 시각 어포던스.

## 2. 범위 (In)
- **인게임 어포던스** (STAGE_GUIDE_PLAN §0.8): "반짝이는 걸 탭한다 — 커서는 결과물 모양". 외곽선 셰이더 글로우 + 4입력모델 라우팅.
- **카테고리 단일 SoT** (§0.8.5, CRITICAL): `SkillAffordance.gd`로 스킬→카테고리 매핑 중앙화. 신규 스킬 = 카테고리 1줄. 기존 분산 SoT(`SkillSign.SIGN_SKILLS` 등) 흡수.
- **인트로 카드** (§2~§4): `StageIntroCard` + StageRunner.begin() 게이트 + S1~S8 가이드 데이터/카피.
- **신규 스킬 = 가이드 에셋 계약** (§0.8.6, CRITICAL): 카테고리별 필요 에셋(②정착폼·④장치 스프라이트 + 공통 아이콘/커서/카피)을 계약화. 누락 시 가드 테스트 fail + `ASSET_PRODUCTION_NEEDS.md`에 제작 요청 자동 기록. (Phase 7)

## 3. 범위 밖 (Out / Deferred)
- **exact-fit 안전망**(여유 +1 / 줍기 전 유실 자동 보충) — 결정: **현행 유지**(STAGE_GUIDE_PLAN §0.7 리스크1). 박제만.
- ~~**S1 blocker 예산 모순**~~ — **해소됨(2026-06-07, codex R1 HIGH)**: `stage01.tres`에서 blocker 제거(available=`[climber]`). S1=climber 단일 튜토리얼, `CampaignS1ClearTest` saved5/5 PASS. blocker 첫 등장=S2. (in-scope 처리 — 어포던스가 소프트락을 광고하는 문제라 onboarding 트랙이 소유.)
- **S6 땅굴 메커니즘 실측**(climber 깊은 귀환 기절 여부) — 별도. S6 카드 카피 확정 전 필요하나 본 task 차단 아님.
- S9 인트로 카드(피날레 복습) — 선택. 1차 미포함 가능.

## 4. 결정 (확정 2026-06-07)
- 전달 방식 = **카드 + 어포던스 2-레이어**(방향 B).
- 글로우 구현 = **외곽선 셰이더**(`outline.gdshader`), modulate-only 아님. 라이트 유저 가독성 우선.
- 어포던스는 **카테고리 SoT 파생**(하드코딩 금지). 확장 가드 테스트 필수.
- 가이드 카피 = `Strings.gd` 중앙화. 입력모델 배지를 카드↔어포던스 공통 시각 어휘로.

## 5. 입력모델 4분류 (DOMAIN_MAP §2.1 = 카테고리 SoT 미러)
| Category | 스킬 | 글로우 대상 | 커서 |
|---|---|---|---|
| ANT_ARMED (③) | climber·bridge·builder | 개미 | 스킬 아이콘 |
| ANT_SETTLE (②) | blocker·floater | 개미 | 반투명 정착폼 |
| SIGN (①) | sand_mound·basher·cutter·digger | surface 타일 | 푯말 |
| DEVICE (④) | leaf_jump | surface 타일 | 장치 |

## 0. 다음 세션 진입 (HANDOFF — 2026-06-07)

> **이 task는 plan-stage 완료, 구현 미시작 상태로 멈춤.** 다음 세션은 여기부터.

**진입 명령**:
```
/harness new-user-onboarding
# 또는
python scripts/execute.py new-user-onboarding next   # → Phase 1 출력(sot/sot_aux)
```

**현재 상태**:
- plan-stage **종결(clean)**: codex 적대적 리뷰 R1(HIGH1+MED2)→수정→R2(HIGH0+MED2)→수정. 최종 HIGH 0. 로그 `reviews/plan-review.md`.
- 7 phase 전부 **pending**. status.json ↔ frontmatter 정합(`validate` ✓, `sync-status` 완료).
- **다음 작업 = Phase 1 구현**: `SkillAffordance.gd`(카테고리 SoT) + `assets/shaders/outline.gdshader` + `scripts/ui/Glow.gd` + `tests/SkillAffordanceCategoryTest` + `tests/OutlineGlowSmokeTest`. 게임 배선 없는 기반.

**⚠ 미커밋 (워킹트리 — 다음 세션 시작 시 존재)**:
- 신규: `phases/new-user-onboarding/**`(metadata·REVISION·phase01~07·status.json·reviews/plan-review.md), `docs/STAGE_GUIDE_PLAN.md`
- 수정: `docs/LEVEL_REDESIGN_STATUS.md`(§0.6 스냅샷), `docs/DOMAIN_MAP.md`(§3.1 Stage01~09), `data/stages/stage01.tres`(blocker 제거)
- **gotcha**: 위 plan-setup을 **먼저 별도 커밋**(`chore(onboarding): plan-stage setup + S1 blocker fix`)으로 남기는 게 깔끔. 안 그러면 Phase 1 `complete`가 docs/stage01.tres를 whitelist 밖으로 보고 abort할 수 있음(terrain-tier 선례). complete 전 plan-setup 커밋 권장.

**구현 시 의존하는 검증된 코어 사실**:
- **carry-consume 1:1**: 운반 개미는 배달 즉시 소비(`Home.gd` carrying→`SavedState`→`queue_free`). N조각 = N마리 배달. 왕복 없음. (CampaignS1ClearTest 로그 실증)
- **exact-fit**: `총마리 = candy_hp + 영구소비 정착개미(blocker/floater)`. ①푯말/③무장/④장치는 개미 미소비.
- **배치 규칙 SoT(Phase 2 추출 대상)**: `SkillToolbar._ground_cell_for_sign`(점유 거부+아래 64칸 스냅) + `_leaf_jump_pad_exists`(중복 거부). 트리거 규칙 `SkillSign._ant_at_cell`과 다름.
- `Skill.can_apply()` 10종 모두 존재(적격 게이팅 가능).

**결정 고정(번복 금지 없이 진행)**: 안전망 미도입(현행 유지) · S1 blocker 제거(해소) · 글로우=외곽선 셰이더 · 어포던스=카테고리 SoT 파생 · 신규 스킬=카테고리+에셋 계약.

**미결(차단 아님)**: S6 "땅굴" climber 깊은 귀환 기절 여부(헤드리스 실측 필요, Phase 5 S6 카드 카피 확정 전). S9 피날레 카드 선택.

---

## 6. Phase 개요 (선형)
1. affordance-foundation — 카테고리 SoT + outline 셰이더 + 글로우 헬퍼 (게임 배선 없음)
2. tap-target-glow — 스킬 선택 시 카테고리별 글로우(개미/타일) + can_apply 게이팅
3. cursor-result + preview 리팩터 — 카테고리별 커서 + PlacementPreview/라우팅 SoT 통합
4. intro-card-infra — StageIntroCard + begin() 게이트 + 헤드리스 스킵
5. guide-data + 카피 — StageGuideData + Strings.guide.* + S1~S8 + 드리프트 가드
6. input-mode + polish — 모드별 카피 분기 + 통합 회귀
7. skill-guide-asset-contract — 카테고리별 가이드 에셋 계약 + 가드 테스트 + 누락 자동 제작 요청(ASSET_PRODUCTION_NEEDS) + CLAUDE.md 스킬 추가 규칙 갱신
