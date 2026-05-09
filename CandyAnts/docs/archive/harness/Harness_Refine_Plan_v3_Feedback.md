> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness_Refine_Plan_v3_Feedback — `Harness_Refine_Plan_v3.md` plan-stage 적대적 리뷰

작성일: 2026-05-10
대상: `docs/Harness_Refine_Plan_v3.md`
검토자: Claude (plan-stage 자체 적대적 리뷰)
정책 근거: `CLAUDE.md` §개발 프로세스 — Plan stage CRITICAL/HIGH 1건 발견 시 자동 재리뷰 X, 즉시 중단·사용자 결정

> **결론**: v3는 v2 feedback의 11개 결정을 충실히 반영했고 §3/§7 read/stage 분리, §10 plan-stage 정책 명시 등 자체 모순이 없다. 다만 **HIGH 1건 + MEDIUM 4건 + LOW 6건** 잔존. HIGH 1건은 사고 시 복구 비용이 크므로 적용 전 결정 필수.

---

## 1. 사실 검증 (v3 정확성)

| v3 진술 | 검증 | 판정 |
|---|---|---|
| §1 11개 결정 | v2 feedback DR2-H1~M5 매핑 정합 | ✓ |
| §3.1 KPI 643 → 195 | `HARNESS_REVIEW_V3.md` KPI와 일치 | ✓ |
| §3.2 phase mapping | phase 1~20 + post-MVP 21~23 정합 | ✓ |
| §6.3 strict order 19 step | atomicity rationale 명시 | ✓ |
| §7.2 deny-list / §7.3 whitelist | v2 feedback HIGH 1~5 흡수 | ✓ |
| §10 plan-stage 정책 | CLAUDE.md 정합 | ✓ |
| §1 DR2-M1 + §6.3 step 5-6 | "사전 staged 항목 있으면 중단" — feedback DR2-M1(a) "보존 후 unstage"보다 **더 strict** | ⚠ 분기 |

→ v2 feedback의 11개 결정 모두 §1에 명시 수용. DR2-M1만 v2 feedback 추천(보존)보다 더 엄격(clean-index 요구)으로 채택 — §6.3 Rationale에서 정당화하나 사용자 확인 필요.

---

## 2. HIGH (1건 — 적용 차단 사유)

### H1. §7.5 `large_change_ok: true` bypass 범위가 size guard까지 포함 — 사고 시 복구 어려움

**v3 진술 (§7.5)**:
> "If target phase frontmatter has `large_change_ok: true`, bypass count/size guard."

**v3 §3.2 매핑**:
- phase 9 (ui-theme-assets): `large_change_ok: true`

**문제**:
- bypass 범위가 **3종 모두**: `>100 candidates / >5MB single / >25MB total`
- phase 9는 `large_change_ok: true`. 디자인 파일을 `assets/`로 잘못 복사하면(예: PSD 50MB, 4K texture set 100MB+) **모든 size guard가 무력화**
- repo에 거대 파일 한번 commit되면 `git filter-branch`/`git lfs migrate` 류로 사후 제거 — 비용 큼
- count guard만 푸는 게 의도였을 텐데(자산 phase는 파일 수가 많을 뿐), spec이 size guard도 함께 풂

**판정**: phase 9 매핑이 이미 `true`인 상태에서 bypass 범위가 전부면, 사고 발생 시 회복 비용이 크다. count/size guard 분리 권장.

**결정 필요 (DV3-H1)**:
- **(a) `large_change_ok`를 count guard 전용으로 한정. size guard는 항상 적용 (강력 권장)**
- (b) `large_count_ok` / `large_size_ok` 두 flag 분리
- (c) 현재 spec 유지 (size guard도 bypass) — 자산 phase 운영 편의 우선

---

## 3. MEDIUM (4건 — 수정 후 적용 권장)

### M1. DR2-M1 채택이 v2 feedback 추천과 분기 — 사용자 확인 필요

**v2 feedback DR2-M1(a) 추천**:
> "사전 staged 보존 후 v2 추가 stage만 unstage"

**v3 §1 / §6.3 step 5-6 채택**:
- "complete 시작 시 사전 staged 항목이 있으면 중단"
- §6.3 Rationale: "Allowing pre-staged files would let unrelated changes ride along in the phase commit. A clean-index requirement is stricter but keeps the commit contract deterministic."

**영향**:
- v3가 의도적으로 더 엄격한 변종 선택 (운영 유연성 → 계약 결정성 trade-off)
- 운영 영향: 사용자가 phase 외 변경을 사전 staged 상태로 두면 `complete` 차단. `git reset HEAD` 후 재시도 강제
- v2 feedback 컨펌이 "보존" 방향이었는데 v3가 "중단" 방향 — 사용자 의도 재확인 필요

**결정 필요 (DV3-M1)**:
- (a) v3의 strict 채택 유지 (clean-index 요구)
- (b) feedback 원안(보존 + 추가 stage만 unstage)으로 회귀

### M2. §4 "task defaults known" 메커니즘 spec 부재

**v3 §4**:
> "If `metadata.json` is missing, validate creates it with task-specific defaults **when known**. If task defaults are unknown, validate fails."

**문제**:
- "known"의 출처 불명: execute.py 하드코드? 별도 registry? 외부 파일?
- 현재 mvp는 §4에 default 명시되어 있으니 알려진 task. 미래 task(예: `sprint01`) 추가 시 누가/어디에 default 등록?
- v3 §6.1 validate가 fail 메시지 출력하지만, 등록 절차 spec 없음

**결정 필요 (DV3-M2)**:
- **(a) execute.py 하드코드 (mvp만, 신규 task는 매뉴얼 metadata.json 작성 후 진행)**
- (b) `tasks/defaults.json` registry 파일
- (c) 첫 task는 사용자가 metadata.json 직접 작성하고 validate는 그 후 진행

### M3. §5 frontmatter parser — 경로 내부 공백 처리 spec 모호

**§5 Rejected 명시**:
- "paths with leading/trailing spaces inside array items"
- "paths containing commas"

**미명시**:
- 경로 *내부* 공백 (예: `[docs/Phase 5 Notes.md]`)
- "Path guidance"는 "권장"일 뿐 strict reject 안 함

**문제**:
- 단순 split(",") + strip() 구현이면 내부 공백은 통과 → 실제로는 OS상 valid 경로지만 spec 정책 불명
- `docs/references/`에 실제 공백 포함 파일명 존재 → 작성자가 직접 sot_aux에 적을 가능성

**결정 필요 (DV3-M3)**:
- **(a) 내부 공백도 reject (strict consistency)**
- (b) accept (Path guidance만으로 충분)
- (c) 명시 허용 + path guidance 강화

### M4. §6.1 validate 호출 시점 — 세션 시작만 자동, 나머지는 수동

**v3 §6.1**:
> "When to run: At `/harness {task}` start, once per session. After phase files are added/deleted/renamed. After metadata, harness command, or `execute.py` changes. After a complete failure caused by phase contract mismatch."

**문제**:
- 세션 시작은 §9 harness.md 갱신으로 자동 (OK)
- 나머지 3개 케이스는 사용자가 기억해야 함 — v2 feedback M5 그대로 잔존
- pre-commit hook 또는 file-watch 등 enforcement 메커니즘 spec 없음

**결정 필요 (DV3-M4)**:
- **(b) 현 spec 유지 (수동 트리거 책임) — 명시만으로 충분하다고 판단**
- (a) 자동 enforcement(pre-commit hook 등) 추가

---

## 4. LOW (6건 — 표현/디테일)

### L1. §3.2 phase 1~5 retroactive frontmatter는 cosmetic
- phase 1~5는 이미 완료/커밋. 매핑 표 상 sot/sot_aux 추가는 운영 효과 없음
- validate path 존재 검증만 됨. 비파괴이므로 무해. completeness 가치만

### L2. §3.2 schema 예시 vs default 정의
- 예시는 `large_change_ok: false` 명시. 필드 설명은 "선택, 기본 false"
- 작성자가 "필드 누락 = false"임을 헷갈릴 수 있음. 예시에서 빼는 게 명확.

### L3. §9 phase 생성 템플릿 default 값 미명시
- "Add the phase frontmatter template fields `large_change_ok`, `sot`, `sot_aux`."
- 새 phase 생성 시 `large_change_ok: false`, `sot: <empty>`, `sot_aux: []` 등 default 값 명시 필요
- harness.md §4 phase 템플릿에 들어가야 함 (실제 적용 단계)

### L4. §11 acceptance에 `addons/**` large guard 적용 검증 누락
- §7.3 + §7.5 "addon note"에 정책은 있으나 §11 수용 기준 표에 명시 없음
- 추가 권장: "addons large change | `addons/**` 변경에도 large_change_ok 또는 별도 commit 정책 적용"

### L5. `large_change_ok` 파싱 — string vs bool 처리 detail
- 현 `parse_frontmatter`(scripts/execute.py:43-53)는 raw string `"true"` / `"false"` 반환
- §6.3 step 12와 §7.5 비교 로직이 string lower 비교 또는 bool 변환 필요 — 구현 detail 명시 권장

### L6. 첫 v3 적용 시 backlog `.uid` 14개 자동 stage
- 현 git status에 untracked `.uid` 14개 누적
- v3 §7.3 whitelist `**/*.uid` 매칭 → 첫 phase complete에서 모두 자동 stage
- 의도된 동작이지만 첫 commit이 phase 산출물 + backlog metadata 혼재 — 운영 노트 또는 별도 정리 commit 권장

---

## 5. 결정 필요 항목 요약

| ID | 항목 | 옵션 (추천 굵게) |
|---|---|---|
| **DV3-H1** | `large_change_ok` bypass 범위 | **(a) count guard만 bypass, size guard는 항상 유지** / (b) `large_count_ok` / `large_size_ok` 분리 / (c) 현 spec 유지 |
| **DV3-M1** | DR2-M1 strict vs lenient | (a) v3 strict 유지 (clean-index) / (b) feedback 원안(preserve pre-staged + 추가 stage만 unstage)으로 회귀 — *사용자 의도 확인 필수* |
| **DV3-M2** | metadata defaults source | **(a) execute.py 하드코드 (mvp만)** / (b) `tasks/defaults.json` registry / (c) 사용자 매뉴얼 작성 후 validate |
| **DV3-M3** | 경로 내부 공백 | **(a) reject (strict consistency)** / (b) accept / (c) 명시 허용 + guidance 강화 |
| **DV3-M4** | validate enforcement | **(b) 현 spec 유지 (수동 트리거)** / (a) pre-commit hook 등 enforcement |

LOW 6건은 v3 본문 마이너 보강으로 일괄 처리 권장 (별도 결정 불요).

---

## 6. 추천 한 줄 조합

**DV3-H1(a) + DV3-M1(?) + DV3-M2(a) + DV3-M3(a) + DV3-M4(b)**

| 결정 | 근거 |
|---|---|
| H1(a) count guard만 bypass | size guard는 사고 방지 안전망. count는 자산 phase 의도된 우회 |
| M1(?) | 사용자 의도 재확인. v2 feedback은 (b) 추천이었으나 v3는 (a) 채택. 어느 쪽이 의도? |
| M2(a) execute.py 하드코드 | mvp 단일 task 환경에서 가장 단순. 미래 task 추가 시 코드 patch |
| M3(a) reject | 명시 거부 케이스(공백) 일관성 유지. wrapper 패턴 강제 |
| M4(b) 현 spec 유지 | hook 추가는 별도 후속 — 본 v3 범위 외 |

DV3-M1만 사용자 의도 확인 필요. 나머지는 추천 조합으로 일괄 채택 가능.

---

## 7. v3가 잘 풀어낸 부분 (보존 가치)

- **§3 Read Policy / §7 Stage Policy 별도 섹션 분리**: v2 H2 약속 이행 — 자체 모순 해소
- **§3.3 UI asset workflow 명시**: design_handoff read-only + 복사 패턴 — v2 M4 해결
- **§6.3 strict order 19 step**: atomicity 결정성 + Rationale 명시 — v2 M1 해결 (단 strict 분기)
- **§7.4 porcelain v2 detection**: R/C 검출 메커니즘 명시 — v2 M2 해결
- **§8 archive 별도 commit**: rename detection 회피 + Plan v3 적용과 분리 — v2 H4 해결
- **§10 plan-stage 정책 명시**: HIGH 발견 시 자동 재리뷰 금지 — v2 H6 자기 모순 차단
- **§11 acceptance 18개 항목**: 수용 기준 정량/정성 혼합 명시
- **§12 Next Step**: 실제 적용 6단계 명시
- **§1 11개 결정 명시 표**: feedback 추천 조합과 1:1 매핑 — 추적성 ★★★

---

## 8. 다음 단계

CLAUDE.md plan-stage 정책: HIGH 1건이라도 즉시 중단·사용자 결정.

1. 본 피드백 사용자 검토
2. **DV3-H1 결정 필수** (size guard 유지 권장 — 사고 회복 비용 고려)
3. DV3-M1~M4 결정 (M1은 사용자 의도 재확인)
4. 결정 반영 위치 선택:
   - **(A) v3 본문 즉시 보완**: §7.5 bypass 범위 정정 + §1 결정 표 갱신 — 즉시 정합화
   - **(B) Plan v4 작성**: v3는 그대로 두고 v4에서 모든 결정 반영
5. LOW 6건은 (A) 선택 시 동시 보강. (B) 선택 시 v4에 일괄 반영
6. 컨펌 후 §12 Next Step 절차로 실제 적용 진입

본 피드백 자체에 대한 자체 적대적 리뷰는 사용자 결정 후(또는 별도 요청 시) 1라운드 진행 가능.
