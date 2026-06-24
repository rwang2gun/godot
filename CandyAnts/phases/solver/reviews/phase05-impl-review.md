# Phase 5b (가능성-공간 다양-해 — revised 구현) — Impl-stage 적대적 리뷰

> 대상: `tools/solver/diverse.py`(신규) + `solve.py`(forbid callable 확장) + `try_solve.py`(diverse/diverse-verify
> 위임) + `auto-solver-plan.md` frontmatter `verify`(diverse-verify 편입) + `data/solutions/stage12.diverse.json`
> (range 스키마 재생성). plan-stage 종결([phase05-plan-review.md](phase05-plan-review.md)) 후 revised 5b 구현.
> 정책: impl-stage = 자체 적대 리뷰 clean(HIGH 0) → codex 재리뷰 → clean까지 루프.

## 구현 요약
- **표현 = 검증된 연속 구역(range)**: cell_x 슬롯(ant_reaches_x)을 placement 셀로 환산, *나머지 고정* 독립
  축 스윕(엔진 D4) → intervals/gaps/gap_verified(stride==1=full). 비공간 슬롯(picked_ge carry 등)=placement_axis
  "none"(point).
- **4요소 solution-class**: skill_multiset + 슬롯별 (검증 구역, role/state, trigger/timing). `_class_sig` dedup +
  `_make_forbid` 4요소 술어 forbid(placement∈gap_verified 구역, R3 — 구역만 아님). same-region·다른 role/timing은
  forbid 안 걸려 발견(2단계 (a) 자동).
- **5c 게이트** `diverse-verify`: reference clear + 각 cell_x 슬롯 interval 전 셀(stride1) clear + 도메인-내부
  경계 밖 fail + gap fail. `_selfcheck_diverse`(검출기 fail-open 가드). `verify` frontmatter 편입.
- **solve.solve(forbid=)**: callable 술어 허용(기존 sig iterable·None 동작 불변, byte-identical).

## Self-Review Round 1 (자체 적대적 리뷰)

가혹 기준(CRITICAL/HIGH/MEDIUM/LOW + hypothetical + cross-doc + dead branch + fail-open) 자체 적용.

### 발견·수정 (구현 중)
- **[HIGH→fixed] 게이트 경계-밖 fail 단언이 도메인 끝 구역에서 false-fail**: interval이 스윕 도메인 끝에
  닿으면(예 S12 slot1 `[6–18]`, domain `[0,18]`) `hi+1`은 미샘플 → fail 미보장(ant_reaches_x le 큰 임계 =
  즉시 발화 모호성, 3a R7~R10 동류). 무조건 `lo-1`/`hi+1` fail 단언하면 게이트가 정당한 해를 false-fail.
  → **도메인 내부 경계만 단언**(`lo>dom_lo`/`hi<dom_hi` AND `gap_verified`)로 수정. 그 경우 `lo-1`/`hi+1`은
  스윕된 fail 셀이라 결정론 재현. verify_one_diverse + coverage에 domain 검증 추가.

### 검토 — clean (HIGH 0)
- **fail-open 차단**: `_selfcheck_diverse`(17 케이스, 검출기 음성/양성) + `verify_diverse` 빈 대상 FAIL(fail-closed)
  + coverage(schema_version·skill_multiset 파생·expect 강계약·gap_verified==(stride==1)·도메인·ref_index/role/timing
  reference 파생 일치). 변조/stale 거부.
- **gate 권위**: gap_verified 구역은 stride==1 = **전 셀 리플레이**(hidden fail-island 0). reference·경계·gap 모두
  엔진 재검증(analyze --verify 동형). pos는 권위 주장 아님(axis_independent 명시).
- **back-compat/회귀 0**: `forbid=None`이면 두 필터 skip → byte-identical. selftest 16/16 PASS, frame 불변
  (s12=2385·s13=2719·s14=4624), analyze --verify 4스테이지·diverse-verify stage12 그린.
- **종료성**: `seen_sigs` dedup + 빈-플랜 1회 break + `extra_cap` 예산 → 무한루프 없음.
- **merge acceptance(S12)**: naive 2해(`@24/888/312`·`@72/840/360`)가 **1 solution-class**로 병합(슬롯 col[0–3]·
  [6–18]·[0–18] 검증 구역에 sol2 포함). 실측 확인.

### 정직 경계 (over-claim 아님 — 문서화)
- **axis_independent**: 보고 range는 *나머지 고정 시* 각 축 cross-section. joint 곱공간 클리어 미주장(조합 폭발).
  플래그·note로 명시.
- **forbid 보수성(under-report 방향)**: 4요소 술어가 비공간(none) 슬롯을 (skill,role,timing) 일치로 막으므로,
  "같은 timing-슬롯 재사용 + 다른 placement" class를 못 찾을 수 있다. **보수적 under-report(정직 정지)**이지
  거짓 주장 아님 — 사용자/계약은 완전성 주장보다 정직 정지 선호. 현 검증 스테이지(S12 전 cell_x, S13/14 carry)는
  올바른 1-class 산출. (codex 검토 의견 수렴 대상.)
- **grid_cols 도메인 한정**: 스윕 도메인=[0, grid_cols-1]∪{c_star+1}. 지형 밖 placement는 비탐색(셀 단위, 정직).

**자체 리뷰 verdict: clean (HIGH 0)** — codex 재리뷰 진입 가능(사용자 트리거: `/codex:adversarial-review` 또는
bash `codex-companion.mjs adversarial-review`, [[codex-adversarial-review-invocation]]).
