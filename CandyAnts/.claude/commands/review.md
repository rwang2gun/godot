---
description: CLAUDE.md / docs/ 규칙 기반으로 현재 변경 사항을 점검
allowed-tools: Bash, Read, Glob, Grep
---

# /review — 규칙 기반 리뷰

현재 변경 사항(`git diff`)을 `CLAUDE.md`와 `docs/`의 규칙에 비추어 점검한다.

## 실행 흐름

1. `git status`와 `git diff`로 변경 범위 파악
2. `CLAUDE.md`의 CRITICAL 규칙 로드
3. `docs/ADR.md`의 결정사항 로드 (특히 트레이드오프 항목 — 위반 여부 확인)
4. 변경된 파일 각각을 규칙에 비추어 점검
5. 결과를 ✅ / ⚠️ / ❌ 로 분류해 출력

## 점검 항목 (CLAUDE.md CRITICAL 기준)

### 아키텍처 규칙
- [ ] 신규 `.gd` 파일이 `scripts/{core,ant,skills,world,ui}/` 안에 있는가
- [ ] 새 Area2D를 추가했다면 `collision_mask`에 Ant Layer(3)가 포함되었는가
- [ ] ScoreSystem 관련 변경이 4-카운터 무결성을 유지하는가 (단일 카운터로 회귀하지 않았는가)
- [ ] 새 스킬 추가 시 `SkillRegistry.SKILL_SCRIPTS`에 preload가 추가되었는가
- [ ] `_static_init` 자기등록 패턴을 사용하지 않았는가

### 개발 프로세스
- [ ] 한 커밋이 하나의 Phase에 대응하는가 (Phase 혼합 커밋 금지)
- [ ] 커밋 메시지가 `phase N:` 또는 conventional commit 형식인가
- [ ] 이전 Stage에 회귀가 없는가 (수동 확인 필요 항목)
- [ ] Hook 차단/경고를 우회하지 않았는가

### GDScript 규약 (BattlePrototype 계승)
- [ ] 함수/변수: `snake_case`, 클래스/노드: `PascalCase`
- [ ] 타입 힌트 누락 여부 (`var x = ...`가 untyped면 ⚠️)
- [ ] `untyped Array/Dictionary` / Autoload / `Dictionary.get()` / `$NodePath`에서 `:=` 사용 여부 (사용 시 ❌)
- [ ] 시그널은 과거형 (`candy_picked`, `ant_died` 등)

## 출력 형식

```
## /review 결과

### ✅ 통과
- {항목}

### ⚠️ 경고 (검토 권장)
- {파일:라인} {내용} — {제안}

### ❌ 위반 (수정 필요)
- {파일:라인} {규칙 위반} — {수정안}
```

위반 항목이 있으면 우선순위 순서로 수정안 제시.
외부 도구의 깊은 검증이 필요하면 `/codex:adversarial-review` 별도 실행 권장.
