> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness_Refine_Plan_Feedback — `Harness_Refine_Plan.md` plan-stage 적대적 리뷰

작성일: 2026-05-10
대상: `docs/Harness_Refine_Plan.md`
검토자: Claude (plan-stage 자체 적대적 리뷰)
정책 근거: `CLAUDE.md` §개발 프로세스 — Plan stage CRITICAL/HIGH 1건 발견 시 자동 재리뷰 X, 즉시 중단·사용자 결정

> **결론**: Refine Plan의 방향(v4 추천 조합 채택)은 옳지만, R2 화이트리스트가 이 repo 실 사용 패턴과 맞지 않아 **첫 적용부터 자기 자신을 차단하는 bootstrap 모순**을 포함한다. HIGH 6건 + MEDIUM 7건 + LOW 2건. 사용자 결정 후 v5(`HARNESS_REVIEW_V5.md`) 작성 권장.

---

## 1. 사실 관계 사전 검증

| Refine Plan 진술 | 실측 | 판정 |
|---|---|---|
| Godot `.uid`는 phase 산출물의 일부 | git status에 untracked `.uid` 14개 존재 | ✓ |
| `init_status()`는 `active_revision` 미생성 | scripts/execute.py:64-89 — 미생성 | ✓ |
| `execute.py complete`가 `git add -A` 사용 | scripts/execute.py:184 | ✓ |
| 현재 phase 6 page_id null | `notion-phase-ids.json.phases.6.page_id == null` | ✓ |

→ 진술 사실관계는 정확. 결함은 *처방 범위*에 있다.

---

## 2. HIGH (6건 — 적용 차단 사유)

### H1. R2 화이트리스트가 `scripts/*.py`를 누락 — v5 자체 적용 불가 (bootstrap 모순)

- 1차 허용 범위에 `scripts/**/*.gd`만 있고 `scripts/**/*.py`가 없음
- 그런데 v5 적용 자체가 `scripts/execute.py`를 대량 수정하는 작업
- "whitelist 밖 변경이 있으면 complete 중단" 정책상 v5 적용 phase의 complete가 **자기 자신을 차단**
- `scripts/run_test.py` 등 다른 Python helper 수정도 동일 문제

### H2. `.tscn.uid` / `.tres.uid` 등 `.uid` 변종 누락

- 화이트리스트는 `*.gd.uid`만 허용
- 실제 Godot은 `.tscn`, `.tres` 등 **모든 리소스**에 `.uid`를 자동 생성
- phase 7~13(씬 추가/UI)은 `*.tscn.uid`, `*.tres.uid` 다수 발생 → 매 phase complete 차단
- R1이 풀려고 한 ".uid 회귀 위험"의 하위셋만 해결됨

### H3. UI 자산 파일 전체 미포함 — UI track(phase 9~13) 차단

- 화이트리스트에 `*.png`, `*.jpg`, `*.svg`, `*.webp`, `*.ogg`, `*.wav`, `*.ttf`, `*.woff` 등 자산 확장자 없음
- `assets/`, `art/`, `audio/`, `themes/` 같은 자산 디렉토리도 없음
- UI phase는 `docs/design_handoff/`에서 PNG/SVG/폰트가 들어올 수밖에 없는데 모두 whitelist 밖 → 매번 차단
- R3 매핑 표에 phase 9~13 sot이 `docs/UI_GUIDE.md`로 정상 매핑된 것과 모순

### H4. `phases/{task}/notion-phase-ids.json` 누락 — Phase 6 진입 시 차단

- CLAUDE.md §Notion 동기화 정책: phase 6 진입 시 신규 page 생성 후 `notion-phase-ids.json`에 page_id 기입 (현재 null 상태)
- 이 갱신은 phase 6 산출물의 일부로 같은 commit에 들어가는 게 자연스러움
- 화이트리스트에 없음 → phase 6 complete 차단 또는 별도 수동 stage(R2 자동화 취지 훼손)
- §7 보류 항목 "Notion page_id null 검증 별도 처리"와 충돌 — 별도 처리할 거라면 적어도 화이트리스트는 열어야 함

### H5. `phases/{task}/REVISION_*.md` 누락 — 미래 revision 추가 차단

- 현재 `REVISION_2026-05-09.md` 1개. 향후 v4·v5 revision 추가 시 화이트리스트 밖
- §1 "v2/v3/v4 누적 정리"와 동일하게 revision 누적도 운영상 발생할 수 있는데 봉쇄됨

### H6. R5 `sync-status --prune-missing` "사용자 확인" 메커니즘 부재

- "missing phase가 completed면 중단하고 사용자 확인을 요구한다"
- `execute.py`는 비인터랙티브 CLI — `input()` prompt? 추가 옵션(`--force-prune-completed`)? 명세 없음
- Plan stage에서 미정의로 두면 구현 단계에서 다시 결정 사이클 발생

---

## 3. MEDIUM (7건 — 수정 후 적용 권장)

### M1. R2-1 step 10 atomicity 정책 모호

> "commit 실패 시 status 변경을 원복하거나, 최소한 실패를 크게 출력하고 다음 phase 진행 금지"

"원복하거나 / 최소한 ..." 둘 다 허용으로 결정 회피.
§6 수용 기준 "complete atomicity: commit 실패/중단 시 status만 completed로 남지 않음"은 strict 원복을 요구.
**정책↔수용기준 불일치**.

### M2. R2-2 review artifact preflight 강제력 모호

> "권장 확인: 파일 존재 / 비어 있지 않음 / `Self-Review` 또는 `adversarial-review` 관련 헤더/본문 포함"

"권장"이 강제인지 옵션인지 불명. §6 "review gate"는 파일 존재만 보는지, 본문까지 보는지 결정 필요.

### M3. R3 phase 1~4 sot 분리 무의미

표에서 phase 1은 별도 행, 2~4는 묶음 행이지만 sot/sot_aux 값 동일. 분리 이유 없음 → 표 노이즈.
한 행 `1~4 | docs/PRD.md | [docs/ARCHITECTURE.md, docs/ADR.md]`로 통합 가능.

### M4. Step 5 frontmatter parser 모순

> "외부 의존성 없이 간단 parser 유지" + "`sot_aux: [docs/A.md, docs/B.md]` 지원"

현 `parse_frontmatter`(execute.py:43-53)는 `key:value` split. inline 배열 `[a, b]` 파싱은 정규식 또는 분기 추가 필요.
"간단 유지"와 "배열 지원"의 트레이드오프 명시 필요(어디까지 허용할지: 빈 배열만? 단일 항목? 다중 항목?).

### M5. R6 validate 호출 시점의 강제력 없음

> "metadata 또는 harness/execute.py 수정 후 1회"

누가 트리거하나? 사람이 기억? 자동? 강제 메커니즘 없음. pre-commit hook이나 `harness.md` 명시 등 강제 수단이 §3 R6에 없음.

### M6. R3 phase 9~13 sot_aux에 `docs/design_handoff/` 누락

phase 9~13이 UI track인데 sot_aux는 `[docs/INPUT_PLAN.md]`만. design_handoff/가 UI 자산 SoT인데 표에 없음.
(자동 로드 X는 OK이나, sot_aux는 명시 read 트리거이므로 누락은 결정성 약화.)

### M7. v2/v3/v4 정리 방식 미결정

> §1 "v5 통합 후 구버전 계획 문서는 archive 또는 superseded 처리"
> §5 Step 1 "archive 또는 superseded 처리"

"archive 또는 superseded" 둘 다 OK라는 건 미결정. 디렉토리(`docs/archive/`?), 파일명 접두사(`SUPERSEDED_*`?), 헤더 표기(`> Status: SUPERSEDED by v5`?) 중 하나 선택 필요.

---

## 4. LOW (2건 — 표현 수정)

### L1. §6 검증 명령 escape 환경 의존성

```text
rg "sot:\\s*self" phases/mvp -g 'phase*.md'
```

PowerShell 더블쿼터 안에서 `\\s`는 `\s`로 파싱되지만 환경별 변동 가능. 작은따옴표 권장:

```text
rg 'sot:\s*self' phases/mvp -g 'phase*.md'
```

### L2. atomicity 검증 명령 부재

§6 "complete atomicity: commit 실패/중단 시 status만 completed로 남지 않음" — 기준은 있지만 검증 절차/명령 비명시.
의도적 fail 시뮬레이션 방법 명세 필요(예: pre-commit hook으로 강제 reject 후 status.json 확인).

---

## 5. 결정 필요 항목

| ID | 항목 | 옵션 |
|---|---|---|
| **DR-H1** | scripts/*.py 화이트리스트 추가 | (a) `scripts/**/*.py` 추가 / (b) `scripts/execute.py`만 핀포인트 / **(c) `scripts/**`로 확장(.py 외 helper 포괄)** |
| **DR-H2** | `.uid` 변종 일괄 허용 | **(a) `**/*.uid` 와일드카드 단일 추가** / (b) `*.gd.uid`, `*.tscn.uid`, `*.tres.uid` 명시 추가 |
| **DR-H3** | UI 자산 화이트리스트 | **(a) `assets/**`, `art/**`, `themes/**` 디렉토리 단위 + 확장자 일반 화이트리스트** / (b) phase 9 진입 시점에 화이트리스트 갱신 (지연) / (c) UI phase 들어가기 전 design_handoff 구조 확정 후 한 번에 추가 |
| **DR-H4** | `notion-phase-ids.json` 화이트리스트 | **(a) `phases/{task}/notion-phase-ids.json` 추가** / (b) Notion 갱신을 phase 별도 commit으로 분리 |
| **DR-H5** | `REVISION_*.md` 화이트리스트 | **(a) `phases/{task}/REVISION_*.md` 추가** / (b) revision 추가는 별도 commit |
| **DR-H6** | sync-status 사용자 확인 메커니즘 | **(a) `--force-prune-completed` 옵션 추가** / (b) `input()` 인터랙티브 prompt / (c) prune-completed 자체 금지 (수동 status.json 편집 강제) |
| **DR-M1** | atomicity 정책 strict 여부 | **(a) strict 원복** / (b) 실패 출력 + flag 파일만 / (c) (a)+(b) 둘 다 |
| **DR-M2** | review artifact 강제력 | (a) 파일 존재만 / **(b) 비어있지 않음** / (c) 헤더 패턴 매칭 |
| **DR-M4** | sot_aux 파싱 범위 | **(a) `[]` / `[a]` / `[a, b]` 모두 지원** / (b) `[]` 빈 배열만, 다중은 YAML list 형식(`- a / - b`) / (c) pyyaml 도입 |
| **DR-M7** | 구버전 정리 방식 | **(a) `docs/archive/HARNESS_REVIEW_v{1,2,3,4}.md` 이동** / (b) 헤더에 `> SUPERSEDED by v5` 한 줄만 / (c) 삭제 |

(굵게 표시는 추천안)

---

## 6. 추천 한 줄 조합

**DR-H1(c) + DR-H2(a) + DR-H3(a) + DR-H4(a) + DR-H5(a) + DR-H6(a) + DR-M1(a) + DR-M2(b) + DR-M4(a) + DR-M7(a)**

| 결정 | 근거 |
|---|---|
| H1(c) `scripts/**` 디렉토리 단위 | repo 정책상 scripts/는 모두 도구 코드 — 디렉토리 단위가 깔끔 |
| H2(a) `**/*.uid` | Godot 메타 파일은 어디서나 산출 — 확장자 단일 룰이 가장 안전 |
| H3(a) 자산 디렉토리 사전 확보 | UI phase 들어가서 막히는 것보다 미리 여유 있게 |
| H4(a)+H5(a) | Notion/REVISION 둘 다 phase 산출물의 일부로 자연스럽게 같은 commit에 |
| H6(a) `--force-prune-completed` | 비인터랙티브 CLI 일관성 유지, 명시 의도 표현 |
| M1(a) strict 원복 | §6 수용 기준 "complete atomicity"와 정합 |
| M2(b) 비어있지 않음 검사까지만 | 헤더 패턴 강제는 brittle, 빈 파일 가드는 효용 명확 |
| M4(a) 단순 인라인 배열만 | pyyaml 의존 회피, 빈배열·단일·다중 모두 흔한 케이스 |
| M7(a) `docs/archive/` | 파일 시스템에 superseded 문서가 보이면 검색 노이즈, 분리가 깔끔 |

→ 이 조합으로 가도 될지 컨펌 후 v5 재작성 진행.

---

## 7. Refine Plan이 잘 풀어낸 부분 (보존 가치)

- **R1 staged-only complete 폐기**: v4 H1(.uid 회귀)을 정확히 인지하고 방향 전환 — 옳음
- **R2-1 complete 순서 보정**: status 갱신과 commit의 atomicity 문제를 plan에서 미리 잡은 건 큰 진전. M1만 strict 결정하면 그대로 유지
- **R2-2 review artifact preflight**: impl review 강제는 CLAUDE.md §개발 프로세스 정책과 정합. M2 결정만 확정하면 OK
- **R3 `sot: self` 폐지**: v4 feedback H3 그대로 수용 — 옳음
- **R4 `local_phase_count` 동적 계산**: v4 feedback H4 그대로 수용 — 옳음
- **R5 `sync-status` 명령**: validate 실패 시 reset만 권하던 v4 M1 보정 — 옳음 (H6만 결정)
- **R6 validate 호출 시점 명시**: v4 M2 보정 — 옳음 (M5 강제 메커니즘만 보강)
- **§4 v5 작성 지침**: 패치 대신 단일 적용 계획으로 다시 쓰는 방침 — 옳음 (M3/M7 정리만 결정)

---

## 8. 다음 단계

1. 본 피드백 사용자 검토
2. §5 결정 항목 10개 컨펌 (또는 §6 추천 조합 일괄 채택)
3. 결정 반영해서 `docs/HARNESS_REVIEW_V5.md` 작성
4. v5에 대해 1회 더 자체 적대적 리뷰 (clean까지)
5. 사용자 컨펌 후 실제 코드/문서 변경 진행

---

## 9. Self-Review Round 1 — 본 피드백 자체에 대한 적대적 리뷰

작성일: 2026-05-10
대상: 본 문서 §1~§8
기준: CLAUDE.md plan-stage 정책 — 자체 결과물도 codex 동일 기준(CRITICAL/HIGH/MEDIUM/LOW + 누락 + 모순 + 가혹 hypothetical)로 검토

### 9.1 본 피드백의 누락 (HIGH)

#### S-H1. `phases/{task}/...` placeholder 처리 명세 없음
- 본 §2 H4/H5에서 `phases/{task}/notion-phase-ids.json` 같은 패턴을 그대로 인용했지만, glob은 `{task}` 변수를 미지원
- `execute.py`가 task 이름을 알고 있으니 런타임 치환이 필요한데, 누가/어떻게 치환하는지 spec 없음
- 같은 결함이 Refine_Plan §3 R2 1차 허용 범위 전체에 있음(`phases/{task}/phase*.md` 등)
- 본 피드백이 H4/H5를 다루면서 이 메타 결함을 지적 안 한 건 누락

#### S-H2. `docs/*.md`만 top-level 허용 — 하위 디렉토리 차단
- Refine_Plan 화이트리스트의 `docs/*.md`는 `docs/PRD.md` 같은 top-level만 매칭
- `docs/references/Phase 5- Game Mechanics & UX.md` 같은 하위 파일은 매칭 X
- phase가 reference 문서 추가/수정 시 차단 → 결정 필요
  - (a) `docs/**/*.md`로 확장 (단, `docs/design_handoff/`는 명시 제외 유지)
  - (b) references 미수정 정책으로 못 박기

#### S-H3. git 삭제/리네임 처리 명세 부재
- `git status --porcelain`은 `M / ?? / A / D / R / C` 6가지 상태
- Refine_Plan §3 R2 정책은 add/modify만 다루고 D(삭제)/R(rename) 처리 없음
- 의도된 파일 삭제(예: deprecated 코드 제거) 시 R2가 어떻게 판정하는지 결정 필요
- 본 피드백 §2/§3 어디에도 이 케이스 다룸 없음

#### S-H4. 메타 비판 — 추천 조합 적용 시 whitelist 실효 의문
- 본 §6 추천 조합(H1c + H2a + H3a + H4a + H5a)을 모두 채택하면 화이트리스트가 매우 광범위
- 명시 제외(repo 외부 / 임시 / 대용량 design_handoff 원본 / whitelist 밖 untracked)는 양이 적음
- 결과: whitelist의 보호 효과가 `git add -A` 대비 미미 — R2 도입 본 취지 약화
- 진짜 차단해야 할 대상(`*.godot/` 캐시, `.import`, `.DS_Store`, `node_modules/`, IDE 캐시, 빌드 산출물)이 명시 제외에 누락
- 메타 결정: **블랙리스트 + 위험 패턴**이 단순할 수도 있음 (whitelist vs blacklist 본질 결정 자체를 v5에서 재검토)

### 9.2 본 피드백의 누락 (MEDIUM)

#### S-M1. `.claude/` 하위 미커버
- Refine_Plan 화이트리스트 `.claude/commands/*.md`만 허용
- `.claude/agents/`, `.claude/hooks/`, `.claude/settings.json` 누락
- phase 작업 중 settings.json에 allowed-tools 추가나 hook 추가가 필요할 수 있음
- 본 피드백 §2~§3 어디서도 다루지 않음

#### S-M2. `*.import` 파일 (Godot 자산 import 메타) 누락
- Godot은 PNG/SVG 등 자산을 import할 때 동명의 `*.import` 메타 파일 자동 생성
- UI phase에서 자산 추가 시 `*.import`도 같이 생김
- H3에서 자산 디렉토리는 다뤘지만 `*.import` 확장자는 명시 안 함

#### S-M3. frontmatter `sot` 키 누락 시 검출 책임 미명시
- Refine_Plan §5 Step 5 "빈 값 또는 누락은 빈 배열로 처리" — `sot_aux`만 다루고 `sot` 키 자체 누락은 명시 없음
- 현 `parse_frontmatter`(execute.py:43)는 누락 키를 dict에 안 넣음
- validate가 `fm.get("sot")` 결과를 어떻게 처리할지(KeyError vs empty string vs None) spec 부재
- 본 피드백 §3 M4가 sot_aux만 다루고 이 케이스를 빠뜨림

#### S-M4. 등급 재평가 — 본 §3 M3는 cosmetic, LOW로 강등
- "phase 1~4 sot 분리 무의미"는 표 디자인 노이즈일 뿐 운영에 영향 없음
- MEDIUM은 과등급 — LOW가 적절

#### S-M5. 등급 재평가 — 본 §3 M6는 LOW에 가까움
- design_handoff sot_aux 누락은 *보조* SoT 빠짐 — 강제 read 아님
- 결정성 약화는 사실이지만 H급은 아님 → LOW로 강등 또는 유지

#### S-M6. 본 §3 M4 표현 과장
- "외부 의존성 없이 + 배열 지원"은 정규식 분기 1개로 가능 — "모순"이 아니라 "spec 명세 부족"
- 표현을 약화: "구현 분량 spec 미명시"

### 9.3 본 피드백의 누락 (LOW)

#### S-L1. ID prefix 불일치
- `Harness_Feedback_v4.md`: `D-H1` 형식
- 본 문서: `DR-H1` 형식
- 사용자가 답할 때 헷갈림. 한쪽으로 통일 필요(권장: `DR-H1` 유지하되 v4 feedback과 충돌 시 본 문서가 후행이라 그대로)

#### S-L2. §6 추천 조합 강도 표현
- "추천"으로 굵게 표시 + §6에 "이 조합으로 가도 될지 컨펌"
- plan-stage 정책 정신("자동 재리뷰 X, 사용자 결정")과 약한 충돌 — 추천이 너무 강한 nudge
- 표현 약화: "한 가지 합리적 조합 예시" 정도가 정직

#### S-L3. §7 보존 가치에서 R2 자체 평가 누락
- §7은 R1, R2-1, R2-2, R3, R4, R5, R6, §4를 평가하지만 **R2(자동 stage 화이트리스트 도입)** 자체 평가 없음
- R2의 의도(unrelated 파일 차단)는 옳음, 다만 화이트리스트 범위가 부족 — 명시 누락

#### S-L4. cmd.exe 호환성
- 본 §4 L1 추천 명령 `rg 'sot:\s*self' ...` — PowerShell은 OK이나 cmd.exe는 작은따옴표 미인식
- 시스템 컨텍스트는 PowerShell 환경이라 무관, 단 향후 환경 다양화 시 noting

---

## 10. 보완 — Round 1 반영 갱신

§9 결과를 반영해 §2/§3/§5/§6/§7을 다음과 같이 갱신한다. 본 §10이 이전 섹션과 충돌 시 §10이 우선.

### 10.1 §2 HIGH에 추가 (S-H1~S-H4)

| 추가 ID | 항목 | 핵심 |
|---|---|---|
| **H7** | `{task}` placeholder 런타임 치환 spec 부재 | execute.py가 task 이름으로 치환 — 명시 spec 필요 |
| **H8** | `docs/**/*.md` vs `docs/*.md` 깊이 결정 누락 | references 등 하위 디렉토리 처리 결정 필요 |
| **H9** | git 삭제/리네임(D/R) 처리 정책 부재 | whitelist 정책에 D/R 케이스 명시 필요 |
| **H10** | whitelist 실효 메타 결함 | 추천 조합 적용 시 보호 효과 미미 — 블랙리스트 대안 재검토 |

### 10.2 §3 MEDIUM 갱신

추가:
- **M8**: `.claude/agents/`, `.claude/hooks/`, `.claude/settings.json` 화이트리스트 누락
- **M9**: `*.import` (Godot 자산 import 메타) 화이트리스트 누락
- **M10**: frontmatter `sot` 키 자체 누락 시 검출 spec 부재

등급 재평가:
- **M3 → LOW로 강등**: cosmetic 표 디자인 문제
- **M6 → LOW로 강등 or 유지**: 보조 SoT 누락은 강제 read 아님 (사용자 판단에 맡김)
- **M4 표현 약화**: "모순" → "구현 spec 미명시"

### 10.3 §5 결정 항목 추가

| ID | 항목 | 옵션 |
|---|---|---|
| **DR-H7** | `{task}` placeholder 처리 | (a) execute.py가 런타임 치환 / (b) 화이트리스트 spec을 정규화된 패턴으로 직접 작성 |
| **DR-H8** | `docs/**/*.md` vs `docs/*.md` | (a) `docs/**/*.md`로 확장(`docs/design_handoff/` 명시 제외 유지) / (b) `docs/*.md` top-level만 |
| **DR-H9** | git 삭제/리네임 처리 | (a) D/R도 whitelist 안이면 자동 stage / (b) D/R은 항상 사용자 명시 stage 요구 / (c) D는 자동, R은 명시 |
| **DR-H10** | whitelist vs blacklist 구조 | (a) 현 whitelist 유지 + 명시 제외 보강 / (b) blacklist로 전환(`*.godot/`, `.import` 캐시, IDE 메타 차단 후 나머지 허용) / (c) 하이브리드(blacklist 우선 + whitelist 후순위) |
| **DR-M8** | `.claude/` 하위 화이트리스트 | (a) `.claude/**` 전체 / (b) `.claude/{commands,agents,hooks}/*.md` + `.claude/settings.json` 명시 |
| **DR-M9** | `*.import` 처리 | (a) `**/*.import` 화이트리스트 / (b) Godot import 캐시는 `.gitignore`로 처리 (`.import` 자체는 commit, `.godot/` 캐시는 차단) |
| **DR-M10** | `sot` 키 누락 검출 | (a) `parse_frontmatter`가 누락 키를 빈 문자열로 채워 validate에서 실패 처리 / (b) validate가 `"sot" not in fm` 체크 |

### 10.4 §6 추천 조합 갱신

이전 추천 + 추가 항목:

**기존 추천 + DR-H7(a) + DR-H8(a) + DR-H9(c) + DR-H10(c) + DR-M8(b) + DR-M9(b) + DR-M10(a)**

| 추가 결정 | 근거 |
|---|---|
| H7(a) execute.py 런타임 치환 | 화이트리스트를 사람이 읽기 쉬운 `{task}` 형태로 유지 |
| H8(a) `docs/**/*.md` | references/ 추가 시 차단 회피, design_handoff만 명시 제외 |
| H9(c) D 자동, R 명시 | 삭제는 흔한 정상 작업, rename은 의도 확인 가치 있음 |
| H10(c) 하이브리드 | whitelist 단독은 보호 약하고 blacklist 단독은 신규 자산 누락 위험 — blacklist 우선(`.godot/`, `.import` 캐시, `*.tmp`) 후 whitelist fallback |
| M8(b) 명시 | `.claude/**` 전체는 너무 넓음, 명시 패턴이 의도 분명 |
| M9(b) `.gitignore` 처리 | `*.import`는 commit 대상이지만 Godot 캐시 `.godot/`은 차단 — 책임 명확 |
| M10(a) parse 채움 | validate 단순화, 누락 시 즉시 검출 |

표현 약화 (S-L2 반영): "**한 가지 합리적 조합 예시** — 사용자가 항목별로 다른 선택을 해도 무방"

### 10.5 §7 보강 (S-L3)

추가:
- **R2 자동 stage 화이트리스트 도입**: 의도(unrelated 파일 차단)는 옳음, 다만 1차 허용 범위가 부족(S-H1~S-H4, S-M1~S-M2). H7~H10/M8~M9 결정 후 화이트리스트 재구성하면 보존 가치 ★★★

### 10.6 v5 작성 시 추가 점검 항목

§8 다음 단계의 step 3에 추가:
- v5는 §10 `DR-H7~H10`, `DR-M8~M10` 결정도 모두 명시 반영
- v5 Self-Review에서 **whitelist vs blacklist 구조 결정**(DR-H10)을 가장 먼저 점검

---

## 11. Self-Review Round 1 종합

| 라운드 | HIGH | MEDIUM | LOW | clean? |
|---|---|---|---|---|
| Initial (§2~§4) | 6 | 7 | 2 | X |
| Self-Review Round 1 추가 (§9~§10) | +4 (H7~H10) | +3 (M8~M10), 2건 LOW 강등 | +4 (S-L1~S-L4) | X |
| 통합 | **10** | **8** | **6** | X — 사용자 결정 필요 |

CLAUDE.md plan-stage 정책: HIGH 1건이라도 즉시 중단·사용자 결정. 본 피드백 자체에서도 HIGH 4건 추가 발견 → v5 작성 전에 §5 + §10.3의 결정 항목 17개 모두 컨펌 필요.

다음 사용자 액션:
1. §5 + §10.3 결정 항목 17개 일괄 컨펌 (또는 §6 + §10.4 추천 조합 일괄 채택)
2. 컨펌 후 v5 작성 진행
3. v5에 대해 다시 1회 자체 적대적 리뷰 (Self-Review Round 2) 후 사용자 컨펌
