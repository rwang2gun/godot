> SUPERSEDED: See `docs/Harness_Refine_Plan_v3.md`.

# Harness_Feedback_v4 — `HARNESS_REVIEW_V4.md` plan-stage 적대적 리뷰

작성일: 2026-05-10
대상: `docs/HARNESS_REVIEW_V4.md`
검토자: Claude (plan-stage 자체 적대적 리뷰)
정책 근거: `CLAUDE.md` §개발 프로세스 — Plan stage CRITICAL/HIGH 1건 발견 시 자동 재리뷰 X, 즉시 중단·사용자 결정

> **결론**: v4 그대로 적용 금지. HIGH 4건 + MEDIUM 6건 + LOW 2건. 사용자 결정 후 v5 재작성 권장.

---

## 1. 사실 관계 사전 검증 (v4 진술 정확성)

| v4 진술 | 실측 | 판정 |
|---|---|---|
| 로컬 phase 파일 20개 (1~20) | `ls phases/mvp/phase*.md` = 20개, phase01~phase20 | ✓ |
| Notion page_id 매핑 23개 (1~23) | `notion-phase-ids.json.phases` 키 = 1~23 | ✓ |
| phase 6 page_id null | `phases.6.page_id == null` | ✓ |
| `execute.py`가 `git add -A` 사용 | scripts/execute.py:184 `subprocess.run(["git", "add", "-A"], ...)` | ✓ |
| `init_status()`가 `active_revision` 미생성 | scripts/execute.py:64-89 — `task / started_at / completed_at / phases`만 작성 | ✓ |
| 현 CLAUDE.md "현재 22 phase 고정" | CLAUDE.md 마지막 문단 — 정확 | ✓ |

→ **v4의 사실 진술은 모두 정확**. 진단/측정에는 결함 없음. 결함은 *처방* 부분에 있다.

---

## 2. HIGH (4건 — 적용 차단 사유)

### H1. `.uid` 자동 생성 파일 회귀 위험 (D5 권장안 A의 본질적 결함)

**사실**:
- 현 `git status`: untracked `.uid` 파일 14개 (예: `scripts/input/CoordSpace.gd.uid`, `tests/test_GameAction.gd.uid`)
- `.uid`는 Godot이 `.gd` 파일 추가/이동 시 자동 생성하는 메타 파일
- **phase 산출물의 일부** — commit되지 않으면 다른 머신/CI에서 import 깨짐 (silent regression)

**v4의 처방**:
- §3 D5 권장안 A: "untracked 파일이 있으면 자동 커밋을 중단"
- §4.4: "phase 완료자는 먼저 의도한 파일만 직접 stage한다"
- §3 D5: "v4 첫 적용에서는 안전을 위해 `--stage-all` 옵션 미도입"

**실제 영향**:
- `.uid` 파일은 거의 매 phase 생성됨 → **매 phase complete가 1회 이상 중단**
- 모델 에이전트가 매 phase마다 14개씩 일일이 `git add` 호출해야 함 → 비용 증가
- 누락 가능성 ↑ (silent regression — 다음 머신에서 깨짐)
- 기존 `git add -A`가 이걸 자동 해결하던 것을 v4가 제거하면서 대체 정책 부재

**판정**: 권장안 B(phase manifest `commit_paths`)를 회피한 결과지만, B 없이 A를 강제하면 운영 자체가 깨진다.

### H2. §4.1 권장 흐름과 §4.4 staged-only 정책의 절차 누락

**v4 §4.1 권장 흐름**:
```
python scripts/execute.py {task} validate
python scripts/execute.py {task}
python scripts/execute.py {task} next
frontmatter sot/sot_aux read
phase 작업
manual/automated verify
/codex:adversarial-review
python scripts/execute.py {task} complete {N}
```

**v4 §4.4**: "staged 변경이 없으면 'stage files intentionally before complete' 메시지로 중단"

**문제**: §4.1 흐름에 `git add <intended files>` 단계가 **없다**. 모델이 흐름만 따르면 staged 0인 채 complete 호출 → 항상 중단. 자체 모순.

**판정**: 흐름에 staging 단계 명시 또는 자동화 정책(H1 해결과 연계) 필수.

### H3. `sot: self` semantic escape hatch

**v4 §4.3 표**: "Phase 1~4 | `self` | `[]`"
**v4 §3 D4 validate 검사**: "`sot != self`인 경우 경로 존재"

**문제**:
- phase 1~4의 진짜 SoT는 본문이 아니라 PRD/ARCHITECTURE (이미 자동 로드)
- "잘 모르겠으면 self"로 default하면 결정성 보장이 무너짐 — frontmatter 도입 본 취지 훼손
- 새 phase 작성자가 self 사용 시 validate가 통과 → 검증 무효화 escape hatch

**판정**: `self` 폐지하고 phase 1~4도 `sot: docs/PRD.md` 또는 `sot: docs/ARCHITECTURE.md`로 명시. validate에서 self 허용 제거.

### H4. metadata.json의 `local_phase_count` hard-code + lifecycle 부재

**v4 §4.2 metadata.json**: `"local_phase_count": 20`
**v4 §3 D4 validate**: "로컬 phase 파일 수가 `metadata.local_phase_count`와 일치"

**문제**:
- post-MVP phase 21 진입 → `phase21-*.md` 생성 시 `local_phase_count`도 동기 갱신 필요
- v4에 갱신 책임자/시점/방법 명세 없음
- 갱신 누락 시 validate가 모든 후속 작업 차단
- metadata.json **최초 생성** 책임자도 불명 (사람? `harness.md`? `execute.py` helper?)

**판정**: 다음 중 하나 결정 필요
- (a) `execute.py update-metadata` helper 도입 + harness.md 흐름에 호출 명시
- (b) `local_phase_count` 필드 폐지하고 validate가 동적으로 `glob('phase*.md')` 카운트 (권장 — hard-code 제거)

---

## 3. MEDIUM (6건 — 수정 후 적용 권장)

### M1. validate 실패 시 fix path 부재

`status.json`의 phase 파일 목록 vs 실제 파일 목록 불일치 시 validate fail. 현재 해결책은 `reset`인데 reset은 완료 phase의 `duration_seconds` 등 진행 데이터까지 삭제. 데이터 손실 없는 fix 명령(`execute.py status sync` 등)이 명세에 없음.

### M2. validate 호출 시점 모호

§4.1 권장 흐름에 매 phase마다 `validate`가 들어있다. 매 phase 호출인지 세션 시작 1회만인지 미명시. 매 phase면 비용 낭비, 1회면 그렇게 명시 필요.

### M3. 버전 누적 정책 부재

`docs/HARNESS_REVIEW.md`(v2 내용) + `HARNESS_REVIEW_V3.md` + `HARNESS_REVIEW_V4.md` 3개 공존. §8이 "v3 대비 차이"로 v3를 SoT처럼 다루지만 v4 적용 후 v3는 outdated. 폐기 정책(삭제 / 아카이브 / 본 문서로 통합)이 v4에 없음 → 다음 v5 등장 시 같은 drift 반복.

### M4. §1 표 자기 참조 오염

"현재 하네스 구조" 표에 `docs/HARNESS_REVIEW_V3.md`를 일반 구조 항목으로 나열. v3는 plan 문서지 운영 구조의 일부가 아님. 표의 의미가 흐려짐. 제외 권장.

### M5. CLAUDE.md 문구 정정의 향후 drift

§4.6 "현재 23 phase 매핑, 로컬 MVP phase 파일은 20개" — phase 23 추가/이름 변경 시 또 갱신 필요. metadata.json을 도입하면서도 CLAUDE.md에 같은 숫자를 적는 건 H4와 같은 종류의 SoT 분산. CLAUDE.md는 **"phase 수는 `metadata.json` 참조"** 1줄만 두는 게 drift 최소.

### M6. 자동 로드 제외 목록의 `status.json`은 비KPI

§3 D1 자동 로드 제외에 `status.json` 포함. 애초에 status.json은 자동 로드 대상이 아니므로(execute.py 출력으로만 노출) §6 자동 로드 측정 KPI에서는 빠져야 정직.

---

## 4. LOW (2건 — 표현 수정)

### L1. §6 검증 명령 환경 의존성

```text
rg -L "^sot:" phases/mvp/phase*.md
```
PowerShell glob 확장이 환경별로 다름. ripgrep 안전 형식 권장:
```text
rg -L "^sot:" phases/mvp -g 'phase*.md'
```

### L2. `sot_aux` 배열 파싱 helper 부재

D2 스키마: `sot_aux: []` (YAML 배열)
현 `parse_frontmatter`(scripts/execute.py:43-53)는 단순 `key:value` split 파서 — YAML 배열 미지원.
validate가 `sot_aux`를 배열로 해석할 helper(또는 `pyyaml` 의존성 추가)를 어디에 둘지 명세 부재.

---

## 5. 결정 필요 항목 (사용자 입력 대기)

| ID | 항목 | 옵션 |
|---|---|---|
| **D-H1** | `.uid` 자동 생성 메타 파일 정책 | (a) `.gitignore` 추가 (다른 머신 회귀) / (b) phase 파일 `commit_paths` 도입 / **(c) `execute.py complete`에 화이트리스트(`*.uid`, `*.gd`, `*.tscn`) 자동 stage** / (d) `--stage-all` 옵션을 v4 첫 적용부터 도입 |
| **D-H2** | §4.1 흐름의 staging 단계 명시 | D-H1 결정에 따라 자동(c/d) 또는 수동(b) 명시 |
| **D-H3** | `sot: self` 처리 | (a) 폐지 + phase 1~4 명시 SoT 채움 / (b) 유지하고 의미 정의 강화 |
| **D-H4** | `local_phase_count` 처리 | (a) helper 도입 + 흐름에 호출 명시 / **(b) 필드 폐지 + validate가 동적 glob 카운트** |
| **D-M3** | v2/v3/v4 누적 정리 | (a) v5로 통합 후 v2/v3 삭제 / (b) v2/v3는 `docs/archive/`로 이동 / (c) 모두 살려두고 헤더에 "SUPERSEDED" 표기 |

---

## 6. 추천 한 줄 조합

**D-H1(c) + D-H2 자동 + D-H3(a) + D-H4(b) + D-M3(a)**

| 결정 | 효과 |
|---|---|
| H1(c): 화이트리스트 자동 stage | `.uid` 회귀 방지 + 모델 staging 부담 0 + unrelated 파일 보호 동시 달성 |
| H2 자동: §4.1 흐름에 staging 단계 별도 X (complete 내부 자동) | 흐름 단순 유지 |
| H3(a): `self` 폐지 | escape hatch 제거, frontmatter 정합성 유지 |
| H4(b): 동적 glob | hard-code 제거, post-MVP 추가 시 metadata 갱신 불필요 |
| M3(a): v5 통합 + v2/v3 삭제 | 단일 SoT 유지, drift 차단 |

→ 이 조합으로 가도 될지 컨펌 후 v5 재작성 진행.

---

## 7. 부록 — v4가 잘 풀어낸 부분 (보존 가치)

- **D3 metadata 분리** (구조 메타 ≠ 런타임 상태): 옳은 방향. `active_revision`을 status.json에서 분리한 건 v3 H3 보정으로 적절.
- **D4 validate 명령**: phase 계약을 기계 검증 가능하게 만든 건 큰 진전. 검사 항목 자체는 H3/H4/M1만 보정하면 유지 OK.
- **D1 자동 로드 축소 + lazy SoT**: v2~v4 일관 핵심 — KPI 643줄 → 195줄, 변경 없이 v5에서도 유지.
- **D2 frontmatter `sot`**: 결정성 보장 핵심 메커니즘. self 폐지(H3)만 하면 그대로 유지.
- **§7 롤백 절차**: 비파괴 설계는 적절. v5에서도 그대로 사용 가능.
