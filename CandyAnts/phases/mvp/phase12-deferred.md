# Phase 12 — Deferred Findings

본 문서는 phase 12 codex impl Round 3 (2026-05-17)에서 발견된 MED/LOW 중 본 phase commit에서 흡수하지 않고 후속으로 미룬 항목 기록.

근거: CLAUDE.md 2026-05-09 impl-stage 정책 — HIGH/CRITICAL만 반드시 fix, MED/LOW는 `phaseNN-deferred.md`로 미룰 수 있음.

---

## R3-M1 (MEDIUM) — phase05-plan.md Esc/back_menu phase 12 routing

**Locations**: `phases/mvp/plans/phase05-plan.md` lines 140, 277, 293, 325, 388, 495, 538, 550, 625, 642 — "phase 12" routing 표기.

**Defer 사유**:
- phase 5 plan은 이미 완료(commit `e35db9e` 영역)된 phase의 historical record. 동작에 영향 없음.
- DEFER-1(Esc InputMap binding phase 13으로 이동)은 본 phase plan §6, INPUT_PLAN.md §1/§4, INPUT_MAPPING.md §3.x에서 이미 phase 13으로 sweep 완료. 현재 SoT는 phase 13으로 일관.
- phase 5 plan 자체를 회복적으로 갱신하는 건 historical record를 retroactively 수정하는 거라 의미 낮음.

**Resolution path**: phase 13 plan 작성 시 phase 5 plan을 historical reference로 인용할 때 한 줄로 "phase 5 plan의 'phase 12' 표기는 v3 renumber 이전 — 실제 owner는 phase 13" 노트 추가하면 됨. 본 phase 범위 외.

---

## R3-L1 (LOW) — phase02-plan.md / phase03-plan.md generic phase 11/12 ref

**Locations**:
- `phases/mvp/plans/phase02-plan.md` lines 85, 213 — HUD/StageDialog 의미로 "phase 11/12" generic ref.
- `phases/mvp/plans/phase03-plan.md` lines 207-211 — 동상.

**Defer 사유**:
- phase 2/3 plan도 완료된 phase의 historical record.
- "phase 11/12" 표기는 v2(완료된 phase 1~4 시기) 기준 phase 번호. v3 renumber로 현재는 phase 11 = ui-hud-toolbar-replace, phase 12 = ui-stage-dialog로 매핑 변경.
- generic ref라 실제 의미 추적 가능. dependency chain 깨지지 않음.

**Resolution path**: 향후 plan에서 phase 2/3 plan을 명시 참조할 때 inline 보강. 본 phase 범위 외.

---

## 본 phase 흡수된 R3 findings (참조용)

- **R3-M2** (phase12-plan 자기 노트 line 90, 420 INPUT_PLAN phase 12 표기) → 본 phase commit에 inline fix.
- **R3-M3** (phase12-plan SFX follow-up phase 20 → phase 21) → 본 phase commit에 inline fix. polish refs는 phase 20(stage10-bomber-polish) 유지 (SFX vs polish 의도 분리).
