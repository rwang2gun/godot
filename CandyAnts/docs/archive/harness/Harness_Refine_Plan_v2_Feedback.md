> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness_Refine_Plan_v2_Feedback — `Harness_Refine_Plan_v2.md` plan-stage 적대적 리뷰

작성일: 2026-05-10
대상: `docs/Harness_Refine_Plan_v2.md`
검토자: Claude (plan-stage 자체 적대적 리뷰)
정책 근거: `CLAUDE.md` §개발 프로세스 — Plan stage CRITICAL/HIGH 1건 발견 시 자동 재리뷰 X, 즉시 중단·사용자 결정

> **명명 규칙 정정 (2026-05-10)**: 본 문서의 차기 산출물 표기는 모두 **`Harness_Refine_Plan_v3.md` ("Plan v3")**. 사용자 결정에 따라 `HARNESS_REVIEW_V5.md`는 만들지 않고 Refine Plan 시리즈로 통일됨. v2 §6 / §9에 등장하는 "v5"도 원래 의미는 차기 정식 계획(=Plan v3). 본 피드백의 인용 부분도 같은 매핑으로 읽으면 됨.
>
> **결론**: v2는 v1 대비 크게 개선되었고 §8 Round 1 자체 리뷰 포함도 좋은 진전. 다만 v2 자체에 HIGH 6건 + MEDIUM 5건 + LOW 4건이 잔존. 사용자 결정 후 v2 본문 보완(특히 H2/H6) 또는 Plan v3 작성 시 일괄 반영 권장.

---

## 1. 검증한 사실 (v2 정확성)

| v2 진술 | 실측/판단 | 판정 |
|---|---|---|
| §1 결정 표 16개 항목 | `Harness_Refine_Plan_Feedback.md` 추천 조합과 정합 | ✓ |
| §2.1 자동 로드 제외 목록 | UI_GUIDE / REVISION / README / design_handoff/** | ✓ |
| §2.2 sot 매핑 표 | `HARNESS_REVIEW_V4.md` 매핑 + Refine Plan v2 매핑 일관, phase 1~4 통합 행, design_handoff/README.md 추가 | ✓ |
| §4.1 deny-list 패턴 | 일반 안전 패턴(`.git/`, `.godot/`, `node_modules/` 등) | ✓ |
| §4.2 whitelist 자산/uid/import 포함 | v4 feedback 지적 누락 항목 모두 반영 | ✓ |
| §8 자체 적대적 리뷰 4건 (HIGH 2 + MEDIUM 2 + LOW 1) | 각 finding 적절, 보완책 합리적 | ✓ |

→ v2의 사실 진술/구조는 정확. 결함은 *자체 리뷰가 잡지 못한 잔존 위험*에 있다.

---

## 2. HIGH (6건 — 적용 차단 사유)

### H1. §9.3 large change guard가 UI track(phase 9)을 차단 + override 부재

**사실**:
- guard: stage 후보 100개 초과 / 단일 5MB 초과 / 총 25MB 초과 시 complete 중단
- phase 9 `ui-theme-assets`는 PNG/SVG 다수 + 동수의 `*.import` 메타 → **100개 쉽게 초과**
- 자산 디렉토리(`assets/`, `art/`, `themes/`, `fonts/`)에 design_handoff에서 가져온 자산을 한 phase에 묶어 추가하는 워크플로우 가정

**v2 처방**:
- §9.3 예외: "asset import phase에서는 한시적으로 완화 가능. 완화 옵션은 [Plan v3]에서는 구현하지 않고 수동 stage/commit으로 처리" (원문은 "v5"로 표기, 명명 통일에 따라 Plan v3로 매핑)

**문제**:
- phase 9는 R2 자동화 적용 불가 → v2 핵심 취지(phase complete 자동화)가 가장 자산 많은 phase에서 작동 X
- "완화 옵션 Plan v3에서 구현하지 않고 수동 처리"는 Plan v3 적용 직후부터 phase 9 마찰을 만든다

**판정**: override 메커니즘을 Plan v3 첫 적용에 포함시켜야 함. 미루지 말 것.

### H2. §8 Round 1 HIGH-2 "read/stage 분리" 약속이 §9에 미반영 (자체 모순)

**v2 §8 HIGH-2 보완 (원문 인용, "v5" → Plan v3로 매핑)**:
> "[Plan v3]에서 read policy와 stage policy를 별도 섹션으로 분리한다."

**v2 §9 실제**:
- §9.1 stage 후보 계산 순서
- §9.2 local settings 제외
- §9.3 large change guard
- §9.4 archive 이동
- → **read policy 별도 섹션 누락**. "Round 1 반영" 말미에 "read policy와 stage policy는 별개다" 한 줄만 명시.

**문제**:
- v2 자체 약속을 §9에서 안 지킴 → Plan v3에서도 누락될 위험
- read 계약(`sot`/`sot_aux`)과 stage 계약(`whitelist`/`deny`) 충돌 케이스 spec 부재 (예: design_handoff/README.md는 read 가능, stage 차단)

**판정**: v2 §10으로 read policy 섹션 신설하거나, 적어도 Plan v3 필수 포함 항목(§6)에 명시 강화.

### H3. metadata.json 최초 생성 책임자 미명시

**v2 §1 결정 표**: metadata 관련 결정 없음
**v2 §3.1 validate**: "metadata.json 존재" 강제

**문제**:
- 첫 적용 시 metadata.json 부재 → validate 항상 실패
- 누가 만드나? 사용자 수동? `harness.md` 안내? helper?
- v4 feedback의 H4가 이걸 지적해서 helper 도입 권고했으나 v2 §1 결정 표에 없음
- spec 부재 → Plan v3 구현 단계에서 다시 결정 사이클

**판정**: 첫 적용 시점의 부드러운 진입을 위해 명시 필요.

### H4. archive 이동 시 git rename detection 메커니즘 spec 부재

**v2 §5**: 구버전 계획 문서 5개를 `docs/archive/harness/`로 이동 (Plan v2 자체는 Plan v3 승인 후 별도 archive 검토 — 최종 archive 대상 7개로 확장 예정)
**v2 §4.3**: rename(R) 자동 stage 금지
**v2 §9.4**: "delete+add로 포함 또는 별도 commit으로 분리"

**문제**:
- git은 commit/diff 시 자동 rename detection (similarity threshold ~50%)
- 사용자가 의도적으로 `git rm` + `git add new_path` 해도 git이 **R로 분류 가능**
- v2 적용 commit이 archive 이동을 포함하면 첫 적용에서 자동 stage 차단
- spec 누락: rename detection을 어떻게 회피? `git -c diff.renames=false`? 같은 base name이면 R 허용?

**판정**: 운영 가이드 명시 필요. 또는 archive를 Plan v3 적용 commit과 분리하는 정책으로 못 박기.

### H5. §3.2 frontmatter parser spec 부족 — edge case 미정의

**v2 §3.2 지원 명시**: `sot_aux: []`, `[a]`, `[a, b]`

**누락 케이스 (실제 발생 가능)**:
- 따옴표: `sot_aux: ['docs/A.md', "docs/B.md"]`
- 테두리 공백: `sot_aux: [ docs/A.md , docs/B.md ]`
- 공백 포함 경로: `sot_aux: [docs/Phase 5 Notes.md]` — 실제 `docs/references/`에 공백 파일명 존재
- 콤마 escape, 경로 내 콤마
- 한글 파일명 (UTF-8 bytes)

**문제**:
- 단순 split 구현이면 위 케이스 일부 깨짐 → validate 거짓 실패 또는 거짓 통과
- "외부 YAML 의존성 없이"는 OK이나 **허용/거부 케이스 명시** 필요

**판정**: Plan v3에 허용/거부 정책 표 추가.

### H6. §6 작성 순서가 CLAUDE.md plan-stage 정책 위반

(v2 §6 헤더는 "v5 작성 순서". 본 피드백에서는 명명 통일에 따라 Plan v3 작성 순서로 매핑.)

**v2 §6 step 4 (원문 인용, "v5" → Plan v3로 매핑)**:
> "HIGH 발견 시 [Plan v3] 문서 보완 후 재리뷰"
**v2 §6 step 5**: "clean 또는 사용자 명시 승인 후 실제 적용"

**CLAUDE.md plan-stage 정책 (2026-05-09 명시 결정)**:
> "Plan stage codex 리뷰에서 CRITICAL/HIGH가 1건이라도 나오면 작업을 즉시 중단하고 사용자에게 보고한다. 자동 재리뷰 사이클을 돌리지 않는다."

**문제**:
- §6 step 4-5는 자동 재리뷰 사이클 함의
- 이전 game-flow plan v1~v5 5라운드 폭증 사고를 막기 위해 도입된 정책 정면 위반 (※ 이 "v1~v5"는 별개 문서 시리즈 — 본 harness Refine Plan 명명과 무관)
- Plan v3 작성 시 사이클 폭증 → usage limit 빠른 소진 위험

**판정**: §6 step 4를 "HIGH 발견 시 즉시 중단·사용자 결정"으로 정정 필수.

---

## 3. MEDIUM (5건 — 수정 후 적용 권장)

### M1. §3.3 Step 17 atomicity rollback 정책 모호

**v2 진술**: "commit 실패 시 status.json 원복 + 재stage 정리 + 실패 출력"

**모호점**:
- "원복": `git checkout`? 사전 snapshot 복원? spec 없음
- "재stage 정리": `git reset HEAD`? 그러면 사용자 사전 stage했던 것도 풀림 → 사용자 의도 손실

**필요**: 사전 staged 보존 vs 정리 일관성 결정.

### M2. §4.3 git status R/C 검출 메커니즘 spec 부재

**문제**:
- `git status --porcelain` 기본 출력은 rename detection 비활성 — R 미출력 가능
- 별도 명령(`git diff --cached -M --name-status` 또는 `--porcelain=v2`) 필요
- v2가 어느 명령으로 R/C 감지하는지 미명시 → 구현 모호

### M3. `--force-prune-completed` 백업 정책 부재

**문제**:
- completed phase의 `started_at / completed_at / duration_seconds` 손실 위험
- prune 전 `status.json.bak` 자동 생성? 사용자 backup 안내?

**필요**: data loss 방지책 spec.

### M4. UI 자산 워크플로우 가정 미명시

**v2 함의**:
- §2.2 sot_aux에 `docs/design_handoff/README.md` 포함 (read 가능)
- §4.1 deny-list `docs/design_handoff/**` (stage 차단)
- 추정 워크플로우: design_handoff는 read-only 레퍼런스, UI 자산은 design_handoff에서 *복사*해 `assets/`/`art/`/`themes/`로

**문제**:
- 워크플로우 미명시 → 실 작업자가 design_handoff 직접 수정 시도 → 차단 → 혼선
- Plan v3에 1-2줄 명시 필요

### M5. `addons/**` whitelist + large guard 외 추가 가드 부재

**문제**:
- 외부 addon은 GB 단위 가능 (예: shader library, asset pack)
- 단일 5MB / 총 25MB guard만으로 부족
- addon 추가는 phase 산출물보다 별도 commit이 자연스러움 — 정책 명시 누락

---

## 4. LOW (4건 — 표현/디테일)

### L1. 정량 KPI 누락
- v2 §7 수용 기준에 "자동 로드 줄 수 ≤ 200" 같은 정량 지표 없음
- v3/v4가 상속받은 643 → 195 KPI 명시 필요 (※ 여기 "v3/v4"는 `HARNESS_REVIEW_V3/V4.md`의 KPI를 가리킴 — Plan v3와 무관)

### L2. §4.2 `scripts/**` 중복
- "도구/스크립트" 그룹과 "Godot runtime" 그룹 양쪽에 명시. 표 cosmetic 노이즈.

### L3. §4.1 `.import/**` deny가 Godot 4에서 dead pattern
- Godot 4는 `.godot/imported/`에 캐시 저장. `.import/` 디렉토리는 Godot 3 잔재.
- 무해하나 노이즈. 제거 또는 코멘트로 의도 명시.

### L4. §3.3 Step 11 `git add` 명령 길이 제한
- 100개 파일 단일 명령은 OS 명령 길이 제한 (Windows ~8KB) 가능성
- 배치 또는 stdin pipe (`git add --stdin`) 사용 명시. 구현 디테일.

---

## 5. 결정 필요 항목

| ID | 항목 | 옵션 |
|---|---|---|
| **DR2-H1** | large change guard override | (a) 임계값 상향(500개/50MB) / **(b) phase frontmatter `large_change_ok: true` flag** / (c) `--allow-large` CLI 옵션 / (d) phase별 임계값 metadata.json |
| **DR2-H2** | read/stage policy 별도 섹션 | **(a) v2 §10 신설** / (b) Plan v3 작성 시 추가 |
| **DR2-H3** | metadata.json 최초 생성 | (a) `execute.py init-metadata` helper / (b) `harness.md` 안내 후 사람 수동 / **(c) `validate` 첫 호출 시 부재면 자동 생성** |
| **DR2-H4** | archive 이동 rename detection 회피 | (a) `git -c diff.renames=false` 사용 / (b) 동일 base name + 디렉토리만 변경 시 R 허용 / **(c) archive를 Plan v3 적용과 별도 commit으로 명시 분리** |
| **DR2-H5** | frontmatter parser 허용 케이스 | **(a) `[a, b]` 단순 split만 (따옴표/공백 경로 거부)** / (b) 따옴표 지원 / (c) pyyaml 도입 |
| **DR2-H6** | §6 작성 순서 (Plan v3로 가는 절차) | **(a) "HIGH 발견 시 즉시 중단·사용자 결정"으로 정정 (정책 정합)** / (b) 사용자가 plan-stage 자동 재리뷰 면제를 명시 결정한 경우에만 현재 표현 유지 |
| **DR2-M1** | atomicity rollback 사용자 stage 보존 | **(a) 사전 staged 보존 후 v2 추가 stage만 unstage** / (b) 전체 unstage / (c) 사용자 사전 stage가 있으면 v2 자동 stage 거부 |
| **DR2-M2** | rename detection 명령 | **(a) `git status --porcelain=v2 -z`로 R 정보 추출** / (b) `git diff --cached -M --name-status` 보조 사용 |
| **DR2-M3** | `--force-prune-completed` 백업 | **(a) 자동 `.bak` 생성** / (b) 사용자 명령 안내만 |
| **DR2-M4** | UI 자산 워크플로우 명시 | **(a) v2 §2.2에 1-2줄 추가** / (b) Plan v3에서 별도 섹션 |
| **DR2-M5** | `addons/**` 처리 | **(a) whitelist 유지 + addon 추가는 별도 commit 권고만** / (b) deny-list로 옮기고 명시 stage 강제 |

(굵게 표시는 추천안)

---

## 6. 추천 한 줄 조합

**DR2-H1(b) + DR2-H2(a) + DR2-H3(c) + DR2-H4(c) + DR2-H5(a) + DR2-H6(a) + DR2-M1(a) + DR2-M2(a) + DR2-M3(a) + DR2-M4(a) + DR2-M5(a)**

| 결정 | 근거 |
|---|---|
| H1(b) frontmatter flag | phase별 명시 의도 + spec이 phase 파일에 동봉 — drift 적음, override 명시적 |
| H2(a) v2 §10 신설 | Plan v3 누락 위험 차단, 본 v2에서 즉시 정합화 |
| H3(c) validate 자동 생성 | 사용자 마찰 최소, 첫 사용 시 부드럽게 진입 |
| H4(c) archive 별도 commit | rename detection 우회 시도보다 깔끔. Plan v3 적용 commit 따로, archive 따로 |
| H5(a) 단순 split | spec 단순성 유지, 따옴표 등 향후 필요 시 확장 |
| H6(a) 정책 정합 | CLAUDE.md plan-stage 정책 준수 (필수) |
| M1(a) 사용자 stage 보존 | 사용자 의도 손실 방지 |
| M2(a) porcelain v2 | 단일 명령으로 R 정보 추출 |
| M3(a) 자동 백업 | data loss 방지 |
| M4(a) 즉시 명시 | Plan v3 누락 위험 차단 |
| M5(a) commit 분리 권고 | guard만으로 충분, 정책 단순 유지 |

---

## 7. v2가 잘 풀어낸 부분 (보존 가치)

- **§1 16개 결정 일괄 채택**: feedback의 추천 조합을 그대로 반영 — 옳음
- **§4.1 deny-list 도입**: whitelist 단독의 보호 약함 문제(v1 H10) 해결 — 옳음
- **§4.2 whitelist 패턴 보강**: scripts/python, .uid 변종, 자산 디렉토리, .import, .claude 하위 — feedback HIGH 1~5 모두 흡수
- **§4.3 git status 상태별 처리 표**: 6가지 상태 명시 — feedback S-H3 해결
- **§4.2 `{task}` 런타임 치환 명시**: feedback S-H1 해결
- **§7 수용 기준 추가**: Godot metadata / Python helper / UI assets / design handoff / rename/copy 항목 — 운영 검증 가능
- **§8 자체 적대적 리뷰 라운드 포함**: plan-stage 정신 일부 반영 — 좋은 진전 (단 §6 step 4 정책 위반은 별개 문제)
- **§9 보정 정책 추가**: deny 우선 / settings.local 제외 / large change guard / archive 정책 — 자체 리뷰 반영 적절

---

## 8. 다음 단계

1. 본 피드백 사용자 검토
2. §5 결정 항목 11개 컨펌 (또는 §6 추천 조합 일괄 채택)
3. 결정 반영 위치 선택:
   - **(A) v2 본문 보완**: H2 §10 read policy 신설 + H6 §6 step 4 정정 + M4 §2.2 워크플로우 추가 — 즉시 정합화
   - **(B) Plan v3에 일괄 반영**: v2는 그대로 두고 Plan v3 작성 시 모든 결정 반영 — 한 번에 정리
4. Plan v3 작성 시 1회 자체 적대적 리뷰 (Self-Review Round). clean이면 사용자 컨펌. **HIGH 발견 시 자동 재리뷰 없이 즉시 사용자에게 보고** (CLAUDE.md plan-stage 정책 — H6와 동일 원칙 본 §8에도 적용)
5. 컨펌 후 실제 코드/문서 변경 진행

CLAUDE.md plan-stage 정책: HIGH 1건이라도 즉시 중단·사용자 결정. v2 채택 전 §5 결정 필수.
