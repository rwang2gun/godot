# Phase 10 Plan Review

> Target: `phases/mvp/phase10-ui-atoms-foundation.md` (plan after 2026-05-17 refresh)
> SoT: `docs/UI_GUIDE.md` §3 (atoms) + §4 (motion)
> SoT-aux: `docs/INPUT_PLAN.md`, `docs/design_handoff/README.md`
> Date: 2026-05-17
> Policy: CLAUDE.md plan-stage — CRITICAL/HIGH 1건이라도 발견 시 **즉시 중단 + 사용자 결정**. 자동 재리뷰 금지.

---

## Round 1 (codex plan review)

### Verdict
**STOP** — the plan has a HIGH contract mismatch: it requires `Motion.caPop` to kill prior tweens, but Motion is frozen and the SoT implementation does not provide that behavior.

### CRITICAL
None.

### HIGH
- **[H-1] caPop kill guard assigned to frozen Motion but absent from SoT** — plan ref: `phase10-ui-atoms-foundation.md` lines 30–36, 50, 76 | SoT ref: `docs/UI_GUIDE.md` §4 lines 285–342; `scripts/ui/Motion.gd` lines 8–13 | Detail: CONFIRMED hypothesis (h). The plan states `Motion.caPop` kills any existing tween before creating a new one, but the frozen SoT code only creates a new tween, sets scale, appends two scale tweens, and returns it — no kill guard exists. Because the plan also forbids modifying `Motion.gd`, implementation must either move the kill guard into the Counter caller contract, or the plan must explicitly route a Motion.gd sweep through the phase 9 sweep path before proceeding.

### MEDIUM
- **[M-1] Generic ShadowBG/MainBG child order conflicts with Counter SoT tree** — plan ref: lines 71–74 | SoT ref: `UI_GUIDE.md` §3.3 lines 236–250, §1.6 lines 107–112 | Detail: PARTIAL hypothesis (a). The plan's edge-case rule places `ShadowBG` as first child and `MainBG` as second child, but the Counter SoT tree is `Counter (PanelContainer) -> VBoxContainer`, not a ShadowBG/MainBG pair. The duplicate-shadow policy is real per §1.6, but the plan needs a Counter-specific tree reconciling the shadow layer with the §3.3 PanelContainer/VBox structure.

- **[M-2] Chip.set_label_value adds new API not in SoT** — plan ref: lines 26, 106–115 | SoT ref: `UI_GUIDE.md` §3.2 lines 231–235 | Detail: CONFIRMED hypothesis (c). `UI_GUIDE.md` §3.2 defines Chip as an HBox with label/value typography, tint background, border, radius, and padding — no `set_label_value(label, value)` method is defined. Freezing this method in the plan is a new API contract. The plan must either mark it as a phase-local addition or update the SoT before implementation.

- **[M-3] Manual preview comparison broader than §0.5 operating model allows** — plan ref: lines 62–70 | SoT ref: `UI_GUIDE.md` §0.5 lines 22–32, §8 lines 476–488 | Detail: PARTIAL hypothesis (f). The plan makes `preview/skill_toolbar.html` and `preview/dialog.html` comparison part of manual verification, but §0.5 says designer handoff comparison is auxiliary only, and §8 rejects pixel matching. `dialog.html` is especially out of scope for atom-only work. The plan should soften this to auxiliary token/layout sanity only.

- **[M-4] Plan modifies phase 9 Tokens.gd foundation outside stated atoms+tests scope** — plan ref: lines 21–46, 83–99 | SoT ref: `UI_GUIDE.md` §3 lines 219–222, §1.3 lines 70–80 | Detail: The plan adds `TintKind` and `TINT_BG`/`TINT_BORDER` to `scripts/ui/Tokens.gd`, which is a phase 9 frozen foundation. This should be explicitly called out as a deliberate phase 9 extension or moved to atom-local constants.

### LOW / INFO
- **[L-1] Motion call-site signatures match frozen SoT** — REFUTED hypothesis (b) for signature mismatch. The five signatures (`caPop`, `boop`, `idle_bob`, `fade_in`, `fade_out`) align with frozen `Motion.gd`. The only problem is behavioral, covered by H-1.

- **[L-2] Counter set_value caPop-on-BigNumber confirmed by SoT** — CONFIRMED hypothesis (d). `UI_GUIDE.md` §3.3 explicitly defines `set_value(n: int)` to call `Motion.caPop(big_number)`. No contradiction.

- **[L-3] Headless test convention supports .tscn+.gd pair** — REFUTED hypothesis (e). Existing tests are scene-based `.tscn` files and `run_test.py` takes scene paths. `AtomShowcaseHeadless.tscn + .gd` is consistent with convention.

- **[L-4] SkillSlot FocusHalo z-order aligned, non-touch clause only phase-local** — PARTIAL hypotheses (a)/(g). SkillSlot's `ShadowBG → MainBG → FocusHalo` ordering matches §3.4. Phase 10's non-modification of `SkillToolbar.gd` is compatible with atom-only scope, but the plan should not imply the toolbar remains untouched in phase 11 — commit `bd18eaa` already shows it as an active integration surface.

---

## Status (CLAUDE.md plan-stage policy)
- Plan-stage HIGH 1건 발견 → **자동 재리뷰 X, 사용자 결정 대기**.
- 자동 적용/구현 진행 금지 (CLAUDE.md "Plan stage codex 리뷰에서 CRITICAL/HIGH가 1건이라도 나오면 작업을 즉시 중단").
- 사용자 결정 옵션은 §하단 "사용자 결정 필요" 참조.

## 사용자 결정 필요 (3 옵션)

### Option A — Plan revision (H-1 + MEDIUM 모두 흡수, 본 phase 10 안에서 해결)
- H-1: caPop kill 책임을 **Counter 호출자**로 이동 (atom-local guard). plan에 명시 + Motion.gd 미수정.
  - 구현 안: Counter.set_value 안에서 `if _capop_tween and _capop_tween.is_valid(): _capop_tween.kill()` 후 `_capop_tween = Motion.caPop(big_number)`.
- M-1: Counter ShadowBG/MainBG 구조를 §3.3 PanelContainer→VBox 위에 sticker shadow를 어떻게 얹는지 plan에 명시 (예: PanelContainer가 StyleBox normal + 별도 자식 ColorRect/StyleBoxFlat overlay).
- M-2: Chip.set_label_value를 "phase 10 신규 atom API" 로 명시 (UI_GUIDE §3.2는 시각 spec만, 메서드는 phase 10에서 freeze).
- M-3: 수동 검증에서 `preview/dialog.html` 비교 제거, `preview/skill_toolbar.html`은 §0.5 보조 참조로만 명시.
- M-4: Tokens.gd 수정을 "phase 9 frozen Tokens.gd에 atom-needed enum 추가 (phase 10 의도적 확장)" 으로 명시.

### Option B — Motion.gd phase 9 sweep + 최소 plan 수정
- H-1 처리를 phase 9 sweep으로: `fix: motion caPop kill prior tween (phase 9 sweep)` 커밋으로 Motion.gd에 kill guard 추가 + UI_GUIDE §4 갱신. phase 10 plan은 그대로 (이미 kill 동작 가정).
- 장점: caPop의 kill 정책이 모든 호출자(향후 phase 11 HUD 카운터들)에서 일관됨.
- 단점: 이미 commit된 phase 9 freeze를 sweep으로 깨고 가야 함. CLAUDE.md "Hot-fix sweep" 절차 발동.
- M-1~M-4는 별도 plan 수정 (option A의 M-1~M-4 동일).

### Option C — Plan revision + 일부 MEDIUM defer
- H-1 + M-1 + M-2만 plan revision (Option A 동일).
- M-3, M-4는 `phase10-deferred.md`로 옮겨 atom impl 중 발견하면 처리.

---

**대기**: 사용자가 A / B / C 중 결정.
