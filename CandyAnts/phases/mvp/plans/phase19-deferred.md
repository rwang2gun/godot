# Phase 19 Deferred Findings

본 파일은 phase 19 (mechanic-destruction-plant) impl-stage codex adversarial-review Round 1에서 발견된 MEDIUM/LOW finding 박제. CLAUDE.md impl-stage 정책상 CRITICAL/HIGH만 강제 fix 대상이고, MEDIUM/LOW는 deferred 박제 또는 별도 sweep 허용. 본 finding 3건은 phase 20 polish 또는 별도 doc track에서 처리.

---

## F1 (MEDIUM) — Cutter while loop multi-destroy per single update

**Origin**: codex Round 1 impl review, [phase19-impl-review.md Round 1 F1](../reviews/phase19-impl-review.md)

**Location**: `scripts/ant/states/WorkerState.gd` `_update_cutter` `while _tick_accum >= CUTTER_TICK` loop.

**Hypothetical**: 큰 `delta` 값(예: frame drop·CPU spike)에 `_tick_accum`이 `CUTTER_TICK`의 정수배가 되면 한 _update 호출 내에서 multi-cell destroy + position teleport 가능. 그 cell 중 hazard same-cell이 있으면 Area2D body_entered 발화 race 발생 가능성.

**Reality check (phase 19 신규성 분석)**:
- Basher (`_update_basher`)·Digger (`_update_digger`)·Builder (`update` while loop) 모두 phase 16~18에서 동일 패턴 답습. 동일 hypothetical risk 보유.
- phase 16/17/18 essential test가 본 위험 deterministic gate 안 함. ship 후 회귀 0 — 정상 frame budget(`delta` ≈ 0.016s)에서 multi-tick 발화 미발생.
- phase 19는 Basher 패턴을 그대로 답습 (kind 검사만 `"plant"`로 교체), **신규 위험 도입 0**.

**Defer 근거**: 본 finding은 phase 16~19 전체 worker mode while loop 공통 위험으로 phase 19 본질 아님. 추가 가드(per-frame 1 cell cap 또는 multi-cell race essential test)는 worker mode 전체 리팩터링 범위가 되어 phase scope 위반. phase 20 polish 또는 v1.1 후속 phase의 mechanic 전체 sweep에서 dedicated finding으로 처리.

**Action when revisited**: 
- Option A: `_update_*` 패턴 일괄 `if _tick_accum >= TICK and _remaining > 0: _tick_accum = TICK_remainder; _destroy_one()` 으로 per-frame 1 cell cap 통일. Basher/Digger/Cutter 모두 변경.
- Option B: dedicated essential test로 high-delta race 가드 (`Engine.set_max_physics_steps_per_frame` 조작 후 multi-destroy 검출).
- Option C: hypothetical 입증 못 하면 wontfix.

---

## F2 (MEDIUM) — StageLayoutBuilder unknown tile_type silent fallback to earth

**Origin**: codex Round 1 impl review, [phase19-impl-review.md Round 1 F2](../reviews/phase19-impl-review.md)

**Location**: `scripts/world/StageLayoutBuilder.gd` `_add_cell()` else branch + `build()` `kind` 결정.

**Hypothetical**: layout author가 `"plant"` 대신 `"plnat"`·`"vine"` 같은 오타를 적으면 `_add_cell`이 default solid + earth visual로 처리. `build()` `kind = "plant" if tile_type == TILE_PLANT_SOLID else "earth"`도 default earth. 결과: plant 의도였던 cell이 Basher target이 되어 puzzle 디자인 실패.

**Reality check (phase 19 신규성 분석)**:
- plan v3 §11 risk에 이미 박제: "StageLayoutBuilder의 `tile_map` value vocabulary 확장... silent fallback이지만 ColorRect 시각이 plant와 distinct하므로 디자이너 즉시 인지. 명시 assertion 추가는 plan v2에서 재검토 가능."
- 즉 본 finding은 phase 19 plan 작성 시 이미 알려진 risk였고 "plan v2 재검토 가능"으로 deferred 결정됨. codex가 plan v3.1.1 ship 후 재확인한 것.

**Defer 근거**: plan §11 risk decision의 상속. assertion 추가는 phase 19 scope 위반(`_add_cell`에 push_error/assert 추가는 backward compat impact 발생 가능 — 기존 layout이 임의 string으로 작성된 cell을 fail-fast로 reject하면 stage01~03 등 회귀 시 신규 fail 가능). phase 20 polish 또는 별도 layout-vocab-strict track에서 enum validation 도입.

**Action when revisited**:
- Option A: `_add_cell`에 `assert(tile_type in [TILE_SOLID, TILE_SLOPE_RIGHT, TILE_SLOPE_LEFT, TILE_PLANT_SOLID])`. 기존 layout 전수 scan으로 unknown value 0건 검증 후 도입.
- Option B: `push_warning("[StageLayoutBuilder] unknown tile_type: %s — fallback to earth solid" % tile_type)` 추가. backward compat 안전, 디자이너 가시성 강화.
- Option C: enum/StringName 도입으로 type-safety 강화 (Resource schema 변경 → migration 필요).

---

## F3 (LOW) — PRD §4 8종 스킬 wording 과 SkillRegistry 9종 등록 불일치

**Origin**: codex Round 1 impl review, [phase19-impl-review.md Round 1 F3](../reviews/phase19-impl-review.md)

**Location**: `docs/PRD.md:10` (`8종 스킬 (단계적 도입) — Climber / Floater / Bomber / Blocker / Builder / Basher / Miner / Digger`) vs `scripts/core/SkillRegistry.gd:3-13` (SKILL_SCRIPTS 10 entry — phase 19 후 Cutter 포함).

**Hypothetical**: PRD §4 wording을 SoT로 보면 phase 19 도입된 Cutter가 misroster. PROPOSAL §3.4.2가 "Bomber 자리 대체"로 wording을 흡수했으나 PRD §4 자체는 갱신 안 됨.

**Reality check (phase 19 신규성 분석)**:
- plan v3.1.1 §2.7 ban list가 `docs/PRD.md` 무변경 명시. phase 19에서 PRD 갱신은 정책 위반.
- PROPOSAL §3.4.2 derived 결정 (plan §1.1 D10 근거): "Cutter는 PROPOSAL §1 'Bomber 자리 대체' — bomber.svg dead entry 정리는 phase 20 polish 범위".
- 즉 PRD §4 wording 동기화도 phase 20 polish 범위로 의도된 deferred.

**Defer 근거**: ban list 정책 일관성. phase 20 polish에서 PRD §4 wording을 "8종 스킬" → "9종 스킬 (Cutter 포함)" 또는 PROPOSAL §3.4.2 swap rationale 명시로 갱신. bomber.svg/miner.svg dead entry 정리도 동일 phase에서 처리.

**Action when revisited**: phase 20 polish §x 항목에 PRD §4 wording 갱신 + Cutter 명시 + Bomber 대체 rationale 박제.

---

## 종합

- phase 19 impl-stage 정책상 CRITICAL/HIGH 0건 → 강제 fix loop 진입 안 함.
- F1~F3 3건은 모두 phase 19 신규 위험 아니거나(F1) plan 작성 시점에 이미 deferred 결정된(F2/F3) finding. 별도 sweep 또는 phase 20 polish에서 처리.
- phase 19 complete + 커밋 진입 가능.
