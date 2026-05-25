# Phase 20 Plan — polish (MVP 종료) v3.1

**Status**: plan v3.1 — Round 2 HIGH 1건(R2-H1 SceneFlow ban list 모순) + MEDIUM 1건(R2-M1 Subtitle 누적 별점 모순) + LOW 1건(R2-L1 test 카운트 stale) inline fix 검토 완료. Round 3 검토 결과 HIGH 0건, MEDIUM/LOW 0건으로 plan-stage 종결. plan-stage 정책: CLAUDE.md "Plan stage 3-round cap (R1→fix→R2→fix→R3, R3 HIGH STOP)" 2026-05-25 갱신 적용.

---

## 0.000 v3 → v3.1 변경 (Round 3 검토 종결 정리)

| # | 항목 | v3 | v3.1 |
|---|---|---|---|
| R3-VERIFY | Round 2 fix 검증 | Status와 §5.2가 아직 "Round 3 진입 직전/TBD"로 남아 있어 plan-stage가 계속 열린 상태처럼 보임 | Round 3 검토 결과를 plan/review에 기록. R2-H1/R2-M1/R2-L1 구현 지시 구간이 닫힌 것을 확인하고 plan-stage 종결로 갱신 |
| R3-VERIFY | SceneFlow scope | §2.8 ban list와 §3.4는 이미 R2-H1 fix를 반영했으나 상태 문구가 미정 | §2.8의 struck-through SceneFlow 항목은 "수정 대상으로 이동"만 의미하고, §3.4가 `>=` → `==` 변경의 단일 SoT임을 유지. 추가 코드 변경 없음 |
| R3-VERIFY | Subtitle/test count | §0/§4.3는 이미 Subtitle 기존 표시 + 신규 10 test로 정리됐으나 상태 문구가 미정 | plan-stage 종결 문구로 갱신. 누적 별점 합계 표시는 §6 deferred 유지, 신규 test count는 10 유지 |

> v3.1은 새 기능 범위 변경이 아니라 Round 3 검토 결과를 반영한 문서 상태 정리다. 구현 SoT는 v3 본체와 동일하며, SceneFlow/SaveData/StageDialog/Ant/Sfx/Test 명세 변경 없음.

## 0.00 v2 → v3 변경 (codex Round 2 finding 3건 inline fix)

| # | 항목 | v2 | v3 | finding |
|---|---|---|---|---|
| R2-H1 | §2.8 ban list + §3.4 SceneFlow | §2.8에 SceneFlow 두 줄(struck-through + unstruck 충돌). unstruck 줄이 "last-stage 라우팅 전부 그대로"로 무변경 주장 — implementer가 R1-H4 fix 건너뛸 위험. §3.4도 SceneFlow "이미" equality 계산한다고 stale 주장 (실제 코드는 `>=`) | **§2.8 unstruck SceneFlow 줄 삭제** — struck-through 줄(§2.2 이동 안내)만 유지. **§3.4 재작성** — phase 20에서 SceneFlow.gd:163 1줄 `>=` → `==` 변경을 명시. (a) SceneFlow 1줄 등치 변경 + (b) StageDialog Title.text 분기 두 가지 묶음으로 last-stage 메시지 강화. SceneFlow 다른 라인은 무변경 명시 | codex R2-H1 [high] — ban list contradiction이 fix를 가림 |
| R2-M1 | §0 한 줄 요약 Subtitle 설명 | "Subtitle은 누적 별점 합계 표시" — P-D6와 §6 deferred(누적 별점 표시는 본 phase scope 외)와 모순 | **§0 한 줄 요약 수정** — "Subtitle은 phase 12 기존 표시(`saved {n} / {original_hp} 조각`) 그대로 유지. 누적 별점 합계 표시는 §6 deferred (SaveData.total_stars()는 phase 13 산출이지만 본 phase 호출 안 함)" 명시. §0과 P-D6/§6 정합 | codex R2-M1 [medium] — §0 vs §1.2 P-D6/§6 스코프 모순 |
| R2-L1 | §0.0 / §0 / §2.6 test 카운트 8 | "8 test PASS" stale (§4/§5는 10으로 정정됨) | **§0 → "10 test PASS" + 신규 2종 명시. §2.6 AntStickyVisualTest 끝의 "R1-L1 카운트 8 일치" → "R2-L1 카운트 10 일치"로 정정** + 10건 목록 enumerate. 본 §0.00 변경표가 명시적으로 새 카운트 박제 | codex R2-L1 [low] — 카운트 stale (3 곳) |

> v3 본체(§1~§9)는 v2의 design을 보존하고 R2-H1/M1/L1 fix에 한해 inline 수정. R1 9건 fix는 v2 산출 그대로(§0.0 v1→v2 변경표 참조). v3.1 Round 3 검토에서 R2 fix가 implementation 지시 구간에 일관되게 반영된 것을 확인했다.

---

## 0.0 v1 → v2 변경 (codex Round 1 finding 9건 inline fix)

| # | 항목 | v1 | v2 | finding |
|---|---|---|---|---|
| R1-H1 | §2.5 dev id 점유 (sticky_settle_test) | `id=917` 신규 점유 명시 | **`id=914` 변경**. 914는 phase 17 plan §2.5 v3 note에서 sticky_settle_test에 예약했으나 phase 17 impl 시점에 미사용 → 본 phase가 정식 점유. 917은 `data/stages/dev/basher_wall_test.tres:7`가 이미 점유 중. dev id 표도 §2.5에서 갱신 | codex R1-H1 [high] — 917 충돌 (basher_wall_test) |
| R1-H2 | F-D3 / §2.8 SaveData ban list / §3.1 | `scripts/core/SaveData.gd` **무변경** — SaveData가 글로벌 STAR_THRESHOLDS만 사용 → StageDialog(override)와 desync. stage03 saved=8 시 UI 1 star vs SaveData 2 star | **SaveData.record_clear 시그니처 확장** — `record_clear(stage_id, saved, original_hp, thresholds: Array = [])`. `_on_stage_cleared`가 `result.get("star_thresholds", [])` 4번째 인자로 전달. SaveData를 §2.2 수정 대상으로 추가, §2.8 ban list에서 제거. 신규 회귀 `SaveDataStarOverrideTest`로 stage03 override가 SaveData stars 필드까지 정확히 반영 검증 | codex R1-H2 [high] — UI/Data star desync |
| R1-H3 | P-D5 / §2.2 Ant.gd / §3.3 `_update_sprite` | `if is_stuck(): _sprite.pause(); return` 1줄. "stuck 해제 시 다음 frame 자연 play() 재개" 가정 | **`_sprite_paused_for_sticky: bool` flag 추가 + 명시 `_sprite.play(_last_anim)` 재호출**. Ant.gd `_update_sprite()`가 `if is_stuck(): if not _sprite_paused_for_sticky: _sprite.pause(); _sprite_paused_for_sticky = true; return`. unstuck 분기: `if _sprite_paused_for_sticky: _sprite.play(_last_anim); _sprite_paused_for_sticky = false`. AntStickyVisualTest에 unstuck 후 `_sprite.is_playing() == true` 검증 추가 | codex R1-H3 [high] — anim == _last_anim이라 play() 미호출, 영구 pause |
| R1-H4 | F-D5 / §2.8 SceneFlow ban list / §3.4 | `is_last_stage == (result.stage_id == LAST_STAGE_ID)` 등치 주장. SceneFlow 무변경 | **SceneFlow.gd:163 1줄 수정** — `result["stage_id"] >= LAST_STAGE_ID` → `result["stage_id"] == LAST_STAGE_ID` 변경 (의도적 1줄 변경). SceneFlow를 §2.2 수정 대상으로 추가, §2.8 ban list에서 제거. 신규 회귀 `SceneFlowLastStagePredicateTest`로 (a) stage_id=3 → is_last=true, (b) stage_id=2 → is_last=false, (c) 가상 stage_id=4(미존재이지만 미래 STAGE_SCENES 확장 대비) → is_last=false 검증. dev stage(910~)는 STAGE_SCENES에 미등록이라 load_stage fallback 차단 — 자연 분기 유지 | codex R1-H4 [high] — `>=`로 미래 stage 추가 시 last 오인 |
| R1-M1 | §header phase12-deferred SoT 참조 | (내 plan v1에는 phase12-deferred 직접 참조 0건. codex가 task 메시지 SoT를 plan으로 착각) | **plan v2 §0 한 줄 요약에 명시 1줄 추가** — "본 phase 20이 sfx 8 id를 직접 정의(`candy_pick`/`ant_save`/...). phase 12는 `sfx_request(id: StringName)` 시그널 contract만 제공, deferred 파일 없음." | codex R1-M1 [medium] — SoT 명시화 (실제 plan에 stale 참조 없으나 명확화) |
| R1-M2 | §3.1 Scoring.compute_stars 검증 | `var th = thresholds if not thresholds.is_empty() else STAR_THRESHOLDS`로만 사용 — length 검증 X. malformed Array[float]([0.1, 0.5, 0.8, 0.95])(4 elem) 입력 시 4 star 반환 가능 — StageDialog star 3개 노드와 desync | **Scoring.compute_stars 입력 검증 추가** — `if not thresholds.is_empty() and thresholds.size() != STAR_THRESHOLDS.size(): push_warning(...); return 0` + ascending sort check (`for i in range(1, th.size()): if th[i] < th[i-1]: push_warning(...); return 0`) + clamp check (`for t in th: if t < 0.0 or t > 1.0: push_warning(...); return 0`). 잘못된 thresholds는 0 star + warning. StageData export 시 `_init`/validate에 동일 가드 추가는 본 phase scope 외(데이터 검증은 데이터 작성자 책임 + Scoring 함수가 single defense line). ScoringStarsOverrideTest에 invalid case 3건(길이 4, descending, out-of-range) 검증 추가 | codex R1-M2 [medium] — invalid array silent 통과 위험 |
| R1-M3 | P-D4 / §3.3 `_sticky_max` | `_sticky_max = max(_sticky_max, dur)` — `_sticky_remaining`이 0이 된 후 새 sticky 진입 시 옛 max 잔존 → bar 시작값 1/3 등 부정확 | **`_sticky_remaining == 0` 도달 시 `_sticky_max` reset**. `_physics_process(delta)`의 `if _sticky_remaining > 0: _sticky_remaining = max(0, _sticky_remaining - delta)` 직후 `if _sticky_remaining == 0.0: _sticky_max = 0.0` 1줄 추가. apply_sticky에서는 `if _sticky_remaining == 0.0: _sticky_max = dur; else: _sticky_max = max(_sticky_max, dur)` 분기로 fresh entry 시 새 dur 사용. AntStickyVisualTest에 2회 apply_sticky 시나리오(3.0s → 1.0s 재진입) 추가 검증 | codex R1-M3 [medium] — denominator stale |
| R1-L1 | §4.2 / §5.3 "신규 7 test" | 7 test 주장하나 §2.6에 실제 8 test 명세 | **8 test로 일괄 정정**. §4.2 / §5.3 / 본 v2 변경표 정합 | codex R1-L1 [low] — 카운트 불일치 |
| R1-L2 | §2.3 / §2.9 StickyTimerBar 텍스처 경로 | `assets/icons/skills/sticky.svg` 또는 placeholder 둘 중 (sticky.svg 존재 X) | **`assets/icons/sticky_timer_bar.svg` 신규 placeholder 1개로 확정** — 16x4 단색 노란(LEMON 계열) svg. 본 phase impl 시점에 생성. art polish는 phase 21 또는 별도 art phase | codex R1-L2 [low] — 미존재 path 잔존 |

> v2 본체(§1~§9)는 v1의 design을 보존하고 R1-H1/H2/H3/H4 + R1-M1/M2/M3 + R1-L1/L2 fix에 한해 inline 수정. SaveData·SceneFlow 변경은 codex R1-H2/H4 finding 대응으로 §2.2 수정 대상에 추가됨.

---

**Status (history)**: v1 draft → v2 Round 1 fix → v3 Round 2 fix → v3.1 Round 3 검토 종결. plan-stage 정책: CLAUDE.md "Plan stage 3-round cap (R1→fix→R2→fix→R3, R3 HIGH STOP)" 2026-05-25 갱신 적용.

**Phase frontmatter doc**: [phases/mvp/phase20-polish.md](../phase20-polish.md)

**1차 SoT 인용**:
- [docs/PRD.md](../../../docs/PRD.md) — MVP 정의, 8종 스킬, Release Rate 슬라이더, 클리어/점수 분리
- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) — ScoreSystem 4-카운터(ADR-002), EventBus 시그널, Area2D 트리거 계약
- [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §3.5 (4-카운터 무변경), §0.2 (어휘 정책), §0.7.5 (stuck-until-timeout), §1·§2.1 (Bomber 삭제 + 별 시스템/정산 UI/끈끈이 후처리)
- [phases/mvp/REVISION_2026-05-18-option-b.md](../REVISION_2026-05-18-option-b.md) §3.1 (phase 20 = polish, 무게 9000)

**관련 코드 SoT**:
- `scripts/core/EventBus.gd:18` — `signal sfx_request(id: StringName)` 기존 보유 (phase 12)
- `scripts/core/Scoring.gd` — `static func compute_stars(saved, original_hp) -> int` 기존 보유 (phase 12), `STAR_THRESHOLDS := [0.50, 0.80, 0.95]`
- `scripts/core/StageData.gd:1-13` — `star_thresholds` 필드 미보유 (본 phase 신규 추가)
- `scripts/core/StageRunner.gd:138-148` — `_make_result()` 8 키 (stage_id/cleared/saved/lost/original_hp/score/time_left/reason). 본 phase에서 `star_thresholds` 1 키 추가
- `scripts/core/AntSpawner.gd` — Release Rate 1~99 정수, `set_release_rate`/`release_rate_changed` 시그널 기존 보유 (phase 8/11)
- `scripts/ui/ReleaseRateStepper.gd` — HUD ± UI 기존 보유 (phase 11)
- `scripts/ui/StageDialog.gd` — `show_result(result, is_last_stage)` 기존 보유 (phase 12). 본 phase에서 (a) star_thresholds 인자 경유 (b) last-stage+cleared Title text 분기 추가
- `scripts/ant/Ant.gd` — `_sticky_remaining: float`, `apply_sticky`, `is_stuck` API 기존 보유 (phase 17). 본 phase에서 (a) `_update_sprite` stuck 분기 (b) StickyProgressBadge 시각 추가
- `scripts/world/hazards/HazardBase.gd` / `WaterHazard.gd` / `StickyHazard.gd` — phase 17 산출
- `scripts/world/Candy.gd:42` — `EventBus.candy_piece_picked` emit. 본 phase에서 `sfx_request(&"candy_pick")` 1줄 추가
- `scripts/world/Home.gd` — `EventBus.ant_saved` emit 위치. 본 phase에서 `sfx_request(&"ant_save")` 1줄 추가
- `scripts/ant/states/LostState.gd` (phase 17) — `EventBus.candy_piece_lost` emit. 본 phase에서 `sfx_request(&"candy_lost")` 1줄 추가
- `scripts/world/Candy.gd:53` — `EventBus.candy_depleted` emit. 본 phase에서 `sfx_request(&"candy_depleted")` 1줄 추가
- `scripts/core/StageRunner.gd:99/108/114` — `stage_cleared`/`stage_failed` emit. 본 phase에서 `sfx_request(&"stage_cleared"|&"stage_failed")` 1줄 추가
- `scripts/world/hazards/WaterHazard.gd::_handle_ant_entry` — `sfx_request(&"water_splash")` 1줄 추가
- `scripts/world/hazards/StickyHazard.gd::_handle_ant_entry` — `sfx_request(&"sticky_glue")` 1줄 추가

**리뷰 보존**: [phases/mvp/reviews/phase20-plan-review.md](../reviews/phase20-plan-review.md) (codex round별 누적 — 본 plan stage codex 첫 라운드 진입 시 생성)

**작성**: 2026-05-25 (v1 draft), 2026-05-25 (v2 Round 1 fix), 2026-05-25 (v3 Round 2 fix), 2026-05-25 (v3.1 Round 3 검토 종결)

---

## 0. 한 줄 요약

MVP 종료 phase. **5개 묶음**으로 좁힌다 — (1) **끈끈이 후처리 4 deferred** (D-1/D-2/D-5/D-6: phase 17 `phase17-deferred.md` 박제 항목 중 회귀 가치 높은 4종 + 신규 layout 2종 `dev_water_after_candy_layout` + `dev_sticky_settle_layout`). (2) **sfx_request emit 위치 확대 8개 id** (`candy_pick`/`ant_save`/`candy_lost`/`candy_depleted`/`stage_cleared`/`stage_failed`/`water_splash`/`sticky_glue` — receiver는 phase 21 sound-bgm-sfx 산출이므로 본 phase는 emit 위치만 freeze). **본 phase 20이 sfx 8 id를 직접 정의 — phase 12 산출은 `sfx_request(id: StringName)` 시그널 contract + dialog 4 id(`dialog_open`/`dialog_stats_pop`/`star_fill`/`dialog_btn_press`)만 제공, phase 12 deferred 파일 없음** (R1-M1 명시). (3) **stage별 별 산정 임계값 override** (`StageData.star_thresholds: Array[float] = []` 신규 필드 + `Scoring.compute_stars(saved, original_hp, thresholds := [])` 시그니처 확장 + **invalid thresholds 0 star + warning fall-back**(R1-M2). 빈 배열이면 글로벌 `STAR_THRESHOLDS` fall-back. `StageRunner._make_result`에 `"star_thresholds"` 1 키 추가, `StageDialog.show_result`가 그 값을 Scoring에 전달. **`SaveData.record_clear` 시그니처 확장** (`thresholds: Array = []` 4번째 인자) — `_on_stage_cleared`가 `result.get("star_thresholds", [])`를 전달해 UI(StageDialog) 별점과 영속 데이터(SaveData stage_progress.stars)가 항상 일치 (R1-H2)). (4) **시각 polish**: stuck progress bar (`Ant.tscn` `StickyTimerBar: Sprite2D` 신규 — horizontal scale = `_sticky_remaining / _sticky_max`, `_sticky_remaining==0` 도달 시 `_sticky_max` reset(R1-M3)) + stuck walk animation 정지 (`Ant._update_sprite`에 `is_stuck()` 분기 + **`_sprite_paused_for_sticky: bool` flag로 unstuck 시 명시 `_sprite.play(_last_anim)` 재호출**(R1-H3)). (5) **last-stage StageDialog Title 분기** — phase 12에서 `show_result(result, is_last_stage)`가 이미 `is_last_stage` 인자 받음. `is_last_stage && cleared` 시 Title.text를 "마지막 단계 클리어!"로 분기. **Subtitle은 phase 12 기존 표시(`saved {n} / {original_hp} 조각`) 그대로 유지** — 누적 별점 합계 표시는 §6 deferred(SaveData.total_stars()는 이미 phase 13 산출이지만 본 phase는 호출 안 함). **별도 cinematic 씬 X. SceneFlow 1줄 수정** — `SceneFlow.gd:163` `result["stage_id"] >= LAST_STAGE_ID` → `== LAST_STAGE_ID` 등치로 변경(R1-H4 / R2-H1, 미래 stage 추가 시 last 오인 회피). MainMenu 라우팅 phase 13 산출 그대로 재사용 (사용자 결정 ④ "현행 유지"). 

**MVP 종료 검증**: 모든 기존 stage01~03 + dev_* + headless test PASS + 신규 **10 test** PASS(R1-L1 → R2-L1 카운트 정정: D-1, D-2, D-5, D-6, SfxRequestEmit, ScoringStarsOverride, StageDialogLastStageTitle, AntStickyVisual, SaveDataStarOverride [R1-H2], SceneFlowLastStagePredicate [R1-H4]). Bomber 미도입 (PROPOSAL §1 / §3.4.2 Cutter로 대체 — phase 19 완료). Release Rate / 별 시스템 / 정산 UI / sfx hook은 phase 8/11/12에서 이미 구현 완료 — **본 phase는 emit 확대 + override + polish만 추가, 신규 시스템 0건**. SceneFlow·SaveData 1~2줄씩 수정은 codex Round 1 R1-H2/H4 finding 대응(원래 v1은 무변경 가정).

본 phase 20 frontmatter doc의 6 Open decisions 중 D1(release rate 단위) / D2(release rate UI 위치) / D4(사운드 hook 인터페이스) / D6(post-MVP receiver contract)은 phase 8/11/12 산출로 자명 해결. 본 plan §1에서 D3(별 산정 기준) / D5(피날레 시퀀스) 결정 + 본 plan 도출 결정 6건.

---

## 1. Open decisions before implementation — 결정

### 1.1 frontmatter doc §"Open decisions" 6건 처리

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| F-D1 | Release Rate 단위 | **이미 구현** — `AntSpawner.release_rate: int` (1~99 정수). `_interval_for(rate)`가 lerpf로 2.0초~0.05초 spawn interval 매핑. stage 데이터 override 가능(`StageData.release_rate_initial`). 본 phase 추가 작업 0 | `AntSpawner.gd:8/37-45`, `StageData.gd:12-13` 기존. 핵심: stage 데이터로 stage별 시작 rate 조정 가능, 플레이 중 KB(F1/F2)·Pad(D-Pad↑↓)·HUD ± 클릭으로 조정 (RR_STEP=5) |
| F-D2 | Release Rate UI 위치 | **이미 구현** — HUD 내 `ReleaseRateStepper` 위치 (CButton− Value Label CButton+). 본 phase 추가 작업 0 | `scripts/ui/ReleaseRateStepper.gd` 기존 (phase 11) |
| F-D3 | 별 산정 기준 | **stage별 override 가능 — 기본은 글로벌 fall-back** (사용자 결정 ①). `StageData.star_thresholds: Array[float] = []` 신규 필드. `Scoring.compute_stars(saved, original_hp, thresholds := [])` 시그니처 확장. 빈 배열이면 `Scoring.STAR_THRESHOLDS` const 사용. **invalid thresholds(길이≠3, descending, 0..1 범위 외) 입력 시 0 star 반환 + push_warning** (R1-M2). **시간 보너스 불포함** — `time_left`는 정산 UI 표시만(`ChipTime`). 점수에 반영 X (KISS, PRD §"클리어/점수 분리" 그대로). 모든 stage data(stage01~03 + dev_*)은 본 phase에서 default `star_thresholds = []` 빈 배열 유지 — 글로벌 fall-back. 단, **stage03(last stage)만 `[0.55, 0.85, 0.97]`로 약간 더 빡빡하게 override** (마지막 단계 도전성 증가). **`SaveData.record_clear` 시그니처도 확장** (R1-H2) — `record_clear(stage_id, saved, original_hp, thresholds: Array = [])` + `_on_stage_cleared`가 `result.get("star_thresholds", [])` 전달. UI(StageDialog) 별점과 영속 데이터(SaveData stage_progress.stars) 일치 보장 | 사용자 결정 ①. 글로벌 fall-back으로 기존 회귀 0건 보장. stage03만 override = 데이터 변경 1건 + UI/Data 동기 회귀 1 test |
| F-D4 | 사운드 hook 인터페이스 | **이미 구현** — `EventBus.sfx_request(id: StringName)` autoload signal (phase 12 `EventBus.gd:18`). 전용 SoundController autoload는 phase 21 산출. 직접 함수 호출은 채택 안 함(autoload signal로 통일) | phase 12 plan §3.7 freeze. receiver는 phase 21에서 EventBus.sfx_request.connect로 받음 |
| F-D5 | 피날레 시퀀스 | **현행 유지** (사용자 결정 ④) — last-stage Stage03 clear 시 phase 12 산출 그대로: NextBtn visible=true/disabled=true, ReplayBtn/MenuBtn 정상. Menu 클릭 시 phase 13 산출 그대로 `EventBus.request_main_menu` emit → SceneFlow가 MainMenu 라우팅. **단, StageDialog Title text 분기 추가** — `is_last_stage && cleared`일 때 Title.text를 "마지막 단계 클리어!" 등으로 변경(기본은 "스테이지 클리어!"). 별도 cinematic 씬 X. **SceneFlow.gd:163 1줄 수정** (R1-H4) — `result["stage_id"] >= LAST_STAGE_ID` → `== LAST_STAGE_ID` 등치 변경. 미래 STAGE_SCENES 확장 시 last 오인 회피. dev stage(910~)는 STAGE_SCENES 미등록이라 SceneFlow 경유 안 함 — 자연 분기 유지 | 사용자 결정 ④. MainMenu 라우팅 무변경 = 회귀 위험 최소화. Title 분기 + 등치 변경 1줄 = 최소 변경 |
| F-D6 | post-MVP 사운드 phase 21 receiver contract 위치 | **본 phase 20에서 emit 위치만 freeze, contract 문서화는 phase 21 plan** (id 시퀀스/타이밍/볼륨 등 wire 명세는 phase 21 plan의 §receiver-contract으로 미룸). 본 phase 20 plan §3.2에서 8 id의 emit 시점과 payload만 명세 (`id: StringName` 단일 인자) | F-D4와 동일 정책. 본 phase는 emit 8 위치만 추가, receiver wire 책임 없음 |

### 1.2 본 plan 도출 결정 (구현 디테일 6건)

| # | 결정 항목 | 결정 | 근거 |
|---|---|---|---|
| P-D1 | sfx emit 위치 8 id 선정 (사용자 결정 ② "핵심 게임플레이만") | **고정 8 id**: `candy_pick`(Candy.gd `candy_piece_picked` emit 위치) / `ant_save`(Home.gd `ant_saved` emit 위치, `with_candy=true`만) / `candy_lost`(LostState.enter `candy_piece_lost` emit 위치) / `candy_depleted`(Candy.gd `candy_depleted` emit 위치) / `stage_cleared`(StageRunner.gd `stage_cleared.emit` 직전) / `stage_failed`(StageRunner.gd `stage_failed.emit` 직전) / `water_splash`(WaterHazard `_handle_ant_entry` 시작) / `sticky_glue`(StickyHazard `_handle_ant_entry` 시작 — D13 중복 가드 통과 후) | 사용자 결정 ② "핵심 게임플레이만". 8 id 모두 게임플레이 핵심 이벤트 — phase 21 sound receiver의 1차 priority. **무게 9000 잠정치 안 cover 가능**. skill cast / counter caPop / pause toggle / rr step은 phase 21에서 일괄 처리 |
| P-D2 | sfx emit naming convention | snake_case StringName (예: `&"candy_pick"`). prefix 없음 — phase 12 기존 4 id(`dialog_open`/`dialog_stats_pop`/`dialog_btn_press`/`star_fill`)와 패턴 일치 | phase 12 plan §3.7 정착 |
| P-D3 | sfx emit 호출 위치 정확성 — pre-emit vs post-emit | **EventBus 시그널 emit 직전** (한 줄 위) — sfx emit이 게임 상태 변화보다 먼저 트리거되도록. 단, sticky_glue는 D13 idempotency 가드 통과 *후* (중복 emit 방지) | 일관성. sfx receiver(phase 21) 입장에서 게임 시그널과 같은 frame에 도착하지만 sfx가 살짝 먼저 — 트리거 시점 명확 |
| P-D4 | stuck progress bar 형식 | **Ant.tscn에 `StickyTimerBar: Sprite2D` 자식 추가** (TraitBadges 노드 아래). position=(0, -24) (StickyBadge 위쪽), texture=`assets/icons/sticky_timer_bar.svg` 16x4 단색 placeholder svg(R1-L2 신규 placeholder 1개 확정), modulate=Color(1, 0.95, 0.4, 0.9). `Ant._physics_process`에서 `_sticky_remaining > 0`이면 `_sticky_bar.scale.x = _sticky_remaining / _sticky_max`(가로 축소) + `visible = true`, 아니면 `visible = false`. **`_sticky_max` 라이프사이클** (R1-M3): (1) `apply_sticky(dur)`에서 `if _sticky_remaining == 0.0: _sticky_max = dur; else: _sticky_max = max(_sticky_max, dur)` — fresh entry는 새 dur, 진행 중 재진입은 더 큰 값 보존. (2) `_physics_process`에서 timer 감소 후 `if _sticky_remaining == 0.0: _sticky_max = 0.0` 1줄 reset. 2회 apply_sticky(3.0s → 1.0s) 시나리오에서 두 번째 entry는 정확히 1.0 → 0 단조 감소 | 별도 ProgressBar 노드는 Theme 의존 + UI/world 좌표계 혼합 위험. Sprite2D scale animation이 단순/저비용. StickyBadge는 phase 17에서 visible toggle만, 본 phase는 그 위에 bar 추가 |
| P-D5 | stuck walk animation 정지 | **`Ant._update_sprite()`에 `is_stuck()` 분기 + `_sprite_paused_for_sticky: bool` flag로 unstuck 시 명시 play() 재개** (R1-H3). pseudo: `if is_stuck(): if _sprite is AnimatedSprite2D and not _sprite_paused_for_sticky: (_sprite as AnimatedSprite2D).pause(); _sprite_paused_for_sticky = true; return`. unstuck 분기(is_stuck false 진입 시): `if _sprite_paused_for_sticky: if _sprite is AnimatedSprite2D and not _last_anim.is_empty(): (_sprite as AnimatedSprite2D).play(_last_anim); _sprite_paused_for_sticky = false`. 기존 `if anim != _last_anim` 로직은 분기 통과 후 그대로 — anim이 변하면 정상 play() 발화 | Ant._update_sprite은 `if anim != _last_anim`일 때만 play() 호출 → unstuck 후 anim 동일(예: stuck 전후 모두 walk)이면 영구 pause. flag + 명시 play(_last_anim) 호출로 차단. _sprite.pause()는 AnimatedSprite2D에만 안전 호출 (정적 Sprite2D면 분기 안 들어감) |
| P-D6 | last-stage Title 분기 위치 | **`StageDialog.show_result(result, is_last_stage)` 내부에서 Title.text 분기 1줄 추가** — `if cleared and is_last_stage: Title.text = "마지막 단계 클리어!"; elif cleared: Title.text = "스테이지 클리어!"; else: Title.text = "사탕 손실"` (현 phase 12 base text 유지 + last-stage variant 1개 추가). Subtitle은 기존 "saved {n} / {original_hp} 조각" 유지 — 누적 별점 합계는 본 phase 미도입(phase 13 SaveData에 데이터는 있으나, 본 phase scope 외) | 사용자 결정 ④ "현행 유지" 안에서 작은 Title 강화만. SceneFlow가 `is_last_stage` 계산해서 `show_result(result, is_last_stage)`로 전달 (phase 12 산출 그대로). Title 분기 1줄 = 최소 변경 |

---

## 2. 변경 대상 파일 — 완전 리스트

### 2.1 신규 (.gd)
| 파일 | 용도 |
|---|---|
| (없음) | 본 phase 신규 .gd 0건 — emit 확대 + 시각 polish + 데이터 override만 |

### 2.2 수정 (.gd)
| 파일 | 변경 | 라인 영향 |
|---|---|---|
| `scripts/world/Candy.gd` | `_on_body_entered` 안 `EventBus.candy_piece_picked.emit(hp)` 직전에 `EventBus.sfx_request.emit(&"candy_pick")` 1줄 추가. `EventBus.candy_depleted.emit()` 직전에 `EventBus.sfx_request.emit(&"candy_depleted")` 1줄 추가 | +2줄 |
| `scripts/world/Home.gd` | `_on_body_entered`(또는 ant.is_returning 처리부) `EventBus.ant_saved.emit(ant, with_candy)` 직전, `with_candy=true`일 때 `EventBus.sfx_request.emit(&"ant_save")` 1줄 추가 (`with_candy=false`는 분배자 정착 후 ant 회수 등 — sfx 안 울림) | +1줄 (조건문 포함 +2~3줄) |
| `scripts/ant/states/LostState.gd` | `enter()` 안 `EventBus.candy_piece_lost.emit(a)` 직전에 `EventBus.sfx_request.emit(&"candy_lost")` 1줄 추가 (has_candy=true 분기 내부) | +1줄 |
| `scripts/core/StageRunner.gd` | (1) `_make_result` Dictionary에 `"star_thresholds": stage_data.star_thresholds` 1 키 추가. (2) `EventBus.stage_cleared.emit(_make_result(true, ""))` 직전에 `EventBus.sfx_request.emit(&"stage_cleared")` 1줄 추가. (3) `EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))` 직전에 `EventBus.sfx_request.emit(&"stage_failed")` 1줄 추가. (4) `EventBus.stage_failed.emit(_make_result(false, "time_out"))` 직전에 동일 sfx emit 1줄 추가 (총 stage_failed sfx emit 2 site — 둘 다 같은 id) | +4줄 |
| `scripts/world/hazards/WaterHazard.gd` | `_handle_ant_entry(ant)` 첫 줄에 `EventBus.sfx_request.emit(&"water_splash")` 1줄 추가 (LostState 전이 직전) | +1줄 |
| `scripts/world/hazards/StickyHazard.gd` | `_handle_ant_entry(ant)` 안 D13 frame-set idempotency 가드 통과 *후*, `ant.apply_sticky(duration)` 직전에 `EventBus.sfx_request.emit(&"sticky_glue")` 1줄 추가 | +1줄 |
| `scripts/core/Scoring.gd` | `compute_stars` 시그니처 확장: `static func compute_stars(saved: int, original_hp: int, thresholds: Array = []) -> int`. 함수 body (R1-M2 검증 추가): (1) 기존 `if original_hp <= 0: return 0` 유지. (2) **신규 입력 검증** — `if not thresholds.is_empty():` 분기 안에 `if thresholds.size() != STAR_THRESHOLDS.size(): push_warning("[Scoring] invalid star_thresholds length: %d (expected %d)" % [thresholds.size(), STAR_THRESHOLDS.size()]); return 0`. 추가로 ascending check (`var prev := -1.0; for t in thresholds: if t < prev or t < 0.0 or t > 1.0: push_warning(...); return 0; prev = t`). (3) `var th: Array = thresholds if not thresholds.is_empty() else STAR_THRESHOLDS`로 사용 후 기존 for 루프 그대로. 빈 배열 fall-back으로 기존 호출자(phase 12 StageDialog, phase 13 SaveData) 회귀 0. invalid override는 0 star + warning으로 silent corruption 차단 | +6~8줄 (검증 + fall-back) |
| `scripts/core/StageData.gd` | 1줄 필드 추가: `@export var star_thresholds: Array[float] = []`. 빈 배열 = 글로벌 fall-back (모든 기존 stage data 회귀 0) | +1줄 |
| `scripts/ui/StageDialog.gd` | (1) `show_result` 안 Scoring.compute_stars 호출부에 `result.get("star_thresholds", [])` 인자 추가 — `Scoring.compute_stars(saved, original_hp, result.get("star_thresholds", []))`. (2) Title.text 분기: `if cleared and is_last_stage: Title.text = "마지막 단계 클리어!"; elif cleared: Title.text = "스테이지 클리어!"; else: Title.text = "사탕 손실"` (현 phase 12 산출에 last-stage variant만 추가 — phase 12 기존 text가 무엇이든 같은 분기 구조로 갱신) | +3줄 (조건 포함) |
| `scripts/ant/Ant.gd` | (1) 신규 필드 `var _sticky_max: float = 0.0` + `var _sprite_paused_for_sticky: bool = false`. (2) `apply_sticky(dur)` 분기 변경 (R1-M3): `if dur > _sticky_remaining: _sticky_remaining = dur; if _sticky_remaining == 0.0: _sticky_max = dur; else: _sticky_max = max(_sticky_max, dur)`. (3) 신규 필드 `var _sticky_bar: Sprite2D = null`. `_ready()`에서 `_sticky_bar = _trait_badges.get_node_or_null("StickyTimerBar") as Sprite2D` 1줄 추가. (4) `_physics_process(delta)` 안 timer 감소 직후 `_sticky_max` reset(R1-M3): `if _sticky_remaining == 0.0: _sticky_max = 0.0` 1줄. (5) `_physics_process` 끝에 `_update_sticky_bar()` 신규 헬퍼 호출 — bar.scale.x = clamp(_sticky_remaining / _sticky_max, 0, 1) + visible toggle. (6) `_update_sprite()` 진입부에 R1-H3 fix — `if is_stuck() and _sprite is AnimatedSprite2D and not _sprite_paused_for_sticky: (_sprite as AnimatedSprite2D).pause(); _sprite_paused_for_sticky = true` then `return`. unstuck 분기(is_stuck false): `if _sprite_paused_for_sticky and _sprite is AnimatedSprite2D and not _last_anim.is_empty(): (_sprite as AnimatedSprite2D).play(_last_anim); _sprite_paused_for_sticky = false`. 기존 anim != _last_anim 로직 그대로 보존 | +10줄 |
| **`scripts/core/SaveData.gd`** (R1-H2 신규 추가) | (1) `record_clear(stage_id: int, saved: int, original_hp: int, thresholds: Array = [])` 시그니처 확장 (default = 빈 배열, 기존 caller 회귀 0). 함수 body의 `Scoring.compute_stars(saved, original_hp)` 호출을 `Scoring.compute_stars(saved, original_hp, thresholds)`로 수정. (2) `_on_stage_cleared(result)`에서 `record_clear(stage_id, ..., result.get("star_thresholds", []))` 4번째 인자 전달. UI(StageDialog)와 영속 데이터(stage_progress.stars) 동기 보장 — stage03 saved=8 시 UI 1 star + SaveData stars=1 동일 | +2~3줄 |
| **`scripts/core/SceneFlow.gd`** (R1-H4 신규 추가) | line 163 `_overlay.show_result(result, result["stage_id"] >= LAST_STAGE_ID)` → `_overlay.show_result(result, result["stage_id"] == LAST_STAGE_ID)` 1줄 등치 변경. 미래 STAGE_SCENES 확장 시 last 오인 회피. dev stage(910~)는 STAGE_SCENES 미등록 → SceneFlow 경유 안 함 (자연 분기 유지) | 1줄 변경 |

### 2.3 수정 (.tscn)
| 파일 | 변경 |
|---|---|
| `scenes/entities/Ant.tscn` | `TraitBadges` 노드 아래 `StickyTimerBar: Sprite2D` 자식 1개 추가. position=(0, -24), texture=`assets/icons/sticky_timer_bar.svg`(R1-L2 신규 placeholder — 16x4 단색 노란 svg, impl 시점 생성), modulate=Color(1, 0.95, 0.4, 0.9), scale=(1.0, 1.0), visible=false. phase 17의 `StickyBadge: Sprite2D`(position (0, -16))는 그대로 유지 — bar는 그 위에 별도 |

### 2.4 수정 (.tres — stage data)
| 파일 | 변경 |
|---|---|
| `data/stages/stage03.tres` | 1줄 추가: `star_thresholds = Array[float]([0.55, 0.85, 0.97])` — 마지막 단계 도전성 증가 (default 0.50/0.80/0.95보다 약간 빡빡). stage01/02 + 모든 dev_*는 default `[]` 빈 배열 → 글로벌 fall-back 사용 (회귀 0건) |

### 2.5 신규 (dev layout + stage data + stage scene)

| 파일 | 용도 |
|---|---|
| `data/stage_layouts/dev_water_after_candy_layout.tres` | StageLayoutData. cell_size=32. home 좌측 + candy 우측 사이에는 floor 평탄 (Water 없음). candy → home 귀환 경로(즉 candy 우측에서 home 좌측으로 돌아오는 길)에 Water cell 1~2개 배치. 빈손 ant는 자유롭게 candy 도달 가능 → carrying ant만 Water 진입 시 lost |
| `data/stages/dev/water_after_candy_test.tres` | StageData. **id=916** (dev 예약, 본 phase 신규 점유 — `grep ^id data/stages/dev/*.tres`로 916 미점유 확인). display_name="dev-water-after-candy". available_skills=`[]`. total_ants=4, candy_hp=4, time_limit=90, release_rate_initial=30, **star_thresholds=`[]`** (글로벌 fall-back 검증 cross check) |
| `scenes/stages/dev/WaterAfterCandyTest.tscn` | Stage scene. Stage02 패턴 + dev_water_after_candy_layout wiring. World 아래 Water.tscn 인스턴스 1~2개 (귀환 경로) |
| `data/stage_layouts/dev_sticky_settle_layout.tres` | StageLayoutData. cell_size=32. SettlementMarker가 Sticky cell 또는 그 인접 cell에 배치. 분배자 ant가 sticky 진입 → stuck → SettlementMarker.body_entered 같은 frame 발화 → 정착 → 후속 ant에 floater trait 전이 |
| `data/stages/dev/sticky_settle_test.tres` | StageData. **id=914** (R1-H1 fix — 917은 `basher_wall_test.tres` 점유 충돌. 914는 phase 17 plan §2.5 v3 note에서 예약했으나 phase 17 impl 시점에 미사용 → 본 phase가 정식 점유. `grep ^id data/stages/dev/*.tres`로 914 미점유 확인). display_name="dev-sticky-settle". available_skills=`[]` (분배자는 별도 메커니즘 — phase 14/15 산출). total_ants=3, candy_hp=2, time_limit=60, release_rate_initial=20. **star_thresholds=`[]`** |
| `scenes/stages/dev/StickySettleTest.tscn` | Stage scene. World 아래 Sticky.tscn 1개 + SettlementMarker 1개 (같은 또는 인접 cell) |

**dev id 정책 갱신 (R1-H1 fix)**: id ≥ 900 dev 예약. 현재 점유 (`grep ^id data/stages/dev/*.tres` 확인 결과):
- 901~904: phase 14 (trait_test, settle_test, settle_test_stuck, settle_test_race)
- 905~909: phase 16 (sand_mound_test, bridge_test, bridge_too_long_test, sand_bridge_overlap_test, bridge_reject_test)
- 910~913: phase 17 (water_test, sticky_test, bridge_over_water_test, water_sticky_overlap_test)
- **914: phase 20 sticky_settle_test (신규)** — phase 17 plan §2.5 v3 note 예약, phase 17 impl 미사용. 본 phase 정식 점유
- 915: phase 17 (bridge_over_overlap_test)
- **916: phase 20 water_after_candy_test (신규)** — 본 phase 점유. grep으로 미점유 확인
- 917~919: phase 18 (basher_wall_test=917, digger_pillar_test=918, basher_digger_chain_test=919)
- 920: phase 19 (cutter_vine_test)

> R1-H1 finding 정정: v1에서 sticky_settle=917으로 잘못 명시(basher_wall과 충돌) → 914로 재할당. dev id 표는 본 갱신본이 1차 SoT, 이전 phase plan note 우선.

### 2.6 신규 (tests/)
| 파일 | 검증 |
|---|---|
| `tests/WaterHazardLossCarryingTest.tscn/gd` (**D-1**) | 헤드리스. `dev_water_after_candy_layout` 사용. ant 4명. (1) candy 픽업 → 운반 중 Water 진입 → `lost_pieces += 1` + `in_transit -= 1`. **PASS**: 90초 내 (a) `lost_pieces >= 1`, (b) `in_transit_pieces == 0` (운반 끝남, 빈손 ants는 자유), (c) ScoreSystem invariant 유지, (d) `EventBus.sfx_request(&"candy_lost")` 1회 이상 emit (LostState 진입 시 has_candy=true 분기) |
| `tests/StickyCarryingPreservedTest.tscn/gd` (**D-2**) | 헤드리스. `dev_sticky_layout`(phase 17 기존) 또는 carrying 경로용 별도 layout. ant가 candy 픽업 → 운반 중 Sticky 진입 → stuck 동안 `has_candy=true` 유지 + `in_transit_pieces == 1` 유지 + `lost_pieces` 무변. timer 만료(3.5s) 후 carrying 정상 재개 + candy 도달 → home 회수. **PASS**: (a) stuck 시점 `has_candy=true && in_transit_pieces == 1`, (b) 3.5초 후 carrying 정상, (c) 60초 내 `saved_pieces >= 1`, (d) `EventBus.sfx_request(&"sticky_glue")` 1회 emit |
| `tests/DistributorOnStickyTransferTest.tscn/gd` (**D-5**) | 헤드리스. `dev_sticky_settle_layout`. 분배자 ant가 sticky 진입 → stuck → SettlementMarker.body_entered 같은 frame 발화 → 정착(SettledState). 정착 후 후속 walker 진입 → floater trait 전이. **PASS**: 30초 내 (a) 분배자 SettledState 도달, (b) 후속 walker `has_trait(&"floater") == true`, (c) ScoreSystem invariant 유지, (d) sfx emit 확인은 D-2와 중복이라 생략 |
| `tests/SettledImmuneToHazardTest.tscn/gd` (**D-6**) | 헤드리스. 신규 layout 또는 기존 `dev_settle_test.tres` 변형 — SettlementMarker · Water 인접 배치. 분배자 정착 후 test driver가 정착 ant를 강제로 Water area로 이동(`ant.global_position` 갱신) → body_entered 발화하지만 HazardBase D13 `not ant.is_alive()` 가드(SettledState ant는 is_alive=false)로 LostState 미진입. **PASS**: (a) 분배자 SettledState 도달 후 Water entry 시도 → `ant.state_machine.current_state is SettledState` 유지, (b) `lost_pieces` 무변. 별도 layout `dev_settled_water_adjacent_layout` 신설 또는 기존 layout 재활용 (round 1에 확정) |
| `tests/SfxRequestEmitTest.tscn/gd` (**P-D1 회귀 가드**) | 헤드리스. dev stage 다중 시나리오 — Stage01 자체 실행 + dev_water_layout. test driver가 `EventBus.sfx_request` 구독해서 id 시퀀스 캡처. **PASS**: 60초 내 다음 id 모두 1회 이상 발화 — `candy_pick` (Candy 픽업 시), `ant_save` (Home 회수 시), `candy_lost` (Water 진입 시 carrying 분기), `candy_depleted` (사탕 hp 0 도달 시), `stage_cleared` (clear 시), `water_splash` (Water 진입 시), `sticky_glue` (Sticky 진입 시 — 별도 sticky stage). `stage_failed`는 별도 fail 시나리오(timer 만료 stage)에서 검증 (sub-test) |
| `tests/ScoringStarsOverrideTest.tscn/gd` (**F-D3 회귀 가드**) | 헤드리스. Scoring.compute_stars 단순 호출 — `compute_stars(0, 10) == 0`, `compute_stars(5, 10) == 1`, `compute_stars(8, 10, [0.50, 0.80, 0.95]) == 2`, `compute_stars(8, 10, [0.55, 0.85, 0.97]) == 1`(8/10=0.8 < 0.85), `compute_stars(9, 10, [0.55, 0.85, 0.97]) == 2`(0.9 >= 0.85), `compute_stars(10, 10, [0.55, 0.85, 0.97]) == 3`(1.0 >= 0.97). 빈 배열 fall-back: `compute_stars(8, 10, []) == 2` (글로벌 STAR_THRESHOLDS와 동일) |
| `tests/StageDialogLastStageTitleTest.tscn/gd` (**P-D6 회귀 가드**) | 헤드리스. StageDialog 인스턴스 → `show_result({saved:10, lost:0, original_hp:10, score:1.0, cleared:true, stage_id:3, reason:"", time_left:30.0, star_thresholds:[0.55, 0.85, 0.97]}, true)` 호출 → `Title.text == "마지막 단계 클리어!"` 검증. `is_last_stage=false`(stage01/02) 시 `Title.text == "스테이지 클리어!"` 검증. fail 시 `Title.text == "사탕 손실"` 검증 |
| `tests/AntStickyVisualTest.tscn/gd` (**P-D4/P-D5 회귀 가드**) | 헤드리스. Ant 인스턴스 → `apply_sticky(3.0)` 호출. 매 frame `_sticky_bar.visible` 검증 — stuck 중 true, stuck 해제 후 false. `_sticky_bar.scale.x`가 단조 감소 (`3.0 / 3.0 = 1.0` → `0`). 시간 1.5s 시점 scale.x ≈ 0.5 ± 0.05. **R1-H3 sprite resume 검증**: stuck 진입 시 `_sprite.pause()` 호출 + `_sprite.is_playing() == false`, stuck 해제 후 1 frame 안에 `_sprite.is_playing() == true` (anim이 walk → walk로 동일하더라도 명시 play() 호출됨). **R1-M3 _sticky_max reset 검증**: `apply_sticky(3.0)` 후 3.5초 대기(timer 만료 + `_sticky_max == 0` 확인) → `apply_sticky(1.0)` 재호출 → 첫 frame `_sticky_bar.scale.x == 1.0` (stale 3.0이 denominator로 안 잡힘 = 0.33 아닌 1.0). **R2-L1 카운트 10 일치** — 본 plan §2.6 신규 test 10건 (D-1, D-2, D-5, D-6, SfxRequestEmit, ScoringStarsOverride, StageDialogLastStageTitle, AntStickyVisual, SaveDataStarOverride, SceneFlowLastStagePredicate) |
| `tests/SaveDataStarOverrideTest.tscn/gd` (**R1-H2 회귀 가드** — 신규) | 헤드리스. SaveData autoload `_test_reset` 후 `record_clear(3, 8, 10, [0.55, 0.85, 0.97])` 호출 → `stage_progress[3].stars == 1` (0.8 < 0.85 = 1 star). 동일 시나리오에서 thresholds 빈 배열 fall-back: `record_clear(3, 8, 10, [])` → `stars == 2` (글로벌 0.80 fall-back). `_on_stage_cleared` 시그널 시뮬레이션: `EventBus.stage_cleared.emit({stage_id:3, saved:8, original_hp:10, star_thresholds:[0.55, 0.85, 0.97], ...})` → SaveData stars == 1. UI(StageDialog)와 SaveData stars 동기성 확인. **PASS**: thresholds 전달 path가 record_clear까지 정확히 흐름 + invalid thresholds(`[0.1, 0.5]` 길이 2) 입력 시 stars == 0 + push_warning 호출 |
| `tests/SceneFlowLastStagePredicateTest.tscn/gd` (**R1-H4 회귀 가드** — 신규) | 헤드리스. SceneFlow 부분 인스턴스(또는 Main.tscn 통째) → `_on_stage_result({stage_id:3, ...})` 호출 → StageDialog.show_result 두 번째 인자가 `true`. `_on_stage_result({stage_id:2, ...})` → 두 번째 인자 `false`. **가상 stage_id=4** (미래 STAGE_SCENES 확장 대비) → 두 번째 인자 `false` (`>=`였으면 true 잘못 반환). dev stage_id=910 등은 STAGE_SCENES 미등록 → load_stage 자체에서 fallback 차단되어 SceneFlow._on_stage_result 경유 안 됨 — 직접 호출 시나리오는 본 test가 cover |

### 2.7 수정 (frontmatter doc — pointer-ize)
| 파일 | 변경 |
|---|---|
| `phases/mvp/phase20-polish.md` | (선택) plan stabilize 후 본문을 1줄 포인터로 교체 (phase 12 패턴 답습). frontmatter는 그대로 — `large_change_ok: false`, `sot: docs/PRD.md`, `sot_aux: [docs/ARCHITECTURE.md, docs/PHASE_14_OPTION_B_PROPOSAL.md, phases/mvp/REVISION_2026-05-18-option-b.md]`. **본 plan 첫 라운드에서는 frontmatter doc 무수정 — pointer-ize는 plan stabilize 후 별도 작업** |

### 2.8 무변경 (CRITICAL — codex 검증 ban list)
- `scripts/core/EventBus.gd` — 시그널 추가 0건 (sfx_request 기존 보유)
- `scripts/core/ScoreSystem.gd` — 4-카운터(ADR-002) 무영향
- `scripts/core/StageRunner.gd:138-148` `_make_result` — `star_thresholds` 1 키만 추가, 다른 키 무변경
- `scripts/core/SkillRegistry.gd` — 신규 스킬 0건
- `scripts/core/AntSpawner.gd` — Release Rate 시스템 무변경 (phase 8/11 산출)
- `scripts/ui/HUD.gd` — Counter/Stepper 무변경
- `scripts/ui/SkillToolbar.gd`, `PauseBtn.gd`, `ReleaseRateStepper.gd` — phase 11 산출 그대로
- `scripts/ui/Motion.gd`, `Tokens.gd` — phase 9 freeze 그대로 (시각 polish는 Ant.tscn StickyTimerBar Sprite2D만, theme 의존 X)
- `scripts/world/Terrain.gd` — phase 17/18 산출 그대로 (hazard registry 무변경)
- `scripts/world/hazards/HazardBase.gd` — D13 가드 + register/deactivate 무변경
- `scripts/world/SettlementMarker.gd` — D5/D6 자연 분기 무변경
- `scripts/world/StageLayoutData.gd`, `StageLayoutBuilder.gd` — 신규 layout 2종은 기존 데이터 모델 그대로 (hazard cell 필드 미도입 — phase 17 D11 정책)
- `scripts/world/Candy.gd`, `Home.gd` — sfx emit 1줄씩만 추가 (다른 로직 무변경)
- `scripts/ant/states/WalkerState.gd`, `CarryingState.gd`, `FallerState.gd`, `ClimberState.gd`, `WorkerState.gd`, `SettledState.gd`, `SavedState.gd`, `DeadState.gd`, `LostState.gd` — sfx emit 1줄(LostState만) 외 무변경
- `scripts/ant/Ant.gd` — `_update_sprite` stuck 분기 + `_sticky_bar` 시각 갱신만 추가, `_physics_process` 기존 로직 무변경
- `scripts/ant/states/AntStateMachine.gd`, `AntState.gd` — 무변경
- `scripts/skills/*` — 전부 무변경 (sfx emit은 skill cast 시점이 아닌 게임플레이 이벤트 시점에서만)
- ~~`scripts/core/SaveData.gd`~~ (R1-H2 fix — 본 phase 수정 대상으로 §2.2 이동: record_clear 시그니처 확장 + _on_stage_cleared thresholds 전달), `MenuLayout.gd` (phase 13 산출) — 무변경
- `scripts/ui/StageSelect.gd`, `MainMenu.gd`, `TitleScene.gd` (phase 13 산출) — 무변경 (last-stage clear 후 MainMenu 라우팅은 phase 13 산출 그대로)
- ~~`scripts/core/SceneFlow.gd`~~ (R1-H4 fix — 본 phase 수정 대상으로 §2.2 이동: line 163 등치 변경 1줄). 다른 라인은 무변경 (overlay_path 라우팅·_freeze/_unfreeze·request_* 핸들러 그대로)
- `scripts/input/*` — phase 5~8 산출 그대로
- `theme/candyants.tres` — phase 9 freeze 그대로
- `scenes/Main.tscn` — phase 12 + phase 13 산출 그대로 (SceneFlow / CurrentStageRoot / GlobalUI / StageDialog 노드 구조 무변경)
- `scenes/ui/StageDialog.tscn` — 노드 트리 무변경 (Title.text는 .gd에서 분기, .tscn 디폴트는 기존 값 유지)
- 기존 stage 01~03 scenes / dev stages — `dev_settle_test.tres` 등 phase 14~19 산출 무영향
- 기존 헤드리스 test — 회귀 PASS 검증만, 코드 변경 0
- `data/stages/stage01.tres`, `stage02.tres` — `star_thresholds` 필드 미추가 (default 빈 배열, 글로벌 fall-back). stage03만 override

### 2.9 텍스처 정책 (minimal — phase 17 정책 답습)
- StickyTimerBar 시각: 16x4 placeholder Sprite2D (단색 노란 modulate). **R1-L2 fix — `assets/icons/sticky_timer_bar.svg` 신규 placeholder 1개로 확정**. impl 시점에 생성 (`<svg viewBox="0 0 16 4"><rect width="16" height="4" fill="#FFEE66"/></svg>` 단순 placeholder). 기존 svg(blocker.svg 등) 재활용 옵션은 phase 17 StickyBadge가 이미 그 패턴이라 분리 — bar는 독립 placeholder. 정식 디자인은 phase 21 또는 별도 art polish phase
- Water/Sticky hazard 정식 텍스처: **본 phase 미도입** — phase 17 ColorRect placeholder 그대로. 정식 텍스처 교체는 phase 21 audio + art batch 또는 v1.1
- last-stage Title text 색상: phase 9 token (LEMON_500 등 강조색) 사용 옵션 — 본 plan 기본은 default INK_900 유지, 강조색 적용은 plan stage round 1 결정

---

## 3. 명세

### 3.1 별 산정 stage별 override

#### Scoring.gd 시그니처 확장 (R1-M2 입력 검증 포함)
```gdscript
class_name Scoring
extends RefCounted

const STAR_THRESHOLDS := [0.50, 0.80, 0.95]   # 글로벌 default (phase 12 freeze)

static func compute_stars(saved: int, original_hp: int, thresholds: Array = []) -> int:
    if original_hp <= 0:
        return 0
    # R1-M2 — invalid thresholds 0 star + warning fall-back.
    # 길이 ≠ 3 / descending / 0..1 범위 외는 silent corruption 차단.
    if not thresholds.is_empty():
        if thresholds.size() != STAR_THRESHOLDS.size():
            push_warning("[Scoring] invalid star_thresholds length: %d (expected %d)" % [thresholds.size(), STAR_THRESHOLDS.size()])
            return 0
        var prev: float = -1.0
        for t in thresholds:
            var tf: float = float(t)
            if tf < prev or tf < 0.0 or tf > 1.0:
                push_warning("[Scoring] invalid star_thresholds entry %s (must be ascending in [0,1])" % str(thresholds))
                return 0
            prev = tf
    var ratio := float(saved) / float(original_hp)
    var th: Array = thresholds if not thresholds.is_empty() else STAR_THRESHOLDS
    var stars := 0
    for threshold in th:
        if ratio >= threshold:
            stars += 1
    return stars
```

#### StageData.gd 1줄 추가
```gdscript
@export var star_thresholds: Array[float] = []   # phase 20 — 비면 글로벌 fall-back
```

#### StageRunner._make_result 1 키 추가
```gdscript
func _make_result(cleared: bool, reason: String) -> Dictionary:
    return {
        "stage_id": stage_data.id,
        "cleared": cleared,
        "saved": score_system.saved_pieces,
        "lost": score_system.lost_pieces,
        "original_hp": score_system.original_hp,
        "score": score_system.score(),
        "time_left": _time_left,
        "reason": reason,
        "star_thresholds": stage_data.star_thresholds,   # phase 20 — Array[float] (빈 배열 가능)
    }
```

#### StageDialog show_result 호출부
```gdscript
func show_result(result: Dictionary, is_last_stage: bool) -> void:
    # ... 기존 fade/caPop/dismiss_token 처리 ...
    var saved: int = result.get("saved", 0)
    var original_hp: int = result.get("original_hp", 0)
    var thresholds: Array = result.get("star_thresholds", [])
    var stars := Scoring.compute_stars(saved, original_hp, thresholds)
    # ... 기존 star fill 토글 + sfx_request emit ...

    var cleared: bool = result.get("cleared", false)
    if cleared and is_last_stage:
        Title.text = "마지막 단계 클리어!"
    elif cleared:
        Title.text = "스테이지 클리어!"
    else:
        Title.text = "사탕 손실"
    # ... 나머지 기존 ...
```

### 3.2 sfx_request emit 8 위치

| id | 호출 위치 | 호출 시점 | payload |
|---|---|---|---|
| `&"candy_pick"` | `scripts/world/Candy.gd::_on_body_entered` | `EventBus.candy_piece_picked.emit(hp)` 직전 (hp 감소 직후) | id only |
| `&"ant_save"` | `scripts/world/Home.gd` (ant_saved emit 위치) | `EventBus.ant_saved.emit(ant, with_candy)` 직전, **`with_candy=true`만** | id only |
| `&"candy_lost"` | `scripts/ant/states/LostState.gd::enter` | `EventBus.candy_piece_lost.emit(a)` 직전 (has_candy=true 분기 내부) | id only |
| `&"candy_depleted"` | `scripts/world/Candy.gd::_on_body_entered` | `EventBus.candy_depleted.emit()` 직전 (hp <= 0 분기 내부) | id only |
| `&"stage_cleared"` | `scripts/core/StageRunner.gd::_process` | `EventBus.stage_cleared.emit(_make_result(true, ""))` 직전 | id only |
| `&"stage_failed"` | `scripts/core/StageRunner.gd::_process` | `EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))` 직전 AND `EventBus.stage_failed.emit(_make_result(false, "time_out"))` 직전 (2 site, 동일 id) | id only |
| `&"water_splash"` | `scripts/world/hazards/WaterHazard.gd::_handle_ant_entry` | 함수 첫 줄 (LostState 전이 직전) | id only |
| `&"sticky_glue"` | `scripts/world/hazards/StickyHazard.gd::_handle_ant_entry` | D13 idempotency 가드(`_recently_processed`) 통과 *후*, `ant.apply_sticky(duration)` 직전 | id only |

**중요**: phase 12 기존 4 id (`dialog_open`/`dialog_stats_pop`/`star_fill`/`dialog_btn_press`)는 무변경. 본 phase 20 신규 8 id 추가로 총 12 id가 phase 21 receiver의 대상.

### 3.3 stuck progress bar + sprite pause/resume (R1-H3, R1-M3 fix 반영)

#### Ant.gd 변경
```gdscript
# 기존(phase 17):
var _sticky_remaining: float = 0.0

# phase 20 신규:
var _sticky_max: float = 0.0   # denominator (R1-M3 — 만료 시 reset)
var _sticky_bar: Sprite2D = null   # _ready에서 _trait_badges.get_node_or_null("StickyTimerBar")
var _sprite_paused_for_sticky: bool = false   # R1-H3 — unstuck 시 명시 play() 재개 트리거

func apply_sticky(dur: float) -> void:
    # R1-M3 — fresh entry는 새 dur로 _sticky_max set, 진행 중 재진입은 더 큰 값 보존.
    if dur > _sticky_remaining:
        _sticky_remaining = dur
    if _sticky_remaining == 0.0 or _sticky_max == 0.0:
        _sticky_max = dur
    else:
        _sticky_max = max(_sticky_max, dur)

func _physics_process(delta: float) -> void:
    if _sticky_remaining > 0.0:
        _sticky_remaining = max(0.0, _sticky_remaining - delta)
        # R1-M3 — timer 만료 시 denominator 같이 reset.
        if _sticky_remaining == 0.0:
            _sticky_max = 0.0
    if state_machine != null:
        state_machine.update(delta)
    _update_sprite()
    _update_trait_badges()
    _update_sticky_bar()   # phase 20 신규 1 호출

func _update_sticky_bar() -> void:
    if _sticky_bar == null:
        return
    if _sticky_remaining > 0.0 and _sticky_max > 0.0:
        _sticky_bar.scale.x = clamp(_sticky_remaining / _sticky_max, 0.0, 1.0)
        _sticky_bar.visible = true
    else:
        _sticky_bar.visible = false

func _update_sprite() -> void:
    if _sprite == null or state_machine == null:
        return
    # R1-H3 — stuck 진입 시 pause, unstuck 시 명시 play(_last_anim) 호출.
    if is_stuck():
        if _sprite is AnimatedSprite2D and not _sprite_paused_for_sticky:
            (_sprite as AnimatedSprite2D).pause()
            _sprite_paused_for_sticky = true
        return
    if _sprite_paused_for_sticky:
        # unstuck 직후 — _last_anim 동일하더라도 명시 play() 재개. 안 하면 anim != _last_anim
        # 분기 미진입으로 영구 pause.
        if _sprite is AnimatedSprite2D and not _last_anim.is_empty():
            (_sprite as AnimatedSprite2D).play(_last_anim)
        _sprite_paused_for_sticky = false
    # 기존 anim != _last_anim 로직 그대로 ...
    var s: AntState = state_machine.current_state
    var anim: String = "idle"
    # ... (기존 anim 매핑 + flip_h 로직)
```

#### Ant.tscn StickyTimerBar 추가 (R1-L2 텍스처 경로 확정)
```
Ant (CharacterBody2D)
├─ Sprite (AnimatedSprite2D)
├─ CollisionShape2D
├─ TraitBadges (Node2D)
│  ├─ ClimberBadge (Sprite2D) — phase 14
│  ├─ FloaterBadge (Sprite2D) — phase 14
│  ├─ SettleBadge (Sprite2D) — phase 15
│  ├─ StickyBadge (Sprite2D, position=(0, -16)) — phase 17
│  └─ StickyTimerBar (Sprite2D, position=(0, -24), texture=assets/icons/sticky_timer_bar.svg)   ← phase 20 신규
└─ Blocker (Area2D) — phase 4
```

#### Ant.tscn 노드 추가
```
Ant (CharacterBody2D)
├─ Sprite (AnimatedSprite2D 또는 Sprite2D)
├─ CollisionShape2D
├─ TraitBadges (Node2D)
│  ├─ ClimberBadge (Sprite2D) — phase 14
│  ├─ FloaterBadge (Sprite2D) — phase 14
│  ├─ SettleBadge (Sprite2D) — phase 15
│  ├─ StickyBadge (Sprite2D, position=(0, -16)) — phase 17
│  └─ StickyTimerBar (Sprite2D, position=(0, -24), texture=...)   ← phase 20 신규
└─ Blocker (Area2D) — phase 4
```

### 3.4 last-stage Title 분기 + SceneFlow 등치 변경 (R1-H4 / R2-H1 fix)

**phase 20에서 SceneFlow.gd:163 1줄 수정** — `_overlay.show_result(result, result["stage_id"] >= LAST_STAGE_ID)`에서 `>=`를 `==`로 변경한다. 변경 전 코드는 stage_id가 LAST_STAGE_ID(=3) 이상이면 모두 last-stage로 분류 — 미래 STAGE_SCENES 확장이나 직접 호출 시나리오에서 stage_id=4가 last로 오인되는 위험. 변경 후는 정확히 `stage_id == LAST_STAGE_ID`만 last로 분류. `SceneFlowLastStagePredicateTest`(§2.6)가 stage_id=3 true, stage_id=2 false, 가상 stage_id=4 false 모두 검증.

본 phase는 (a) 위 SceneFlow.gd 1줄 등치 변경 + (b) StageDialog 내부 Title.text 분기(`if cleared and is_last_stage: "마지막 단계 클리어!"; elif cleared: "스테이지 클리어!"; else: "사탕 손실"`) 두 가지를 묶어 last-stage 메시지 강화. SceneFlow 다른 라인(overlay_path 라우팅·_freeze/_unfreeze·request_* 핸들러)은 무변경.

**LAST_STAGE_ID 컨벤션**: phase 6/12 시점 stage03이 마지막. `SceneFlow.gd:17`에 `const LAST_STAGE_ID := 3` 정의됨. progression.tres 등 데이터 기반 관리는 phase 21 또는 v1.1 범위 — 본 phase는 const 그대로 사용.

---

## 4. 검증 plan (acceptance — strict)

### 4.1 essential 회귀 (기존 phase 1~19 무영향)
1. 기존 헤드리스 test 전부 PASS (phase 1~19 산출 — Stage02/03HeadlessTest, GameFlowTest, ScoringStarsTest, StageDialog* 7종, WaterHazardLoss* 외 phase 17~19 essential 약 30+ scene)
2. Stage01/02/03 통과 — 시각 회귀 (HUD/StageDialog/Toolbar 표시 무변경, sfx_request emit 추가는 receiver 미연결이라 무성능 영향)
3. ScoreSystem 4-카운터 invariant 위반 0

### 4.2 phase 20 신규 acceptance
1. **별 override**: `Scoring.compute_stars(saved, original_hp, [])` == `compute_stars(saved, original_hp)` (글로벌 fall-back). `compute_stars(saved, original_hp, [0.55, 0.85, 0.97])` 결과가 글로벌과 다름을 boundary 케이스로 검증 (ScoringStarsOverrideTest)
2. **stage03 override**: stage03 stage data 로드 후 `stage_data.star_thresholds == [0.55, 0.85, 0.97]` 검증. StageRunner._make_result에 정확히 그 값이 들어감
3. **sfx 8 id emit**: SfxRequestEmitTest가 60초 내 8 id 모두 캡처
4. **끈끈이 후처리 4 deferred**: D-1 ~ D-6 중 선정한 4종(D-1/D-2/D-5/D-6) test PASS
5. **stuck visual**: AntStickyVisualTest PASS — bar visible toggle + scale 단조 감소 + sprite.pause()
6. **last-stage Title**: StageDialogLastStageTitleTest PASS — 3 분기 모두 정확한 text

### 4.3 MVP 종료 회귀 검증 (본 phase 종료 직전)
1. `python scripts/run_test.py tests/Stage02HeadlessTest.tscn` PASS
2. `python scripts/run_test.py tests/Stage03HeadlessTest.tscn` PASS
3. `python scripts/run_test.py tests/GameFlowTest.tscn` PASS
4. phase 17~19 essential test (Water/Sticky/Bridge/Basher/Digger/Cutter) 전부 PASS
5. 본 phase 신규 10 test 전부 PASS (R1-L1 카운트 정정 — D-1, D-2, D-5, D-6, SfxRequestEmit, ScoringStarsOverride, StageDialogLastStageTitle, AntStickyVisual, SaveDataStarOverride [R1-H2], SceneFlowLastStagePredicate [R1-H4] = 10 test)
6. Stage03 Manual play — clear 시 "마지막 단계 클리어!" Title 표시 + star 1~3 분기 정상 + MainMenu 라우팅 정상
7. dev_water_after_candy + dev_sticky_settle stage manual play — 자연 진행
8. `python scripts/check_tone_policy.py` PASS (신규 .gd 코드에 `die()`/`DeadState`/사망/죽 식별자 0건 — `LostState` `sfx_request(&"candy_lost")` 등은 §0.2 허용 어휘)

---

## 5. plan-stage 정책 + 라운드 로그

### 5.1 정책 (CLAUDE.md 2026-05-25 갱신)
- Plan stage: **3-round cap** (R1 codex → fix → R2 codex → fix → R3 codex → R3 HIGH 1건이면 즉시 STOP, 사용자 결정).
- Round 1~2 HIGH 발견 시: plan inline fix → 다음 round codex 재리뷰.
- MEDIUM/LOW만 남으면 어느 라운드든 plan 내 처리 또는 명시 defer로 종결.
- 자체 적대적 리뷰 사이클은 plan stage 미적용 (impl stage 한정).
- 매 라운드 stdout은 `phases/mvp/reviews/phase20-plan-review.md`에 `## Round N` 헤더로 누적.

### 5.2 라운드 로그
- **Round 1**: needs-attention. HIGH 4 (R1-H1 dev id 충돌, R1-H2 SaveData desync, R1-H3 sprite resume, R1-H4 SceneFlow predicate) + MEDIUM 3 (R1-M1 sfx SoT, R1-M2 thresholds validation, R1-M3 _sticky_max reset) + LOW 2 (R1-L1 test count, R1-L2 texture path). v2 inline fix 완료 — 변경표 §0.0 참조
- **Round 2**: needs-attention. HIGH 1 (R2-H1 §2.8 ban list contradiction + §3.4 stale SceneFlow narration) + MEDIUM 1 (R2-M1 Subtitle 누적 별점 모순) + LOW 1 (R2-L1 test count stale). v3 inline fix 완료 — 변경표 §0.00 참조
- **Round 3**: clean. HIGH 0 / MEDIUM 0 / LOW 0. R2-H1은 §2.8 unstruck SceneFlow ban-list 제거 + §3.4의 명시적 `>=` → `==` 변경 지시로 닫힘. R2-M1은 §0/P-D6/§6 모두 Subtitle 기존 표시 + 누적 별점 deferred로 정합. R2-L1은 §0/§2.6/§4.3/§5.3 모두 신규 10 test로 정합. plan-stage 종결.

### 5.3 강제 가드
- `large_change_ok: false` 그대로 — 신규 .gd 0건, 수정 .gd 11건(v2 SaveData·SceneFlow 추가), 신규 .tscn 3건, 수정 .tres 1건, 신규 .tres 4건, 신규 test 10건(v2 +SaveDataStarOverride +SceneFlowLastStagePredicate) + 신규 placeholder svg 1건 (`assets/icons/sticky_timer_bar.svg`) = 약 30 file 변경. 100 cap 안.
- `phases/mvp/phase20-polish.md` frontmatter doc은 현재 가이드 수준 문서로 유지. 구현 SoT는 본 `phase20-plan.md` v3.1이며, pointer-ize는 별도 docs cleanup으로만 수행.

---

## 6. 비범위 (deferred)

본 phase 20에서 의도적으로 미도입한 항목 (phase 21 또는 v1.1):

- **D-3 StickyTimerCarryingResumeTest** (timer 정확도 ±0.05s 검증) — 사용자 결정 ③에서 제외. v1.1 후속
- **D-4 HazardEntryIdempotentTest** (multi body_entered 1회만 lost) — 사용자 결정 ③에서 제외. HazardBase D13 가드 자체로 자연 검증
- **사운드 receiver 구현** — phase 21 sound-bgm-sfx 산출
- **AudioStream/audio bus 노드 추가** — phase 21
- **스킬 cast sfx** (`skill_assigned` 등 4~6 id) — phase 21
- **HUD Counter caPop sfx** (`counter_pop` id) — phase 21
- **Pause toggle sfx** (`pause_open`/`pause_close`) — phase 21
- **Release Rate ± sfx** (`rr_step`) — phase 21
- **last-stage cinematic 씬** (별도 scenes/ui/MvpEpilogue.tscn 등) — 사용자 결정 ④에서 제외. 현행 StageDialog + MainMenu 라우팅 유지
- **누적 별점 합계 표시** (모든 stage 합산) — phase 13 SaveData에 데이터는 있으나 본 phase scope 외 — v1.1
- **Water/Sticky 정식 텍스처** — phase 21 audio + art batch 또는 별도 art polish phase
- **stage별 시간 보너스 점수** (별 산정에 time_left 반영) — F-D3에서 KISS로 미도입
- **Release Rate ± 토글 시 visual feedback** (Stepper 강조) — phase 21 polish

---

## 7. 참조

- [docs/PRD.md](../../../docs/PRD.md) — MVP 정의
- [docs/ARCHITECTURE.md](../../../docs/ARCHITECTURE.md) — ScoreSystem 4-카운터, EventBus
- [docs/PHASE_14_OPTION_B_PROPOSAL.md](../../../docs/PHASE_14_OPTION_B_PROPOSAL.md) §0.2/§1/§2.1/§3.5/§0.7.5
- [phases/mvp/REVISION_2026-05-18-option-b.md](../REVISION_2026-05-18-option-b.md) §3.1 (phase 20 매핑)
- [phases/mvp/plans/phase12-plan.md](phase12-plan.md) — StageDialog · Scoring · sfx_request 4 id 정착
- [phases/mvp/plans/phase17-plan.md](phase17-plan.md) — HazardBase · LostState · Ant._sticky_remaining
- [phases/mvp/plans/phase17-deferred.md](phase17-deferred.md) — D-1 ~ D-6 deferred 박제
- [phases/mvp/plans/phase18-plan.md](phase18-plan.md) — Basher/Digger Terrain registry
- [phases/mvp/plans/phase19-plan.md](phase19-plan.md) — Cutter/식물 지형
