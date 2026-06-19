# Phase 2 (탐색 솔버) — 적대적 리뷰 트레일

대상: auto-solver Phase 2 종결 커밋 `bdb23c1` (S13 자동발견 + S11~S14 CI 게이트 편입).
실행: `node codex-companion.mjs adversarial-review --wait --base HEAD~1 <focus>`.
정책: impl stage — CRITICAL/HIGH 1건이라도 나오면 수정 + 자체리뷰 + codex 재리뷰를 clean까지 반복.

---

## Round 1 (codex) — needs-attention, HIGH 1건

**Verdict**: needs-attention
**Summary**: Phase 2 게이트가 약속한 S11~S14 solve 집합을 검증하지 않고 통과할 수 있어, 문서 claim이 코드 계약보다 강하다.

### [HIGH] Solve replay gate fails open for missing/under-specified fixtures (`scripts/run_plan.py` selftest)
- `selftest()`가 `targets = golden + solves`를 만들고 **리스트가 비어있을 때만** FAIL. 기존 golden 플랜이
  존재하므로 `data/solutions/*.solve.json`이 비거나 S11~S14 중 하나가 실수로 삭제돼도 CI는 통과 →
  자동발견 해 누락을 못 잡는다.
- `expect = spec.get("expect", {})`이고 `check_expect()`는 **빈 expect를 어떤 비-에러 결과에도 성공으로 처리**
  (uncleared replay 포함). solve.json이 expect 없거나 약하면 verdict-only로 통과.
- 결론: 새 Phase 2 회귀 게이트가 "S11~S14 자동발견 해가 모두 100% saved로 리플레이된다"는 문서 계약을
  실제로 강제하지 않는다 — 존재하는 파일 + 그들이 주장하는 필드만 검증.
- **추천**: `*.solve.json`에 fail-closed — 기대 stage 집합(또는 count/이름) 강제, expect에 `cleared:true` +
  정확한 `saved` 요구, 빈/미지/누락 expectation을 harness 실행 전 거부. `actions_fired`/`search_meta.tools_used`
  일관성도 고려해 malformed solve가 약한 verdict-only fixture로 통과하지 못하게.
- **Next steps**: selftest 스키마 검사 강화 + 음성 케이스(expect 누락/solve 파일 누락 시 CI fail) 추가.

### 평가 (수용)
타당한 HIGH. selftest 확장 시 fail-open 두 경로(① 기대 solve 집합 미강제 ② 빈 expect 통과)를 간과했다.
defer 불가 — 아래 수정.

→ 대응: `## Self-Review Round 1`, `## Round 2 (codex)` 참조.

---

## Self-Review Round 1 (자체 적대적 리뷰) — self-HIGH 1건 발견·수정 후 clean

codex R1-HIGH(fail-open) 수정 결과물을 codex와 동일 기준으로 가혹하게 재검토.

### [self-HIGH] solve fixture 판정이 파일명 정규식 기반 → 잔존 fail-open
- fail-closed ②가 `if _solve_stage_id(pf) is not None`로 solve를 판정했다. `solutions/`에 `foo.solve.json`
  처럼 `stageNN` 형식이 아닌 이름이 있으면 stage_id=None → 강한 expect 검사 **스킵** → 빈/약한 expect가
  verdict-only로 통과(R1-HIGH와 같은 부류의 잔존 구멍).
- **수정**: solve 판정을 `pf in set(solves)`(glob 멤버십)으로 — `solutions/*.solve.json`으로 잡힌 모든 파일에
  강한 expect를 강제. `_solve_stage_id`는 기대 집합 누락 검출(①)에만 사용.

### 점검·수용(LOW, defer 정당)
- `EXPECTED_SOLVE_STAGES=(11,12,13,14)` 하드코딩 = **의도된 최소 기대 집합**(주석 명시: 새 해 S15+ 추가 시
  등재). S15가 있는데 미등재여도 "삭제 검출"만 빠질 뿐 expect 강제(②)는 멤버십이라 여전히 적용 → 약한 fail-open 아님.
- 손상 solve.json `json.loads` 예외 = 크래시 = exit≠0 = CI FAIL(fail-closed 방향) → 수용. golden도 동일 기존 동작.
- `run_plan_file` 에러(no SOLVER_RESULT) → `check_expect` "harness error" → FAIL(fail-closed) → 수용.

### 결과
self-HIGH 수정 후 재점검 = **HIGH 0**. 직접 검증 통과: `_solve_expect_invalid` 음성 4종(empty/no_cleared/
saved0/saved=True) reject·valid 통과, `missing(14 gone)→[14]`, `_selfcheck_schema→True` + 정상 9개
selftest PASS 유지. → codex 재리뷰(Round 2)로.
