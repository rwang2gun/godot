---
name: ui-hud-toolbar-replace
duration_estimate: 7200
verify:
large_change_ok: false
sot: docs/UI_GUIDE.md
sot_aux: [docs/INPUT_PLAN.md, docs/design_handoff/README.md]
---

# Phase 11: HUD / SkillToolbar 씬 교체 (atoms 인스턴스화)

## 1차 SoT

**`phases/mvp/plans/phase11-plan.md` v2** — 본 phase의 모든 구현 spec, 변경 대상, 검증 방법, 엣지 케이스는 plan v2가 SoT. 본 문서는 execute.py validate용 frontmatter만 보존하는 pointer 문서.

frontmatter 갱신 사유: codex plan-review v1 HIGH-1 (plan vs frontmatter SoT 충돌)을 사용자 결정으로 plan-as-SoT 방향 선택 (2026-05-17). 본문 spec 중복 0건 정책으로 단일 SoT 유지.

## 표준 절차

plan/review/deferred는 `phases/mvp/README.md`. 시각 명세는 `docs/UI_GUIDE.md` §3 (atom catalog) + `docs/design_handoff/preview/skill_toolbar.html`.
