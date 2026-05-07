# MVP Task — Phase 표준 절차

이 task의 모든 phase는 동일한 7단계 절차를 따른다. 이 문서가 단일 SoT.

## 폴더 구조

```
phases/mvp/
├── README.md                        # 이 문서 (절차 명세)
├── status.json                      # execute.py 자동 관리
├── phaseNN-<slug>.md                # phase 정의 (frontmatter + 목표 + 변경 대상 + 검증)
├── plans/
│   └── phaseNN-plan.md              # phase 시작 시 작성 (구현 계획)
└── reviews/
    ├── phaseNN-review.md            # adversarial-review stdout 보존
    └── phaseNN-deferred.md          # 미수정 이슈 기록 (있을 때만)
```

## Phase 표준 절차 (7단계)

### 1. 계획 작성 — `plans/phaseNN-plan.md`
다음 항목을 모두 채운다:
- **목표 1줄** (phase 정의 문서와 일치)
- **변경/추가 파일 목록** (씬, 스크립트, 데이터, 에셋)
- **씬 트리 구조** (노드 타입 + 핵심 export 변수)
- **시그널 흐름** (어떤 시그널이 어디서 발화 → 어디서 수신)
- **엣지 케이스** (구현 중 빠뜨리면 안 되는 시나리오 3개 이상)
- **검증 시나리오** (Godot 에디터에서 어떻게 동작 확인할지)

### 2. adversarial review 실행
plan 파일이 working-tree에 있는 상태에서:

```bash
node "C:\Users\code1412\.claude\plugins\cache\openai-codex\codex\1.0.3\scripts\codex-companion.mjs" adversarial-review --wait "phase NN plan: <한 줄 포커스>"
```

리뷰는 working-tree 변경(plan 파일 + 그 시점 변경 파일)을 모두 본다.

### 3. 리뷰 결과 보존 — `reviews/phaseNN-review.md`
stdout을 그대로 저장. 헤더로 다음 추가:

```markdown
# Phase NN Adversarial Review

- **실행 시각**: YYYY-MM-DD HH:MM
- **포커스**: <CLI에 넣은 한 줄>
- **scope**: working-tree
- **base ref**: <git rev-parse HEAD 결과>

---

<stdout 그대로>
```

### 4. 이슈 분류 + 처리

| Severity | 처리 정책 |
|----------|----------|
| CRITICAL | **반드시 수정**. plan 갱신 후 진행 |
| HIGH     | **반드시 수정**. plan 갱신 후 진행 |
| MEDIUM   | 수정 권장. 미수정 시 deferred 기록 필수 |
| LOW      | 선택. 미수정 시 deferred 기록 권장 |

미수정 이슈는 `reviews/phaseNN-deferred.md`에:

```markdown
# Phase NN Deferred Issues

## [SEVERITY] 이슈 한 줄 요약
- **원본 인용**: <리뷰에서 발췌>
- **결정**: defer | wontfix | future-phase
- **사유**: <왜 안 고치는지>
- **재검토 시점**: Phase X | Stage Y | never
```

> CRITICAL/HIGH를 deferred에 넣는 것은 **금지**. 반드시 수정 후 진행.

### 5. 구현
갱신된 plan대로 진행. 파일/씬은 ARCHITECTURE의 폴더 구조 + 명명 규약(snake_case 함수, PascalCase 클래스, UPPER_SNAKE const) 준수.

### 6. 수동 검증
Godot 에디터에서 phase 정의의 "검증 방법"대로 플레이 테스트.
검증 통과 못 하면 7단계로 가지 말고 구현/plan 수정.

### 7. 완료 처리
```bash
python scripts/execute.py mvp complete N
```
자동 커밋 메시지: `phase N: <phase name>`. plans/reviews/deferred 모두 함께 커밋된다.

## 중단/재개

`status.json`에 진행 상태가 보존됨. 재개 시:
```bash
python scripts/execute.py mvp        # 상태 확인
python scripts/execute.py mvp next   # 다음 pending phase 정의 출력
```

## Phase 목록 (요약)

| # | 빌드 | 이름 | 핵심 산출물 |
|---|------|------|-------------|
| 1 | —   | bootstrap | project.godot, 폴더 구조, Autoload 빈 셸 |
| 2 | 0.1 | stage1-core | Vertical Slice — Ant 6상태, Candy/Home, ScoreSystem, HUD |
| 3 | 0.2 | stage2-builder | SkillRegistry 활성화, SkillToolbar, WorkerState, Builder |
| 4 | 0.3 | stage3-blocker | Blocker 스킬 |
| 5 | 0.4 | stage4-hazard-water | Hazard 시스템 + Water |
| 6 | 0.5 | stage5-basher | TileMap 동적 파괴 + Basher |
| 7 | 0.6 | stage6-digger | Digger (수직 굴착) |
| 8 | 0.7 | stage7-miner | Miner (대각선 굴착) |
| 9 | 0.8 | stage8-climber | 벽 감지 + Climber |
| 10 | 0.9 | stage9-floater | 낙하 변형 + Floater |
| 11 | 1.0 | stage10-bomber-polish | 원형 파괴 + Bomber + Release Rate 폴리싱 |
