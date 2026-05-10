---
description: docs/를 읽고 사용자와 정렬한 뒤 Phase로 쪼개 execute.py로 실행하는 원스톱 명령
allowed-tools: Bash, Read, Write, Edit, TodoWrite, Glob, Grep
---

# /harness — 원스톱 Phase 실행 (v3)

`docs/`가 채워진 상태에서 작업 전체를 자동으로 진행한다. Plan v3 적용 후 read policy와 stage policy가 분리되어 있다.

## 인자
`$ARGUMENTS`로 task 이름이 주어지면 해당 task로 진행. 비어있으면 docs를 읽고 적절한 task 이름을 사용자에게 제안.

## 0. 세션 시작 시 한 번 (자동)
세션 시작마다 정확히 한 번 실행:
```
python scripts/execute.py {task} validate
```
- `phases/{task}/metadata.json`이 없고 `{task}`가 빌트인 default(`mvp`)에 있으면 자동 생성.
- 빌트인이 없는 task는 manual 생성 안내 후 종료. 사용자가 metadata를 만들면 재실행.
- frontmatter 스키마 / sot 경로 / status.json ↔ phase 파일 일관성 검증.
- 실패하면 안내된 항목을 고친 뒤 다시 validate.

## 1. 자동 read policy (Plan v3 §3.1)
세션 시작 자동 로드 — 약 200줄 이내:
- `docs/PRD.md`
- `docs/ARCHITECTURE.md`
- `docs/ADR.md`

자동 로드 **제외**:
- `docs/UI_GUIDE.md` — phase frontmatter `sot`/`sot_aux`로 선택적으로 명시 read
- `phases/{task}/REVISION_*.md`
- `phases/{task}/README.md`
- `docs/design_handoff/**` — read-only reference, phase plan에서 명시될 때만 read

`docs/references/`는 추가 컨텍스트로만 참조, 강제 아님.

## 2. 사용자와 논의 (같이)
docs를 읽고 task 진행에 필요한 정보가 명확하지 않으면 물어본다:
- task의 정확한 범위 (예: "MVP 전체"인지 "Stage 1만"인지)
- 우선순위 충돌이 있을 때 결정
- 외부 의존성이나 환경 설정 필요 여부

답이 명확하면 추가 질문 없이 다음으로.

## 3. 구현 계획을 Phase로 쪼갠다 (자동)
사용자가 정한 task에 대해 Phase 분해:
- 각 Phase는 단독으로 검증 가능해야 함 (테스트 또는 수동 확인 가능)
- 각 Phase는 1~3시간 작업량 (너무 크지 않게)
- 첫 Phase는 항상 "셋업/스켈레톤" 성격 (의존성 무엇도 없도록)
- Phase 간 의존은 선형 — 순서대로 진행 가능해야 함

분해 결과는 사용자에게 보여주고 확인 받기.

### 3.1 plan-stage 리뷰 정책 (Plan v3 §10)
- `/codex:adversarial-review`로 plan을 리뷰한다.
- CRITICAL/HIGH가 1건이라도 나오면 **즉시 중단**하고 사용자에게 보고. 자동 재리뷰 금지.
- MEDIUM/LOW만 plan 안에서 처리하거나 명시적으로 defer.

## 4. Phase 파일 생성 (자동)
각 Phase는 `phases/{task}/phaseNN-{slug}.md`로 저장. status.json은 `python scripts/execute.py {task}` 첫 실행 시 자동 초기화.

### Phase frontmatter (Plan v3 §3.2 / §5)
```yaml
---
name: {phase-slug}
duration_estimate: {seconds, integer}
verify:
large_change_ok: false
sot: docs/<required-path>
sot_aux: [docs/<aux-path>, phases/{task}/<aux-path>]
---
```

규칙:
- `sot`은 필수, 실제 경로만 허용. `sot: self` 금지.
- `sot_aux`는 선택, 누락/빈 값은 `[]`. 단순 inline array만 지원, 따옴표/공백 경로/콤마 포함 경로 거부.
- `large_change_ok: true`는 phase 9 같은 자산 임포트 phase에 한해 사용. **count guard만 우회**, 단일 5MB / 합계 25MB size guard는 항상 적용.

### Phase 본문 권장 구조
```markdown
# Phase {N}: {이름}

## 목표
{한 줄}

## 변경 대상
- {파일/씬 목록}

## 검증 방법
{어떻게 동작 확인할지}
```

## 5. execute.py 실행 (자동)

```
python scripts/execute.py {task}                  # 상태
python scripts/execute.py {task} next             # 다음 pending phase 출력 (sot/sot_aux 포함)
python scripts/execute.py {task} complete {N}     # 안전 staging + 커밋
python scripts/execute.py {task} validate         # 스키마 검증 (세션 시작/구조 변경 시)
python scripts/execute.py {task} sync-status      # phase 파일 ↔ status.json 동기화
```

### 5.1 phase 진입 (`next`)
- pending phase의 frontmatter `sot`와 `sot_aux`를 출력.
- agent는 거기 명시된 파일만 명시 read. `docs/UI_GUIDE.md`처럼 자동 로드에서 제외된 문서는 phase가 명시적으로 요구할 때만 read.

### 5.2 phase 완료 (`complete`)
`complete`가 stage policy를 소유한다. 안전한 자동 staging:

1. verify 명령 실행 (있으면)
2. `phases/{task}/reviews/phaseNN-impl-review.md` 존재 + 비어있지 않은지 검증
3. **clean index 요구** — 사용자 사전 staged 항목이 있으면 즉시 중단 (Plan v3 §6.3 step 6)
4. `git status --porcelain=v2 -z`로 변경 분석
5. **rename/copy 발견 시 중단** — 사용자가 수동 처리
6. **deny-list 매치 발견 시 중단** — 정리 후 재시도 (`.git/`, `.godot/`, `__pycache__/`, `*.tmp`, `*.bak`, `docs/design_handoff/**` 등)
7. **whitelist 외 변경 발견 시 중단** — 의도 확인 필요
8. large-change guard: 100개 초과 candidate(`large_change_ok: true`로 우회 가능), 단일 5MB / 합계 25MB(절대 우회 불가)
9. 안전 staging → status.json 업데이트 → `phase {N}: {name}` 커밋
10. 커밋 실패 시 status.json 원복 + 하네스가 stage한 경로만 unstage (사용자 사전 staged는 절대 건드리지 않음)

### 5.3 sync-status
phase 파일이 추가/삭제/리네임되면:
```
python scripts/execute.py {task} sync-status                       # add only
python scripts/execute.py {task} sync-status --prune-missing       # + remove missing pending
python scripts/execute.py {task} sync-status --force-prune-completed  # + remove missing completed
```
prune 전 `status.json.bak`이 자동 생성됨. 리넘버링 의심되면 prune 금지, 매핑부터 수정.

### 5.4 design_handoff 워크플로우 (Plan v3 §3.3)
- `docs/design_handoff/**`는 read-only reference. agent가 수정/auto-stage 금지.
- runtime 자산은 `assets/`/`art/`/`themes/`/`fonts/`/`audio/`로 복사·생성 후 phase 출력으로 staging.

## 중단/재개
중간에 멈춰도 `phases/{task}/status.json`에 진행 상태가 보존됨. 다시 `/harness {task-name}`을 실행하면 현재 상태 표시 후 다음 Phase부터 재개.
