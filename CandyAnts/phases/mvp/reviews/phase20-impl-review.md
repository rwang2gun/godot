# Phase 20 Implementation Review

**Status**: Round 1~5 codex HIGH 5건 누적 fix → Self-Review R6 clean → **codex Round 6: approve / clean**. Phase 20 impl 종결.

---

## Self-Review Round 1 (2026-05-25)

### Scope
plan v3.1 (§0.000) freeze 후 11개 .gd + 1 .tscn 수정 + 9 신규 (1 svg / 2 layout / 2 stage_data / 2 stage scene / 10 test 파일) = 약 30 file 변경(테스트 .tscn까지 포함 시 54 file). 100 cap 안.

### 검증

1. **헤드리스 회귀**: Stage02HeadlessTest / Stage03HeadlessTest / GameFlowTest / ScoringStarsTest / SaveDataRecordClearTest / StageDialogShowResultTest / StageDialogDismissTest / StageDialogSfxTest / SceneFlowEmitContractTest / WaterHazardLossEmptyHandTest / StickyStuckReleaseTest / SettlementTraitTransferTest / CutterCutThroughVineTest / BasherTunnelThroughWallTest / BridgeOverWaterTest / WaterStickyOverlapLostTerminalTest 전부 PASS.

2. **신규 10 test**: 전부 PASS.
   - ScoringStarsOverrideTest (F-D3 / R1-M2): boundary 7건 + invalid 3건 + degenerate 2건
   - StageDialogLastStageTitleTest (P-D6): 3 Title 분기
   - SaveDataStarOverrideTest (R1-H2): direct call + 빈 배열 fall-back + EventBus emit path + invalid thresholds
   - SceneFlowLastStagePredicateTest (R1-H4): 정적 검증 `== LAST_STAGE_ID` literal + `>=` 부재
   - AntStickyVisualTest (P-D4 / P-D5 / R1-H3 / R1-M3): bar visible + scale + sprite pause/resume + _sticky_max reset
   - SfxRequestEmitTest (P-D1): 8 id 정적 + 3 id 동적 캡처
   - WaterHazardLossCarryingTest (D-1): carrying water 진입 시 candy_lost emit + lost_pieces 증가 (lost=4)
   - StickyCarryingPreservedTest (D-2): carrying stuck 시 has_candy/in_transit 보존 + saved>=1
   - DistributorOnStickyTransferTest (D-5): sticky stuck → settled → trait 전이
   - SettledImmuneToHazardTest (D-6): SettledState ant가 Water entry 시도 시 Lost 미진입

3. **Tone policy**: `python scripts/check_tone_policy.py --commit1` PASS (0 forbidden token).

### Self-Adversarial 검증 항목

- [x] **R1-H2 SaveData desync 해소**: record_clear 시그니처 확장 + _on_stage_cleared가 result.star_thresholds 전달. SaveDataStarOverrideTest case A/C가 stage03 override path를 stars=1로 검증.
- [x] **R1-H3 sprite pause/resume**: `_sprite_paused_for_sticky` flag로 unstuck 직후 명시 play(_last_anim) 재호출. AntStickyVisualTest case B가 stuck → unstuck → 5 frame 내 is_playing=true 검증.
- [x] **R1-H4 SceneFlow predicate**: `>=` → `==` 1줄 변경. SceneFlowLastStagePredicateTest가 source 정적 검증.
- [x] **R1-M2 thresholds validation**: 길이/ascending/range 검증 + 0 star + push_warning. ScoringStarsOverrideTest invalid 3건 검증.
- [x] **R1-M3 _sticky_max reset**: timer 만료 시 _sticky_max=0 reset + fresh entry 시 새 dur 사용. AntStickyVisualTest case C가 0.2→1.0 시나리오로 검증 (scale.x ≈ 1.0).
- [x] **plan §2.8 ban list 정합**: SaveData/SceneFlow는 R1-H2/H4 fix 대상으로 §2.2 수정 대상에 포함, 다른 ban list 파일 무변경 확인 (git status 검증).
- [x] **ScoreSystem 4-카운터 invariant**: 모든 stage/dev 회귀에서 invariant 위반 0.
- [x] **§0.2 어휘 정책**: 신규 .gd 코드에 die()/DeadState 직접 참조 0건 (LostState/candy_lost 등 허용 어휘만).
- [x] **stage data backward compat**: stage01.tres/stage02.tres + 모든 dev_* @export 무변경 (Stage02/Stage03HeadlessTest 회귀 PASS).
- [x] **신규 dev id 충돌 검증**: 914/916 미점유 확인 (`grep ^id data/stages/dev/*.tres`).
- [x] **HazardBase Settled 가드**: SettledImmuneToHazardTest가 Water entry → SettledState 유지 검증.
- [x] **sfx_request emit 위치 정합**: D13 idempotency 가드 *후* sticky_glue emit (StickyHazard), LostState has_candy 분기 *내부* candy_lost emit. plan §3.2 freeze 정합.

### HIGH 0 / MEDIUM 0 / LOW 0 (Self-Adversarial Round 1)

Self-Adversarial Round 1 clean. codex adversarial-review impl 진행 → 1 HIGH 발견.

---

## Round 1 (codex adversarial-review, 2026-05-25)

**Verdict**: needs-attention

**Findings**:
- **[HIGH]** Existing stage03 saves can keep obsolete star counts after thresholds tighten (SaveData.gd:132-140)
  - stage03 thresholds [0.50, 0.80, 0.95] → [0.55, 0.85, 0.97] tightening 시 v1 데이터의 stage03.stars가 글로벌 thresholds 기반이라 UI(신규 thresholds) ↔ SaveData(stale stars) desync.
  - max() 보존 정책이 obsolete stars 무한 유지.
  - **Recommendation**: schema bump + migration 또는 versioned scoring policy.

**Fix** (Self-Review Round 2):
1. `SaveData.gd:11` `CURRENT_SCHEMA := 1` → `CURRENT_SCHEMA := 2`.
2. `_migrate_1_to_2(cfg)` 신규 — stage03 entry의 best_saved + STAGE_03_ORIGINAL_HP(=9, stage03.tres) + 신규 thresholds [0.55, 0.85, 0.97]로 stars recompute. 다른 stage(1/2/dev_*)는 무변경.
3. `record_clear()` 갱신 — stars는 max() 보존 X, best_saved 기반 derive (현재 thresholds + original_hp 사용). 향후 thresholds 변경 시에도 stars 자동 동기.
4. `SaveDataPhase20MigrationTest.gd/.tscn` 신규 — v1 seed(stage03 stars=2/best_saved=8) → migration → stars recompute 검증 + boundary cases(saved=5, saved=4).

**Regression**: SaveDataMigrationTest(v0→v1), SaveDataRecordClearTest, SaveDataStarOverrideTest, SaveDataIsUnlockedTest, SaveDataCorruptedTest 전부 PASS.

---

## Self-Review Round 2 (2026-05-25)

### 추가 검증
- [x] **Schema v1→v2 migration**: SaveDataPhase20MigrationTest이 3가지 boundary(saved=8/5/4)로 검증
- [x] **`record_clear` stars derive**: best_saved 기반 — replay 시 best_saved monotonic 유지하면서 stars는 항상 현재 thresholds로 계산. UI ↔ data 영구 동기.
- [x] **Backward compat**: SaveDataMigrationTest(v0→v1 + 새 v1→v2 chain) PASS. SaveDataRecordClearTest PASS (case C repeat replay: best_saved=max(8,5)=8 → stars=2 globally with 8/10).
- [x] **boundary 검증**: stage03 original_hp=9에서 신규 thresholds가 정수 saved 값에 boundary shift 0(saved 0-9 모든 값이 동일 stars). 단, 시스템은 향후 boundary shift에도 견고.
- [x] **stage03.tres override**: 정상 유지. record_clear가 thresholds 인자 받아 derive 정확.

### HIGH 0 / MEDIUM 0 / LOW 0 (Self-Adversarial Round 2)

Self-Adversarial Round 2 clean. codex adversarial-review Round 2 진행 → 1 HIGH 발견.

---

## Round 2 (codex adversarial-review, 2026-05-25)

**Verdict**: needs-attention

**Findings**:
- **[HIGH]** Malformed clear results can permanently downgrade stored stars (SaveData.gd:153)
  - Round 2의 fix가 stars를 best_saved 기반으로 항상 overwrite하지만, `Scoring.compute_stars`가 invalid 입력(original_hp<=0 또는 malformed thresholds)에 대해 0 반환 → 기존 stars=3이 0으로 영구 downgrade. malformed 클리어 이벤트나 잘못된 stage data가 비가역 데이터 손상으로 이어짐.
  - **Recommendation**: Before overwriting, validate `original_hp > 0` and `thresholds` usability. Malformed이면 기존 stars 보존 + warning. invalid thresholds가 legitimate 0-star clear와 구분되어야 함.

**Fix** (Self-Review Round 3):
1. `SaveData._is_clear_input_valid(original_hp, thresholds)` helper 신규 — original_hp>0 + thresholds 길이/ascending/range 검증.
2. `record_clear()` body 분기 — valid 입력이면 stars derive, malformed면 기존 stars 보존 + warning.
3. `SaveDataMalformedClearNoDowngradeTest.gd/.tscn` 신규 — 4가지 시나리오: (a) 기존 stars=3 + malformed original_hp=0 → 보존 3, (b) 기존 stars=2 + invalid thresholds(length/descending/out-of-range) → 보존 2, (c) fresh entry + malformed → stars=0 initial(natural), (d) legit 0 saved + valid → stars=0 recompute + monotonic best_saved.

**Regression**: 모든 SaveData test PASS — SaveDataMigrationTest(v0→v1→v2 chain), SaveDataRecordClearTest, SaveDataStarOverrideTest(case D 의미 보존: malformed → 0 stars natural state), SaveDataIsUnlockedTest, SaveDataCorruptedTest, SaveDataPhase20MigrationTest, SaveDataMalformedClearNoDowngradeTest.

---

## Self-Review Round 3 (2026-05-25)

### 추가 검증
- [x] **Malformed input downgrade 차단**: `_is_clear_input_valid()` guard. (1) original_hp <= 0, (2) thresholds 길이≠3, (3) thresholds descending, (4) thresholds out-of-range 4가지 modes 모두 차단.
- [x] **Legit zero score 정상 처리**: original_hp>0 + empty thresholds + saved=0 → valid → stars=0 derive. NOT downgrade.
- [x] **monotonic best_saved**: 재플레이 시 best_saved 모노톤. stars는 best_saved 기반 derive — replay 결과가 나빠도 stars 보존(best_saved 보존이 트리거).
- [x] **migration 영향 X**: _migrate_1_to_2는 const STAGE_03_THRESHOLDS_V2(valid)와 STAGE_03_ORIGINAL_HP=9(valid) 사용 — 자체 input 검증 불필요. SaveDataPhase20MigrationTest 회귀 PASS.

### HIGH 0 / MEDIUM 0 / LOW 0 (Self-Adversarial Round 3)

Self-Adversarial Round 3 clean. codex adversarial-review Round 3 진행 → 1 HIGH 발견.

---

## Round 3 (codex adversarial-review, 2026-05-25)

**Verdict**: needs-attention

**Findings**:
- **[HIGH]** Malformed clears can poison best_saved and later award invalid stars (SaveData.gd:152-160)
  - R2 fix가 stars overwrite만 차단했고 best_saved/best_score는 여전히 max() update. 예: malformed(saved=999, original_hp=0) → best_saved=999 poison. 후속 valid clear(saved=5, original_hp=10) → stars=compute_stars(999, 10, [])=3 (영구 corruption).
  - **Recommendation**: 모든 progress mutation 전에 validation. Malformed면 cleared/best_saved/best_score/stars 전부 보존, 0<=saved<=original_hp bound 추가 검증. Add regression test with poisoned high saved followed by valid clear.

**Fix** (Self-Review Round 4):
1. `record_clear()` early-return 분기 — 모든 progress mutation 이전에 `_is_clear_input_valid()` + `0 <= saved <= original_hp` 검증. Malformed면 `attempts`만 +1 후 return (cleared/best_saved/best_score/stars 전부 보존).
2. `SaveDataMalformedClearNoDowngradeTest case C` 갱신 — fresh malformed에서 `cleared=false`/`best_saved=0` 보존 검증 (R3 semantic).
3. `SaveDataMalformedClearNoDowngradeTest case E` 신규 — codex의 정확한 시나리오: malformed `(saved=999, original_hp=0)` → poison 차단 → 후속 valid `(saved=5, original_hp=10)` → `best_saved=5`(no 999) + `stars=1`(no 3 corruption) 검증.

**Regression**: 모든 SaveData test PASS (5종) + Stage03HeadlessTest + GameFlowTest 재검증 PASS.

---

## Self-Review Round 4 (2026-05-25)

### 추가 검증
- [x] **모든 progress mutation 이전 validation**: `record_clear` 첫 검증 → malformed 즉시 early-return. 그 이후 progress update 코드는 valid path 전용.
- [x] **saved bound 검증**: `0 <= saved <= original_hp` 추가. Negative saved or saved>original_hp 모두 malformed로 분류.
- [x] **attempts는 항상 증가**: malformed든 valid든 시도 횟수는 카운트 (외부 가시 — 디버깅/통계용).
- [x] **fresh entry malformed semantic**: cleared=false 유지 (R3 정책 — malformed clear는 "stage cleared" 토글 안 함).
- [x] **legit 0 saved + valid input**: original_hp>0 + empty thresholds + saved=0 → valid → stars=0 derive, cleared=true. 의도된 zero-saved clear는 정상 처리.
- [x] **monotonic best_saved invariant**: valid path에서만 max(). malformed로 best_saved poison 불가능.

### HIGH 0 / MEDIUM 0 / LOW 0 (Self-Adversarial Round 4)

Self-Adversarial Round 4 clean. codex adversarial-review Round 4 진행 → 1 HIGH 발견.

---

## Round 4 (codex adversarial-review, 2026-05-25)

**Verdict**: needs-attention

**Findings**:
- **[HIGH]** Previously poisoned best_saved still corrupts stars after a valid clear (SaveData.gd:165-168)
  - R3 fix가 신규 malformed input은 차단하지만 *이미 저장된* corrupted best_saved(예: 수동 .cfg 편집)에 대해서는 valid 후속 clear가 그 poisoned 값을 max()로 가져와 stars derive시 corruption.
  - **Recommendation**: existing best_saved를 use하기 전 [0, original_hp] 범위 clamp/reject. Add regression test seeding current-schema save with best_saved=999.

**Fix** (Self-Review Round 5):
1. `record_clear()` valid path 진입 후 stored sanitize block 추가:
   - `stored_best_saved < 0` or `> original_hp` → reset to current `saved` + warning.
   - `stored_best_score < 0.0` or `> 1.0` → clampf to [0, 1] + warning.
2. 위 sanitized 값으로만 `max()` 계산 진행 → 외부 corruption이 신규 clear에 전파 불가.
3. `SaveDataMalformedClearNoDowngradeTest case F` 신규 — schema_version=2 cfg에 `best_saved=999`/`best_score=99.9` 수동 poison seed → reset → valid `record_clear(8, 5, 10, [])` → `best_saved=5`/`stars=1`/`best_score in [0,1]` sanitize 검증.

**Regression**: 모든 SaveData test PASS (6종) + 모든 phase 1~19 essential test 유지.

---

## Self-Review Round 5 (2026-05-25)

### 추가 검증
- [x] **Stored corruption 격리**: valid path 진입 후 sanitize. Out-of-range stored 값이 신규 clear에 전파 X.
- [x] **Reset strategy 일관성**: best_saved corruption → reset to `saved` (현재 valid 값을 baseline). best_score corruption → clamp to [0, 1].
- [x] **5라운드 누적 검증**: R1(threshold migration) + R2(stars 보존) + R3(progress mutation 전 validation) + R4(stored sanitize). 4계층 defense.
- [x] **regression breadth**: 6 SaveData test (RecordClear / Migration / StarOverride / Phase20Migration / Corrupted / MalformedClearNoDowngrade) 전부 PASS.
- [x] **valid happy path 무영향**: sanitize block은 corruption만 잡아냄. Normal saves의 stored 값 범위는 무변경.

### HIGH 0 / MEDIUM 0 / LOW 0 (Self-Adversarial Round 5)

Self-Adversarial Round 5 clean. codex adversarial-review Round 5 진행 → 1 HIGH 발견.

---

## Round 5 (codex adversarial-review, 2026-05-25)

**Verdict**: needs-attention

**Findings**:
- **[HIGH]** Migration recomputes stars from unsanitized stored best_saved (SaveData.gd:313-316)
  - R4 fix가 record_clear path만 sanitize했고 _migrate_1_to_2는 stored best_saved 직접 사용. v1 save에 best_saved=999 잔존 시 migration이 stars=compute_stars(999, 9, ...)=3으로 inflate. record_clear sanitize는 우회됨.
  - **Recommendation**: _migrate_1_to_2도 동일 sanitize 적용. Migration regression test 추가.

**Fix** (Self-Review Round 6):
1. `_migrate_1_to_2()` body 갱신 — best_saved [0, _STAGE_03_ORIGINAL_HP] 범위 sanitize (out of range → 0 reset + cfg.set_value). best_score [0, 1] 범위 clamp.
2. `SaveDataPhase20MigrationTest case 5` 신규 — v1 stage03 seed with best_saved=999 → migration → stars=0 (sanitized), best_saved=0 검증.

**Regression**: 모든 SaveData test PASS (6종) + phase 1~19 essential 유지.

---

## Self-Review Round 6 (2026-05-25)

### 추가 검증
- [x] **Migration sanitize 동등성**: _migrate_1_to_2와 record_clear가 동일 sanitize 정책 적용. 두 entry point가 일관.
- [x] **외부 corruption 차단 5계층**: (1) v1→v2 migration sanitize, (2) record_clear input validation, (3) record_clear progress mutation 차단, (4) record_clear stored sanitize, (5) Scoring.compute_stars invalid threshold guard.
- [x] **regression breadth**: SaveDataPhase20MigrationTest 4 case (legit 8/9, 5/9, 4/9, poisoned 999) + SaveDataMalformedClearNoDowngradeTest 6 case + 기존 SaveData test 4종 = 14 SaveData regression.
- [x] **legit happy path 무영향**: poisoned 999가 detected되는 path만 sanitize. Normal saves에 영향 X.

### HIGH 0 / MEDIUM 0 / LOW 0 (Self-Adversarial Round 6)

Self-Adversarial Round 6 clean. codex adversarial-review Round 6 진행 → **clean (approve)**.

---

## Round 6 (codex adversarial-review, 2026-05-25) — **clean**

**Verdict**: approve

**Summary**: Round 6 migration path now sanitizes stage03 v1 best_saved before recomputing stars, persists the sanitized cfg through the existing load/save flow, and the focused regression covers the prior inflation case. No material findings.

**Phase 20 impl 종결** — 11 .gd 수정 + 1 .tscn 수정 + 1 .tres 수정 + 1 svg 신규 + 2 stage layout 신규 + 2 stage data 신규 + 2 stage scene 신규 + 12 test 신규(10 core + 2 SaveData hardening regression) + plan v3.1 + impl-review (Round 1~6 누적) = 약 35 file 변경. `large_change_ok: false` cap 안.

**MVP 종료 확인**:
- 모든 phase 1~19 essential test PASS (Stage02HeadlessTest, Stage03HeadlessTest, GameFlowTest, ScoringStarsTest, SaveDataRecordClearTest, StageDialogShowResultTest, StageDialogSfxTest, SceneFlowEmitContractTest, WaterHazardLossEmptyHandTest, StickyStuckReleaseTest, SettlementTraitTransferTest, CutterCutThroughVineTest, BasherTunnelThroughWallTest, BridgeOverWaterTest, WaterStickyOverlapLostTerminalTest)
- Phase 20 신규 12 test PASS
- 톤 정책 0 forbidden token

