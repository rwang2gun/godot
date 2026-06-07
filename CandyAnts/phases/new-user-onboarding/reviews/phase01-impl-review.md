# Phase 1 — affordance-foundation · impl review

대상: working-tree diff (신규 7 파일)
- `scripts/core/SkillAffordance.gd` (카테고리 SoT)
- `assets/shaders/outline.gdshader`
- `scripts/ui/Glow.gd`
- `tests/SkillAffordanceCategoryTest.{gd,tscn}`
- `tests/OutlineGlowSmokeTest.{gd,tscn}`

검증: `SkillAffordanceCategoryTest` PASS · `OutlineGlowSmokeTest` PASS. 기존 코어 미변경(회귀 0).

---

## Self-Review Round 1 (codex 전)

- **HIGH — `Glow.clear`가 부착 전 외부 material을 복원 안 하고 null로 만듦.** 내가 명시한 "외부 머티리얼 보존" 계약 위반.
  - 수정: `META_PRIOR` 메타에 apply 직전 material 백업 → clear 시 복원. 스모크 테스트에 prior-restore 케이스 추가.
- 결과: HIGH 0 → self-review clean.

---

## Round 1 (codex adversarial-review)

Verdict: **needs-attention**

- **[medium] `Glow.clear` interleaving** (`scripts/ui/Glow.gd`): apply 후 외부가 material을 교체한 뒤 clear 호출 시, 소유권이 넘어간 상태의 계약이 불명확하고 미테스트. prior 백업이 폐기되어 원복 불가.
  - 권고: material 슬롯 소유권 계약을 명시적으로 고정 + interleaving 가드 테스트 추가.

(CRITICAL/HIGH 0. MEDIUM 1 — 계약 모호성이라 cheap·정당하여 수정.)

---

## Self-Review Round 2 (Round 1 수정 후)

- **소유권 핸드오프 시맨틱 고정**: 글로우 활성 중 외부가 material을 교체하면 소유권이 외부로 넘어감 → clear는 외부 material을 **존중**(덮어쓰지 않음), prior 백업 폐기, 메타만 정리. `clear()` 헤더 주석에 계약 명문화.
- interleaving 가드 테스트 추가: apply→외부 교체→clear가 외부 material 존중 + 메타 정리 + 재부착 시 외부를 새 baseline으로.
- 결과: HIGH 0 → self-review clean.

---

## Round 2 (codex adversarial-review 재실행)

Verdict: **approve**

> No ship-blocking issue found. The targeted Glow.clear handoff contract is enforced by identity-checking the stored glow material before restore, and the regression test covers external replacement, metadata cleanup, and re-baselining after clear. The SkillAffordance guard also checks registered-skill coverage and stale category entries against SkillRegistry.
>
> No material findings.

(주: codex 샌드박스 정책으로 python 테스트는 미실행 — read-only diff/source 검토 기반. 테스트는 로컬에서 PASS 확인됨.)

**verdict clean → Phase 1 완료 진행.**
