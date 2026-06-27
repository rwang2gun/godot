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

## Round 1 (codex adversarial-review, bash companion `--base 6bef989`)

Verdict: **needs-attention** (HIGH×2 + MEDIUM×1). 명령: `node codex-companion.mjs adversarial-review --wait --base 6bef989 <focus>`.

- **[HIGH] provisional sampled 구역을 병합 키로 사용** (`diverse.py` `_class_sig`): SWEEP_CELL_CAP(40) 초과
  스테이지에서 `_sweep_placement`가 stride>1 구역을 gap_verified=false/provisional로 표기하나 `_class_sig`는
  intervals를 무조건 동치 키로 써 `_record`가 dedup → 같은 sampled interval 모양의 *다른* 해를 중복으로 버리고
  전략 루프가 `if not is_new: break`로 정지. "미검증=병합 금지" 위반, 넓은 스테이지에서 과소보고.
  → provisional 슬롯은 intervals 대신 fixed_cell로 키잉(다른 셀=비병합).
- **[HIGH] 클래스 정체성이 target y-band 무시** (`diverse.py` `_role_sig`): `model.propose`가 backpath row 유래
  y_min/y_max로 액션 생성(model.py:288·299) → 같은 skill/select/x·다른 y-band=다른 층/레인=실질 다른 해인데
  `_role_sig`가 y 드롭 → 거짓 병합·forbid 차단. range-sweep은 x만 스윕 → y는 정체성·스윕 둘 다 누락(차원 상실).
  → y-band를 role 정체성에 포함(미스윕=비병합, 보수적).
- **[MEDIUM] diverse-verify가 보고서를 요청 stage에 미바인딩** (`diverse.py` `verify_one_diverse`):
  `report['stage']`/`stage_scene`를 stage_id와 대조 안 함 → stage12 보고서를 stage13.diverse.json으로 저장 시
  Stage12 리플레이로 false-green. → stage/scene 바인딩 fail-closed + n_solution_classes==len(classes) 검증.

조치(impl-stage 정책, HIGH defer 불가): 셋 다 수정 → stage12.diverse.json 재생성 → 자체 적대 리뷰 → codex 재리뷰.

## Self-Review Round 2 (codex R1 수정 후 자체 적대 리뷰)

3 finding 수정(`diverse.py` 한정, 엔진/PlanRunner/solve.py 무변경):
- **[R1-HIGH] provisional 비병합**: `_class_sig` cell_x 구역키 = gap_verified면 intervals(검증 구역 병합),
  미검증이면 `('provisional', fixed_cell)`(다른 셀=비병합). "미검증=병합 금지" 충족.
- **[R1-HIGH] y-band 정체성**: `_role_sig`에 `band:[y_min,y_max]` 추가(있을 때만). y는 미스윕 축이라
  다른 band=다른 class(보수적·비병합). x-시프트(같은 row)는 band 동일→병합 유지(merge-acceptance 보존).
- **[R1-MED] stage 바인딩**: `verify_one_diverse`가 report['stage']/['stage_scene']를 stage_id와 fail-closed
  대조 + `_coverage_check_diverse`에 n_solution_classes==len(classes) 검증.
- **회귀 가드**: `_selfcheck_class_sig`(병합/비병합 3규칙) 추가 + good() 픽스처 band·n 반영 + n-mismatch 거부 케이스.

자체 적대 검토(HIGH 0):
- provisional 슬롯은 `_make_forbid`가 어차피 forbid 안 함(gap_verified만) → 동일 plan 재발화 시 fixed_cell 동일
  sig로 dedup→안전망 break. 과소-탐색은 정직 표기(provisional)된 *선존* 한계, soundness 버그 아님(거짓 병합 제거가 핵심).
- band 부재 액션(climber carry/picked_ge)=role 불변(band 키 생략). float band는 `_band` 결정론 동일 산출→json
  왕복·동치 정확(diverse-verify PASS 확증).
- 신규 체크 전부 fail-closed 강화(거부 추가)뿐, fail-open 유입 0. solve.py 무변경→selftest byte-identical.
- 정직 경계: y는 1D 정체성만(2D 스윕 미구현, codex 권고 (a) 채택), provisional 대안 enumerate 안 함(선존).

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(회귀 0). → fix 커밋 후 codex 재리뷰(Round 2).

## Round 2 (codex adversarial-review, `--base 6bef989` = revised 5b + R1 fix `cf1fd38`)

Verdict: **needs-attention** (HIGH×1 + MEDIUM×1). R1 정체성 수정은 맞으나 *발견 루프*가 여전히 과소보고 가능.

- **[HIGH] action-local forbid이 슬롯 공유 distinct class 억제** (`diverse.py` `_make_forbid` + `solve.solve`
  소비): `_class_sig`는 plan 전체(skill_multiset+모든 슬롯)로 class를 정의하나 `_make_forbid`는 후보가 이전
  class의 슬롯 *하나*라도 일치하면 즉시 True. `solve.solve`가 이를 후보별 hard-filter로 적용 → 비공간 공유 슬롯
  (예: 같은 `picked_ge n=1` carry)이나 공유 verified cell_x 슬롯을 공유하되 다른 슬롯에서 갈라지는 후속 class가
  차단. 직접적 과소보고. `_selfcheck_class_sig`는 dedup만 테스트, forbid 발견성 미검증.
  → **plan-level 배제로 교체**: `base+[action]`이 이미 발견된 class를 *정확히 완성*할 때만 forbid(distinct class
  절대 억제 안 함). forbid 술어를 `(action, base)`로 plan-aware화.
- **[MEDIUM] coverage가 중복 class를 count만 맞으면 통과** (`_coverage_check_diverse`): `n==len`만 보고
  `_class_sig` 유일성 미검증 → class id만 다른 중복 class가 false-green(diversity 과대주장).
  → coverage가 각 class sig 재구성·중복 거부 + selfcheck 케이스(중복 class·n=2→거부).

조치(impl-stage, HIGH defer 불가): forbid를 completion-only plan-aware로 재설계(solve.py 술어 계약 (action,base))
+ coverage 중복 거부 + `_selfcheck_forbid`(공유 슬롯 distinct class 발견성) → 자체 리뷰 → codex Round 3.

## Self-Review Round 3 (codex R2 수정 후 자체 적대 리뷰)

R2 2 finding 수정:
- **[R2-HIGH] plan-level completion forbid**: `_make_forbid`를 `(action, base)` 술어로 — `base+[action]`이 발견
  class를 *정확히 완성*(슬롯수 동일 + 액션↔슬롯 bijection)할 때만 금지. `_matches_slot`/`_plan_completes_class`
  신설. solve.py forbid_pred 호출을 `(action, base)`로(4개 _propose 사이트 전부 base=누적 plan 전달, grep 확인).
  슬롯 1개 공유 distinct class 억제 제거.
- **[R2-MEDIUM] coverage 중복 class 거부**: `_coverage_check_diverse`가 저장 payload에서 `_class_sig` 재구성·
  중복 fail. `_class_sig`는 `.get("placement_axis")`로 방어화.
- **superset 거짓양성 후속 수정(자체 발견)**: completion-only forbid이 도입한 새 결함 — 솔버가 같은 해에 잉여
  액션(인벤토리 budget 소진 inert 4·5번째 blocker)을 덧붙인 superset을 별개 class로 과대보고(stage12 1→3 class
  오보 실측). → `_record`가 `analyze.minimize`(deletion-minimal)로 **기록 전 정규화** → superset이 원 class로
  collapse·dedup. stage12 재생성 = **1 class 복원**(search_capped=false 자연종료).
- **회귀 가드**: `_selfcheck_forbid`(완성=금지/공유슬롯 distinct=발견/미완성=비금지) + 중복 class selfcheck 케이스.

자체 적대 검토(HIGH 0):
- `_plan_completes_class` greedy bijection은 false-negative 가능(유효 배정 존재해도 greedy 실패) → **under-forbid**
  뿐 → solve가 같은 class 재발견해도 minimize+dedup이 `is_new=False`로 잡아 break(무한루프 없음, 출력 오류 없음).
  over-forbid(distinct 억제)는 구조상 불가(bijection True면 실제 완전 재구성). 정직 경계로 문서화.
- minimize는 1-minimal(order-dependent, analyze 기존·codex 승인 의미) — 각 보고 class는 잉여 없는 실 클리어 최소
  해라 거짓양성 아님. minimize 롤아웃은 extra_cap 미계상(bounded ≤len(plan)/class, 경미).
- byte-identical: solve.py forbid 경로는 forbid=None일 때 inert(selftest/golden frame 불변 확증). 신규 체크 전부
  fail-closed 강화.

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(회귀 0). → fix 커밋 후 codex Round 3.

## Round 3 (codex adversarial-review, `--base 6bef989` = revised 5b + R1 `cf1fd38` + R2 `9f31ab2`)

Verdict: **needs-attention** (HIGH×1 + MEDIUM×1). codex: "R2 수정이 원 forbid/minimize 버그를 좁혔으나 중복-class·인벤토리축 과소보고 경로 잔존."

- **[HIGH] same-cell 슬롯 순서로 중복 solution-class가 dedup·verify 통과** (`diverse.py` `_build_class`/`_class_sig`):
  `_build_class`가 cell_x 슬롯을 `(cell, ref_index)`로 정렬 → `_class_sig`가 결과 튜플을 *순서 의존*으로 처리.
  같은 셀 두 액션의 tiebreak `ref_index`(솔버 plan 순서, 4요소 동치 아님)가 뒤집히면 슬롯 튜플 역전 → sig 달라짐
  → `_record`가 새 class로 수용 + coverage도 같은 order-sensitive sig라 미거부. 잔존 false-positive.
  → `_class_sig`를 순서 무관 canonical(parts json화·정렬, 타입안전)로 + 역순 same-cell selfcheck.
- **[MEDIUM] 인벤토리 변형이 첫 class만 기록** (`diverse.py` 인벤토리 축): 전략 축은 forbid 반복 발견인데
  인벤토리 축은 변형당 `solve` 1회·`final_plan` 1개만 → 한 변형이 다수 distinct class 지원해도 greedy 첫 해만,
  search_capped 안 뜬 채 과소보고. → 인벤토리 축도 동일 completion-forbid 발견 루프(공유 classes·extra_cap 예산).

조치(impl-stage, HIGH defer 불가): `_class_sig` canonical 정렬 + 두 축 공유 `_discover` forbid 루프 + 역순 selfcheck
→ stage12 재생성 → 자체 리뷰 → codex Round 4.

## Self-Review Round 4 (codex R3 수정 후 자체 적대 리뷰)

R3 2 finding 수정:
- **[R3-HIGH] `_class_sig` canonical 순서 무관**: parts를 json 문자열로 직렬화 후 `sorted()` — 슬롯 순서(좌→우
  배치, same-cell tiebreak ref_index)는 4요소 동치 차원이 아니므로 multiset로 비교. 역순 same-cell이 같은 sig가
  되어 중복-class false-positive 제거. selfcheck ④(역순 same-cell→동일 sig) 추가.
- **[R3-MEDIUM] 두 축 공유 `_discover` forbid 루프**: 인벤토리 변형도 전략 축과 동일 completion-forbid 반복
  발견(공유 classes·extra_cap 예산) → 변형당 다수 distinct class 포착. 첫-해-only 과소보고 해소.

자체 적대 검토(HIGH 0):
- canonical 정렬은 순서만 제거(다른 multiset/region/role/timing은 여전히 분리) → false-merge 불가. json sort_keys
  결정론. region(list)·role band(list) 직렬화 안정.
- `_discover`: nonlocal extra_rollouts/capped, 안전망(미클리어 return·중복 return·빈플랜 return) 유지 → 무한루프
  없음·extra_cap bound. forbid는 전체 classes 대상이나 다른 multiset class는 슬롯수 불일치로 완성 불가=무해.
- 인벤토리 변형(blocker2/1)은 stage12 미클리어 → 0 class(정상). stage12 = 1 class 유지(search_capped=false).
- byte-identical: solve forbid=None inert(selftest frame 불변). diverse 게이트 fail-closed 강화 유지.

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(회귀 0). → fix 커밋 후 codex Round 4.

## Self-Review Round 5 (codex R4 수정 후 자체 적대 리뷰)

R4 2 finding 수정:
- **[R4-HIGH] 중복-minimized가 탐색 조기종료**: `_discover`가 is_new=False(superset collapse)에 **종료하지 않고**
  raw plan을 `dead_raw`에 넣어 forbid하며 계속(`_make_forbid`에 dead_raw 인자 — base+[action]이 dead_raw를 정확
  재구성 시 차단). 연속 중복 churn은 `DIVERSE_DRY_LIMIT(3)`로 자연 종료(첫 중복엔 종료 안 함). `seen_minimal`
  cheap pre-filter로 superset 재발화 시 비싼 sweep 생략. `_selfcheck_forbid`에 dead_raw 발견성 케이스 추가.
- **[R4-MEDIUM] extra_cap이 minimize/sweep 롤아웃 미계상**: `_charge()`가 solve 롤아웃 + `roll.count` 델타
  (minimize+`_sweep_placement`) 모두 합산(첫 class 발견 후). stage12가 search_capped=true로 정직 보고(이전엔
  sweep 미계상으로 false 위장 — MEDIUM 수정이 작동).

자체 적대 검토(HIGH 0):
- 종료성: extra_cap(예산) ∨ DIVERSE_DRY_LIMIT(연속중복) ∨ no-clear ∨ raw-repeat(seen_raw) 4중 바운드 → 무한루프
  불가. dead_raw/seen_raw/dry 모두 _discover-local(축마다 리셋).
- 정직성: search_capped=true는 "탐색 미소진"의 정직 표기(다른 class 잔존 가능). minimize 1-minimal order-dependent
  은 각 보고 class가 실 클리어 최소해라 거짓양성 아님. completion+dead_raw forbid은 distinct class 절대 미차단
  (greedy churn은 효율 손실일 뿐 — 정직 disclosed). `_charge` 중첩 nonlocal은 diverse_report 스코프로 정상 바인딩(실행 확증).
- byte-identical: solve forbid=None inert(selftest 불변). 게이트 fail-closed 강화 유지.
- 정직 경계: greedy 솔버 + sound forbid → superset churn은 본질적 한계(완전성 미주장, dry+cap 바운드). 1D y-band·
  axis_independent·grid 도메인 한정 등 기존 경계 유지.

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(회귀 0). → fix 커밋 후 codex Round 5.

## Self-Review Round 6 (codex R5 수정 후 자체 적대 리뷰)

R5 2 finding 수정:
- **[R5-HIGH1] 비연속 구역 거짓 병합**: `_sweep_placement`가 class region을 **c_star 포함 단일 연속 구역**으로
  설정(intervals=[containing], gaps=[]). 전체 스윕은 `swept_intervals`(정보용, non-authoritative)로 보존. 다른
  disjoint 구역은 별개 anchor의 class(솔버 별도 발견). `_class_sig`/`_matches_slot`는 intervals(=단일) 그대로
  사용해 자동 적용. coverage가 cell_x intervals 정확히 1개 강제. schema v1→v2 bump(intervals 의미 변경, stale 거부).
- **[R5-HIGH2] dry-limit 완전성 위장 제거**: 휴리스틱 DIVERSE_DRY_LIMIT 삭제. 종료 = no-clear(자연 소진,
  capped 미set) ∨ extra_cap(capped) ∨ seen_raw 반복(이제 capped=true로 정직 표기). churn은 extra_cap이 바운드.

자체 적대 검토(HIGH 0):
- 종료성: dead_raw+seen_raw(유한 distinct 플랜) + extra_cap 하드 바운드 → 무한루프 불가. dry 휴리스틱 제거로
  "완전성 위장" 경로 소멸 — 비-capped 종료는 forbid 하 no-clear(=자연 소진)뿐.
- 정직성: containing interval은 c_star가 항상 포함(reference anchor가 클리어)→in_region; None이면 provisional
  +coverage fail(fail-closed). disjoint 시 hi+1은 gap이라 boundary fail 단언 성립. swept_intervals는 informational
  (verify/identity 미사용)이라 거짓이어도 false-green 불가(authoritative=intervals만 리플레이 검증).
- byte-identical: solve 무변경(selftest frame 불변). 게이트 fail-closed 강화(len==1·schema v2) 유지.
- 정직 경계(잔존): greedy churn(extra_cap 바운드·capped 표기), axis_independent joint 미주장, 1D y-band,
  grid 도메인 한정. 모두 disclosed.

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(회귀 0). → fix 커밋 후 codex Round 6.

## Self-Review Round 7 (codex R6 수정 후 자체 적대 리뷰)

R6 2 finding 수정 + forbid 메커니즘 통합 재설계:
- **[R6-HIGH] coverage R5 불변식 강제**: `_coverage_check_diverse`가 cell_x 슬롯에 ① `fixed_cell==
  _placement_cell(ref[ref_index])` ② authoritative interval이 fixed_cell 포함 ③ sampled_points에 fixed_cell
  포함을 fail-closed 검증. 음성 selfcheck(fixed_cell 구역 밖) 추가.
- **[R6-MEDIUM] capped 커밋 거부**: coverage가 `search_capped:true` report를 거부(커밋/게이트 대상은 완전
  uncapped). + stage12를 **uncapped 재생성**(search_capped=false, extra_rollouts=48).
- **통합 재설계 — subset-forbid**: completion+dead_raw+dry-limit churn(R4~R6 반복 원인) 근절. `_make_forbid`를
  `base+[action]`이 발견 class를 **sub-multiset 포함**하면 금지로 단순화. **정리(soundness)**: 발견 class의
  minimal은 이미 클리어 → 다른 minimal 해는 그것을 strict-subset 포함 불가(잉여→비최소). ∴ subset-forbid은
  class 자신+superset(inert-padding)만 막고 distinct class는 절대 미차단. 효과: solve가 superset 못 만들고
  (즉시 forbid) class-미포함 plan만 찾거나 no-clear 자연 소진 → **uncapped 종료** + churn 소멸. dead_raw/dry-limit/
  `_plan_completes_class` 제거.

자체 적대 검토(HIGH 0):
- 소거 증명으로 subset-forbid은 distinct minimal class를 절대 미차단(over-forbid 0). greedy 포함판정 false-negative
  →under-forbid→solve가 superset 반환→minimize→class collapse→dedup→capped 종료(sound·honest, 무한루프 없음).
  false-positive 불가(매칭 성공=실제 포함).
- empty-class(베이스라인 클리어): _discover가 빈 플랜 기록 후 즉시 return(forbid 미구성). 인벤토리 축에선
  _plan_contains_class(빈 slots)=vacuous True로 전부 forbid=정확(유일 해=무도구). 엣지 정상.
- 종료성: distinct class(유한) ∨ no-clear(완전) ∨ extra_cap(capped) ∨ seen_raw/예상밖dedup(capped). 무한루프 불가.
- byte-identical: solve forbid=None inert(selftest 불변). 게이트 fail-closed 강화(fixed_cell 불변식·capped 거부·
  schema v2) 유지. stage12 uncapped라 capped-reject 게이트 통과.

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(회귀 0, stage12 uncapped). → fix 커밋 후 codex Round 7.

## Self-Review Round 8 (codex R7 수정 후 자체 적대 리뷰)

R7 2 finding 수정:
- **[R7-HIGH] greedy → Kuhn 이분매칭**: `_plan_contains_class`를 진짜 이분매칭(augmenting-path)으로 교체.
  슬롯들이 겹치는 액션 집합을 가질 때(A=[0,10]·B=[0,0]) greedy가 유효 매칭을 놓쳐 forbid를 누락하던 결함 제거.
  overlapping selfcheck(A↔5·B↔0) 추가 — greedy면 FAIL하는 케이스.
- **[R7-MEDIUM] sampled_points 존재 강제**: coverage가 cell_x 슬롯에 sampled_points=정수 리스트 + fixed_cell
  포함을 강제(누락/비-리스트 거부). selfcheck 2종(누락·비-리스트) 추가.

자체 적대 검토(HIGH 0):
- Kuhn: per-슬롯 visited로 재방문 차단 → 종료. 매칭 존재 iff saturate(완전·정확). 슬롯/액션 소수라 비용 무시.
  forbid 누락 제거 → churn 재발 방지(R6 subset-forbid 완전화).
- coverage sampled_points strictness는 fail-closed 강화뿐. good()/sampled-pass 픽스처는 정수 리스트+fixed_cell
  포함이라 통과(확증).
- stage12 재생성 동일(uncapped 1 class, 48롤) — Kuhn 변경이 비중첩 슬롯 결과 불변.
- byte-identical: solve forbid=None inert. 게이트 fail-closed 유지(fixed_cell·sampled_points·capped·schema v2).

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(회귀 0). → fix 커밋 후 codex Round 8.

## Self-Review Round 9 (codex R8 수정 후 자체 적대 리뷰)

R8 1 finding 수정(plus-형 forbid — soundness+completeness 동시):
- **[R8-HIGH] axis-independent joint over-block 제거**: `_matches_slot`의 interval-membership을 다중 cell_x
  슬롯 forbid에 쓰면 미검증 Cartesian joint를 '포함'으로 오판→distinct class 억제. 수정 = `_plan_contains_class`를
  **plus-형**으로: 검증된 same-class 변형 = reference(전 cell_x exact) ∪ {한 슬롯만 interval, 나머지 exact}.
  유연 슬롯 최대 1개(flex∈{None}∪cell_x). `_matches_slot(exact)` 파라미터 + `_saturates(flex)` Kuhn 분리.
- **soundness 증명**: 막히는 P는 검증 변형 V(클리어) 포함→P⊇V→잉여 redundant→P 최소화 시 V(=cls region)로
  collapse=distinct 아님. ∴ 단일슬롯 shift+superset만 막고 distinct(미검증 joint 포함) class 절대 미차단.
- **효과(실측)**: shift churn 제거 → stage12 **uncapped 자연소진**(search_capped=false, 48롤) 유지 + 미검증 joint는
  발견 허용(완전성). codex R6 capped-게이트와 양립(uncapped 통과).

자체 적대 검토(HIGH 0):
- plus-형은 검증 증거(1슬롯 스윕)에만 forbid 근거 → over-block 0(soundness 증명). joint 2+슬롯 동시이동=미검증=
  발견 허용 selfcheck(forbid_ov(blk2,[blk3])=False)로 확증.
- 단일 cell_x 슬롯 class: flex=그 슬롯 → interval membership(1D 스윕=joint 검증이라 안전). cls1 selfcheck 통과.
- Kuhn `_saturates`: per-슬롯 visited→종료, 매칭 존재 iff saturate. flex별 ≤(1+슬롯수) 시도(소수).
- byte-identical: solve forbid=None inert. 게이트 fail-closed(fixed_cell·sampled_points·capped·schema v2) 유지.

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(stage12 uncapped). → fix 커밋 후 codex Round 9.

## Self-Review Round 10 (codex R9 수정 후 자체 적대 리뷰)

R9 1 finding 수정(검증 joint duplicate → false-capped 제거):
- **[R9-HIGH] 검증된 joint duplicate를 정직 처리**: plus-형 forbid은 미검증 joint 변형을 (정당하게) 허용하는데,
  그게 클리어해 기존 class로 dedup되면 _discover가 is_new=False를 "예상밖→capped"로 오처리(false 미완)했다.
  수정 = `dead_exact`(정확 plan)에 넣고 forbid하며 **계속**(false-capped 제거). `_make_forbid`에 dead_exact 인자
  + `_plan_submultiset` 정확-superset 차단. uncapped 결과가 솔버 heuristic 운에 의존하던 불안정성 해소.
- **soundness**: joint duplicate도 클리어→그 정확 plan+superset만 막아도 distinct class 미차단(최소화 시 cls로
  collapse, R8 동일 증명). Cartesian 곱 전체가 아니라 발견된 정확 변형만 → soundness 불변.

자체 적대 검토(HIGH 0):
- 종료성: dead_exact(유한 정확 변형) + classes(유한) + extra_cap → 무한루프 불가. is_new=False→continue는
  dead_exact가 그 정확 plan 재발화를 막아 진행 보장(seen_raw는 잔여 안전망).
- 정직성: capped는 이제 extra_cap/seen_raw-반복만(검증 duplicate는 capped 아님). stage12 uncapped 안정(48롤).
- selfcheck: dead_exact 정확+superset 금지 / distinct 허용 3종 추가. plus-형 joint-허용·단일shift-금지 유지.
- byte-identical: solve forbid=None inert. 게이트 fail-closed 유지.

**자체 리뷰 verdict: clean (HIGH 0).** 게이트 7/7 그린(stage12 uncapped). → fix 커밋 후 codex Round 10.

## Round 10 (codex adversarial-review) — ✅ APPROVE (종결)

Verdict: **approve — "No material findings."** codex: "revised forbid는 검증된 plus-형 class 변형 + 정확
학습 joint duplicate/superset로 soundly scoped; `_discover`는 유한-예산 종료 + 검증 duplicate를 capped로
오표기 안 함; 커밋된 stage12 report는 uncapped 1 class; 게이트 selfcheck가 class-sig·forbid·capped·coverage
불변식을 커버."

**impl-stage 적대적 리뷰 종결**: codex R1(HIGH×2+M) → R2(HIGH+M) → R3(HIGH+M) → R4(HIGH+M) → R5(HIGH×2) →
R6(HIGH+M) → R7(HIGH+M) → R8(HIGH) → R9(HIGH) → **R10 approve**. 매 라운드 사이 자체 적대 리뷰 clean(HIGH 0).
커밋: cf1fd38·9f31ab2·770f558·4d02d10·2209c26·6100a75·cd98e7d·48e3109·c0f5ccd. 최종 게이트 7/7 그린(회귀 0,
stage12 uncapped 1 class).

핵심 진화(가능성-공간 다양-해 forbid 메커니즘): naive 4요소 completion → subset-forbid → **plus-형 forbid
(검증된 단일슬롯 변형만, 미검증 joint는 발견 허용) + dead_exact(검증 joint duplicate 정확 차단)** + Kuhn
이분매칭 + canonical class-sig + 단일연속 region(fixed_cell 불변식 coverage 강제) + capped 거부 게이트.

---

# S20 early-climber 체이닝 — impl-review (2026-06-25)

> 별개 변경(5d Ch2 — model.py early-chain 휴리스틱). base=`a560995`(5d① 부모), 초기 커밋 `50e8ccb`.
> bash 경로 codex(adversarial-review --base). 트레일: 이 절.

## Round 1 (codex, base=a560995, 커밋 50e8ccb diff) — needs-attention

Verdict: needs-attention. No-ship: the heuristic can now hide required structural candidates after the
first early arm, and the added gate does not actually exercise the changed search path.

- [HIGH] Early-arm boost can starve required non-early actions (model.py:351-375)
  Once any same-skill early arm is present in the closure plan, every remaining spawn_index candidate gets
  weight 210+ and the globally sorted list is truncated with `cands[:max_n]`. That can fill the candidate cap
  with early climber actions before bridge/reverse/cross candidates are even returned. Failure mode: a stage
  that needs structure -> early arm -> another bridge/blocker before more early arms can now stall or look
  ahead only through early candidates, despite viable structural moves still existing in
  `diag["reverse_targets"]`. The STATUS note documents this class, but the code ships the boost globally once
  the gate flips.
  Recommendation: Keep the exclude waiver separate from ranking, and scope the boost so non-early families
  retain slots (reserve per family, boost early only after structural exhausted, or lower/interleave).

- [medium] Stage20 gate replays the fixture but never tests solver rediscovery (run_plan.py:39)
  Adding stage20 to EXPECTED_SOLVE_STAGES only proves the file exists. selftest calls run_plan_file (replays
  stored actions); it never invokes solve.solve()/model.propose(). A regression that passes speculative base2,
  removes the closure-plan gate, changes boost ordering, or breaks deterministic rediscovery would still pass.
  Recommendation: Add a solver-level no-save regression for stage20 (and representative existing stages) that
  runs discovery and asserts cleared + stable action signatures/order.

### Fixes (2-fix, 자체 적대 리뷰 clean 후)
- HIGH → `model.propose` 구조-후보 보존: `early_active`(early_armed 발화)면 정렬 후 `cands[:max_n]` 대신
  **최상위 구조 후보(trigger=ant_reaches_x) 1개를 절단에서 항상 선반영**. early_active=False(기존 전 스테이지)면
  미적용 → byte-identical. S20 30→31롤(보존 1칸), plan 불변. 한계(정직): 보존은 *최상위* 구조만 보장(임의
  필요 구조는 반복 라운드+LA2 frontier로 수렴 — 완전성 주장 아님, 휴리스틱).
- MEDIUM → `try_solve.py rediscover-verify` 신규 + frontmatter `verify` 편입: up-루프 대표 S4(early-single)/
  S13(carry-chain)/S20(early-chain)을 `solve.solve(save=False)` 재발견 → cleared + 액션 시그니처(순서) ==
  커밋된 solve.json. fail-closed(없음/미클리어/불일치=FAIL, save=False 무부작용).
- 자체 적대 리뷰(2-fix) clean(HIGH 0): 보존 `is not` 식별자 제외·max_n=1 경계·결정론·rediscover stats 갱신
  경로(error path=cleared False=FAIL) 검토 통과.
- 전체 게이트 그린·EXIT 0: selftest 17 + analyze 4 + diverse-verify 4 + **rediscover-verify(S4 1/1·S13 6/6·
  S20 7/7 시그니처 일치)**. 회귀 0.

## Round 2 (codex, base=a560995, 커밋 8aab1f1까지) — needs-attention

Verdict: needs-attention. No-ship: the HIGH starvation class is only narrowed, not closed; rediscover
coverage does not exercise the remaining failure mode.

- [high] Single preserved structure slot can be monopolized by the same failed ceiling candidate
  (model.py:314-388). The preservation gate only forces the first `ant_reaches_x` candidate back. But
  structural candidates with `ceil=True` are exempt from `exclude`, so a high-ranked ceiling candidate that
  was already evaluated and not adopted can be returned as `top_struct` again on later rounds. With
  early_active=True, remaining slots are dominated by boosted early-arm candidates, so lower-ranked
  bridge/blocker/cross candidates can still be starved. Original HIGH not fully resolved — reduced to 'top
  structural only'.
  Recommendation: reserve multiple structural slots, suppress a preserved candidate after it fails for the
  same closure plan, or preserve the best not-yet-evaluated structural candidates.

- [medium] Rediscover gate does not cover the preservation failure it was added to guard
  (try_solve.py:196-219). S4/S13/S20 are not negative/mixed cases where early-active plan has multiple
  competing structural candidates and the first preserved structural candidate is non-improving. Gate can
  pass while the starvation path persists.
  Recommendation: add a rediscover regression that forces early_active plus multiple structural candidates
  (higher-ranked non-improving preserved + lower-ranked required).

### Fixes (R2 2-fix)
- HIGH → `model.propose` 보존 대상을 **untried(label∉exclude) 최상위 구조**로 한정: 시도·실패한 구조(ceiling-
  exempt 재제안 포함)는 tried라 보존서 제외 → fresh 구조가 슬롯 획득(독점 차단). S20 거동 불변(31롤, solve.json
  byte-identical). 한계(정직): 1 슬롯이나 매 라운드 *fresh* 구조 보장 + LA2 frontier → 필요 구조 수렴(완전성 아님).
- MEDIUM → `model._selfcheck_preserve()` 단위 검증(엔진 불요) + rediscover-verify ① 선두 편입: 구조 A(천장·
  고가중)/B(저가중) + early 활성에서 A untried→보존 A, A tried→보존 B(독점 차단) 직접 단언. **prove-it**: R1
  동작으로 되돌리면 FAIL(A 반환), R2면 PASS = 회귀 박제(vacuous 아님).
- 자체 적대 리뷰(R2) clean(HIGH 0). 전체 게이트 그린·EXIT 0(preserve-selfcheck + rediscover S4/S13/S20 +
  selftest 17 + analyze 4 + diverse 4).

## Round 3 (codex, base=a560995, 커밋 6ac97c1까지) — needs-attention

Verdict: needs-attention. No-ship: R2 prevents one tried ceiling candidate from monopolizing the
preservation slot, but it also permanently excludes retry-eligible structure candidates by global label,
leaving a real starvation path after the plan context changes.

- [high] Preservation skips retry-eligible structure candidates after context changes (model.py:388-393)
  `top_struct` only preserves structure candidates whose label is not in the global `exclude` set. That
  conflicts with the reverse-candidate logic that intentionally re-proposes ceiling candidates after they
  were tried, because a blocker can fail alone and become useful only after another action changes the plan
  context. In an early-chain round, a ceiling structure tried under an earlier base is re-created by propose
  but line 390 makes it ineligible for the preservation slot, so it can stay outside the truncated set
  indefinitely. Closes tried-monopoly but can still starve a necessary structure in structure→early→structure.
  Recommendation: Do not key preservation solely on global label freshness. Track tried status by plan/base
  signature for retry-exempt structure candidates, or include re-proposed candidates while rotating past
  exact same-base failures. Add a selfcheck where A is tried under one base, an early action is added, and A
  must still receive a preservation slot under the new base.

### Fix (R3 round-robin)
- HIGH → `model.propose` 보존 대상을 **least-attempted 라운드-로빈**으로: live 구조 후보(재제안 천장 포함)
  중 롤아웃 시도 횟수(`attempts` label→count)가 최소인 것을 보존(동률=가중 desc). 보존·실패하면 attempts↑ →
  다음 라운드 다른 구조 → 모든 live 구조가 유한 라운드 내 보존(영구 starvation 불가능, 천장 retry-eligible은
  rotating past로 exact 반복만 회피·배제 안 함 = R3 모순 해소). `solve.attempts`가 eval_cands서 누적 → propose
  전달. attempts=None 기본=R1(타 호출자). S20 거동 불변(31롤, solve.json byte-identical). early_active=False면 미적용.
- selfcheck 라운드-로빈 갱신 + prove-it(R1 top-1 동작이면 (2) A 반환 FAIL). 자체 리뷰 clean(HIGH 0).
- 전체 게이트 그린·EXIT 0(preserve round-robin + rediscover S4/S13/S20 + selftest 17 + analyze 4 + diverse 4).

## Round 4 (codex, base=a560995, 커밋 0b7d04e까지) — needs-attention → 사용자 결정 carry-mirror 단순화

Verdict: needs-attention. No-ship: R3 reduces pure top-structure starvation, but retry accounting is still
global by label, so context-dependent structure retries can be delayed past the finite rollout budget.

- [high] Retry-eligible structure rotation is not scoped to the plan context (model.py:394-395). The
  preservation selector uses `attempts[label]` accumulated globally, so a structure that failed under an
  earlier base keeps its penalty after the plan context changes. Recommendation: track attempts by base/closure
  plan signature, or suppress only exact same-base failures while treating changed-plan retries as fresh.

### 분석 → 근본 충돌 (사용자 에스컬레이션)
R1(top-1 보존)→독점 / R2(untried만)→retry-eligible 배제 / R3(global 라운드-로빈)→cross-base 페널티.
R4 권장 base-scoped는 **메인루프가 매 라운드 base 변경**이라 같은 구조가 매번 fresh = R2 독점 재발 →
**global↔base 직접 충돌**, 단순 카운터로 동시 만족 불가("의미있는 맥락 변화" semantic 판단 필요). 이 starvation은
**latent**(현 캠페인 structure→early→structure 없음; 선재 carry-chain도 carry>구조 동일 속성, 미flag).

### 결정 = carry-mirror 단순화 (사용자 AskUserQuestion 2026-06-25)
보존 메커니즘 전부 폐기(R1 reserve / R2 untried / R3 round-robin / attempts / `_selfcheck_preserve` /
`early_active`). early-armed 가중 = `max(carry_base,40)+cnt+(ant_n-si)` = **carry 프로파일 바로 위** →
early-chain이 **검증된 carry-chain과 동형 가중 프로파일**, 구조 후보 관계도 carry-chain과 동일(새 starvation
클래스 없음 = 공유 선재 속성). rediscover-verify 엔진 재발견(S4/S13/S20)은 유지(R1 MEDIUM 가드).
- 결과: S20 SOLVED 30롤(31→30 복귀), plan 불변. 회귀 0(S4/S13 byte-identical, early_armed=False면 byte-identical).
  전체 게이트 그린·EXIT 0(selftest 17·analyze 4·diverse 4·rediscover S4/S13/S20). 자체 리뷰 clean.

## Round 5 (codex, base=a560995, carry-mirror 최종) — needs-attention → 사용자 사전수용 latent로 종결

Verdict: needs-attention (예상된 결과). codex는 diff만 보므로 carry-mirror가 early-above-structural을
유지하는 한 구조 starvation을 계속 flag한다.

- [high] Early-chain boost can still starve required structural candidates behind the candidate cap
  (model.py:340-393). After a same-skill early arm is in plan, remaining spawn_index early candidates are
  exclude-exempt + `early_w_base+(ant_n-si)`, then globally sorted+truncated `cands[:max_n]`. structure→
  early→structure stage can stall or spend budget on no-op early arms while a required bridge/blocker is
  never evaluated. Carry-mirror rationale is an inference about shared latent properties; code makes no
  slot/interleave guarantee.
- [medium] Rediscovery gate does not exercise the removed preservation failure mode (try_solve.py:201-220).

### 종결: 사용자 사전수용 latent 한계 (ACCEPTED, 정책 예외 — 사용자 결정 override)
이 HIGH는 **carry-mirror 결정 시 사용자가 AskUserQuestion에서 명시적으로 사전 수용**한 속성이다(선택지 설명:
"구조 starvation은 carry와 공유하는 선재 속성(새 회귀 아님)", "codex는 여전히 flag할 수 있으나 근거는 carry 동형").
근거:
1. **검증된 carry-chain이 이미 동일 속성**(carry _w 40 > 구조 _w ~12 → structure-after-carry도 동일 starvation).
   codex는 carry 코드가 diff 밖이라 미flag일 뿐, 새로 도입한 회귀가 아니다.
2. **latent**: structure→early→structure(또는 →carry→structure) 다단 레벨은 **현 캠페인에 존재하지 않음**.
   S20는 discovery 단계서 구조(bridge×2) 완료 *후* early-chain이라 구조 경쟁이 발생하지 않는다(실측 30롤 클리어).
3. **완전 해소는 카운터 범위 밖**(R1→R4 입증: global↔base-scoped 직접 충돌, "의미있는 맥락 변화" semantic 판단
   필요). 사용자가 그 복잡도(R1~R3 보존 tar pit)를 폐기하고 carry-parity 단순성을 선택.
- MEDIUM(rediscover 미커버): preservation 규칙 자체를 폐기했으므로 "보존 실패모드" 회귀는 무의미(테스트할
  보존 규칙 없음). rediscover-verify는 carry-mirror 가중·early gate·결정론 회귀를 가드하는 본래 목적 유지.
- **재진입 조건**: 실제 structure→early→structure 레벨이 캠페인에 등장하면(현재 없음) preservation/interleave를
  semantic 맥락-인지로 재설계해 재개. 그 전엔 carry-chain과 동일 취급.

**상태**: S20 SOLVED·게이트 그린·회귀 0. codex 5R(R1~R3 보존 진화 → R4 근본충돌 에스컬레이션 → R5 carry-mirror
확인). 사용자 결정으로 review 루프 종결.

## 5d② sand_mound (cell-up) routing — impl-review (2026-06-26)

> plan-stage(3-round, R3 HIGH→사용자 "반영 후 구현 진입") 후 구현. base=plan-stage 종결 시점 워킹트리.
> 엔진/PlanRunner/게임 무변경 — `tools/solver/`(model.py·solve.py·try_solve.py) + `scripts/run_plan.py`
> EXPECTED 1줄 + 신규 `data/solutions/stage19.solve.json`. 하니스 `--fixed-fps`([[godot-binary-location]]).

**구현 산물:**
- **`model.diagnose` 신규 `wall_targets`**(`_wall_targets`): 벽-반전 검출 — d=진입 세그먼트 방향(트레이스에
  ant.direction 없어 명시 정의), soundness=전방 same-row solid, 목표-위 게이트, backpath≥6(reverse depth-4 cap
  비재사용, R3-M1). 목표(candy) 근접 desc 결정론 정렬.
- **`model.propose` 신규 ③ SIGN cell-up 분기**(meta.target==cell && routing==up): 후보 column-sweep off=0..5,
  **off 큰 쪽 선호**(`+off`·tgt_w*8) — 벽은 개미↔목표 사이라 ladder1을 벽서 멀리 둬야 ladder2 공간(T2/T3) 확보.
  T1 같은-col exclude(`_cellup_cols`, speculative base 기준). 좌·우 벽 중복 셀 dedup. ①②와 routing 키로 격리.
- **`solve._propose` plumbing**(R3-H1): `model.propose(..., cellup_base=base)` — cell-up 같은-col 회피가 LA2의
  speculative base(base2)를 보도록(early-chain closure `plan`과 직교). filter는 propose-레벨, 배선은 1줄 passthrough.
- **`model._selfcheck_wall_targets()`**(fail-closed, 엔진 불요): ⓐ right ⓑ left ⓒ two-wall valley(목표근접 정렬)
  ⓓ 허공 반전 미검출 ⓔ 목표-아래 미검출 + **R3-M1**(우측벽 backpath≥6·propose off=5 (10,14) emit) + **R3-H1**
  (speculative base col10 → 같은-col 배제). rediscover-verify 선두 편입.
- **stage19 게이트 편입**: `stage19.solve.json`(witness `[(10,14),(11,10)]` saved=5/5 frame1586 rollouts8) +
  selftest EXPECTED + rediscover-verify(REDISCOVER_TARGETS[19]).

**S19 하드 acceptance = 통과**: `solve.solve(19)` → **saved=5/5, rollouts=8**, 자동 발견(off-preference로 greedy가
ladder1=(10,14)[off=5] 채택 → 다음 라운드 ladder2=(11,10), 다른-col·우향). 결정론 재현(재탐색 byte-identical).

**전체 게이트 그린·EXIT 0**: Determinism×2 + SkillMetadataDrift + harness-test + selftest **18 plans**(stage19
편입, 기존 byte-identical) + analyze --verify(4) + diverse-verify(4) + **`_selfcheck_wall_targets` PASS** +
rediscover-verify(4/13/**19**/20). **inert 불변식 확인**: up-cell 스킬 없는 기존 스테이지 solve.json **git 무변경**
(stage19만 신규), rediscover 4/13/20 시그니처 byte-identical.

**자체 적대 리뷰 — clean(HIGH 0, 2-fix):**
- [HIGH] R3-H1 LA2 same-col regression이 selfcheck에 부재(propose 필터=LA2 메커니즘인데 fixture 누락) → **수정**:
  selfcheck에 speculative-base(=LA2 base2) col 배제 케이스 추가.
- [MEDIUM] 좌·우 벽이 같은 backpath 셀(valley off=5=col10)을 양쪽서 중복 emit(중복 롤아웃) → **수정**: 스킬별
  `seen_cells` dedup(목표근접 우선 가중 유지).
- **정직 경계(HIGH 아님, 문서화)**: ① R3-H1 배선(solve.py cellup_base=base)은 inspection 검증·propose-필터
  fixture — solve._propose closure 비export라 full LA2-driven 통합 테스트는 미추가(1줄 passthrough, 저위험).
  ② off-preference는 ladder 높이가 col-불변이고 backpath가 동일 접근면이라 sound — 비연속 플랫폼 backpath에선
  불완전 가능하나 엔진 verdict가 거름(S5 등 single-gap stretch 스코프 밖). ③ wall_targets 목표는 any()-picked
  근사(per-frame 목표전환 미모델, reverse_targets 동급). ④ break/down/jump cell 디바이스 미커버(스코프 밖).

**⏳ 다음 = codex impl-review**(사용자 슬래시/bash 트리거 — model-invocation 불가). clean 후 커밋.

### codex impl-review R1 (needs-attention, HIGH×1) → 1-fix
> base=구현 워킹트리 diff. codex session(bash 경로, [[codex-adversarial-review-invocation]]).

- **[HIGH] wall_targets가 sample별 목표가 아닌 트레이스 전체 단일 목표 사용** (model.py `_wall_targets`):
  `picked_any = any(s[3]==1 for s in ss)`를 개미당 1회 계산해 모든 반전에 적용. 트레이스가 픽업 전(접근)+픽업
  후(운반) 샘플을 같이 담을 때, 개미가 *나중에* 픽업하면 *이른* 접근 벽이 candy 아닌 home 기준 판정 → home이
  그 벽 위가 아니면 `goal[1]>=cy`로 **유효 상승 벽을 조용히 누락**. 정렬도 candy 고정. selfcheck가 `_tr`에서
  has_candy=0 하드코딩이라 미포착. 권고: 반전 *샘플별* 목표(`home if ss[i][3]==1 else candy`)로 게이트·정렬.
- **수정**: `_wall_targets` 목표 계산을 루프 *안*으로 — `goal = _goal_cell(ss[i][3]==1, layout)`(phase별). 정렬 gx도
  target별 `agg[k]["gx"]`(목표 col)로. **selfcheck ⓕ 추가**: has_candy **0→1 플립** 트레이스(픽업 전 우측 벽 반전,
  그 후 픽업, home 아래) → per-sample이면 (8,10) 검출 / any()-bug면 home(아래) 기준 reject로 누락 = FAIL.
  **falsifiable 확인**(vacuous 아님). S19 회귀 0(픽업 없어 candy 일관, byte-identical SOLVED 5/5 rollouts8).
- **자체 적대 리뷰 clean(HIGH 0)**: per-sample 목표 결정론(gx target별 저장)·gate/sort 일관·S19 불변 검토. 전체
  게이트 그린·EXIT 0(selftest18+analyze4+diverse4+selfcheck ⓐ-ⓕ+rediscover4/13/19/20). **⏳ codex 재리뷰.**

### codex impl-review R2 (needs-attention, HIGH×1 + MEDIUM×1) → 2-fix
- **[HIGH] phase별 target이 구 wall 키로 병합** (model.py `_wall_targets`): per-sample 목표는 골랐으나 `(col,row,
  d_in)`로 병합 → 같은 벽이 픽업 전/후 둘 다면 나중 것이 count만 증가·자기 gx/backpath 상실 → return-phase 벽이
  stale approach 데이터로 정렬/스윕. ⓕ는 검출만 단언. → **수정**: 키에 **phase(picked) 포함** `(cx,cy,d_in,picked)`
  → phase별 별도 레코드(각자 gx/backpath). selfcheck **ⓖ**(같은 벽 pre/post-pick → phase별 2 target, 구코드면 1).
- **[MEDIUM] backpath가 비연속 stale 셀 우선** (model.py `_wall_targets`): 인접성 체크 없이 grounded 6셀 수집 →
  루프/계단의 옛 셀이 off-preference로 실제 접근 셀을 밀어내 cap 소진. → **수정**: **연속 접근 세그먼트** — 직전
  수용 셀과 Chebyshev>1(비인접)이면 중단. selfcheck **ⓗ**(far-jump (0,10) 거쳐온 trace → backpath=(5,10)(4,10)
  (3,10)만, propose가 (0,10) 미선택).
- **자체 적대 리뷰 clean(HIGH 0)**: phase-키 결정론(tie-break k[3] 추가)·연속 backpath 종단 결정론·S19 byte-identical
  (평지 전부 인접·픽업 없어 candy 일관, SOLVED 5/5 rollouts8). ⓖ/ⓗ falsifiable(구 병합/비연속이면 FAIL). 전체
  게이트 그린·EXIT 0(selftest18+analyze4+diverse4+selfcheck **ⓐ-ⓗ**+rediscover4/13/19/20). **⏳ codex 재리뷰.**

### codex impl-review R3 = **approve** (no material findings) — impl-stage 종결
> "Phase-key aggregation is deterministic, the backpath continuity rule is bounded and regression-checked, and the
> new S19 fixture is wired into selftest/rediscover gates." codex 3R(R1 per-sample 목표 → R2 phase-키+연속 backpath
> → R3 approve) + 자체리뷰 3R 사이 clean. **5d② sand_mound cell-up routing impl-stage 종결, 커밋 대기.**

---

## 5e 구현 (리스크-구동 다중-도구 분기, S22 정준) — 2026-06-27

> plan §"5e 계약"(R3 approve) 구현. D1(목표-위 fall-edge cell-up) + D2(intervention-class evaluated-prefix
> burial 해소). 엔진/PlanRunner/게임 무변경 — `tools/solver/model.py`(diagnose/propose) + `scripts/run_plan.py`
> (EXPECTED) + `tools/solver/try_solve.py`(rediscover[22]) + `data/solutions/stage22.solve.json`.

### 산출물
- **D1** (`model.diagnose`): fall_edges에 **per-sample `goal_above`** 추가(`edge_goal_above`, OR 집계 —
  cur[3]==1=운반→home / 아니면 candy가 셀보다 위인가). reverse_targets 항목에 `goal_above` 필드. ①(reverse/
  safe_fall/cross) 후보는 이 필드 **무시**(낙하 차단=목표 방향 무관) → byte-identical 보존.
- **D1** (`model.propose` ③): cell-up 루프가 `wall_targets` + **목표-위 fall-edge**(`reverse_targets` 중
  `goal_above`)를 함께 순회. wall(전방 solid)·fall(전방 비-solid) **배타**라 셀 중복 없음(`seen_cells` 보장). N:
  wall=6, fall=4(reverse backpath cap). 후보에 `_class="up_cell"`·`_off`·`_risk` 부여.
- **D2** (`model._class_prefix_protect`, propose 말미 호출): `up_cell`이 *다른 class*(carry-arm `up_armed`,
  bridge `cross`…)와 경쟁할 때, _w(≈10)가 carry-arm(_w≈220)에 눌려 top-`max_n` 절단에 밀려 **롤아웃조차 안 되던**
  cross-routing burial 해소 — up_cell 프리픽스(off 전부)를 절단 밖이면 **추가 보호**. 3중 inert 가드: `up_cell∉
  classes` OR `len(classes)≤1`(S19 단일) OR `len(cands)≤max_n`(절단 없음)이면 보호 무발동=byte-identical. ①②③
  후보에 `_class` 부여(action/label/_w 불변, solve 미사용 → 누출 0).
- **selfcheck 확장** (`_selfcheck_wall_targets`): ⓘ 목표-위 fall-edge → cell-up emit + wall_targets 누출 0(soundness)
  / ⓙ 목표-아래 fall-edge → 미emit / **D2 witness-rolled prove-it**(carry-arm _w220 독점 합성 cands에서 보호가
  witness off=2 포함 + naive 절단엔 up_cell 0개=burial 재현 [vacuous 아님] + 단일 up_cell 보호 항등 [inert]).
- **게이트 편입**: `EXPECTED_SOLVE_STAGES`에 22 + `REDISCOVER_TARGETS[22]=40` + `stage22.solve.json` 신규.

### 하드 게이트 = S22 100% (plan acceptance)
- `solve.solve(22)` **SOLVED 7/7**, plan=`[bridge max_x, sand_mound@(10,6)]`, rollouts=16. de-risk witness
  (10,6)을 burial 없이 자동 발견 — 롤8~13 carry-arm(slideR/L) 미클리어 → **D2 보호**로 cell-up off0(8,6)→off1
  (9,6)→**off2(10,6) 클리어**. (8/9/11,6=0/7, off2만 유효 = de-risk 입증과 일치.)
- **witness-rolled fixture** = rediscover[22](solve.solve 재발견 → 액션 시그니처 `[bridge, sand_mound(10,6)]`
  일치, cleared) + selfcheck D2 prove-it(보호 메커니즘 단위 박제). "후보 풀 존재"가 아니라 "실제 발견·평가" 단언.

### 회귀 0 (byte-identical, 실측 입증)
- **재발견 byte-identical**: S19(8롤, (10,14)/(11,10))·S13(26롤)·S14(40롤)·S20(31롤) — solve.json git diff **0**.
  D1 fall-edge가 S19에 누출 0(단일 up_cell → D2 보호 무발동), D2가 up_cell 없는 multi-class(S13/14/20)에 무영향.
- **전체 verify 게이트 8/8 그린·EXIT 0**: Determinism×2(962f) + SkillMetadataDrift(11) + harness-test(PASS+exit0)
  + selftest **19 plans**(golden5+solve14, stage22 saved=7, frame byte-identical s12=2385·s13=2719·s14=4624) +
  analyze --verify(4 analysis 272체크) + diverse-verify(4 diverse 145체크) + rediscover-verify(5: 4/13/19/20/22).

### Self-Review Round 1 = clean (HIGH 0)
- **byte-identical 경로**: ① 후보 goal_above 무시·_class solve 미사용 → 누출 0(S13/14/19/20 git diff 0 실측).
- **D2 발동 3중 가드**: 단일 up_cell 항등 / up_cell 없는 multi-class extra=[] / 절단 없으면 무발동. 결정론 extra
  정렬 (_risk, _off) 완전 사전식.
- **soundness**: fall-edge·wall 배타 + seen_cells 중복 차단(selfcheck ⓘ 누출 0 박제).
- **정직 경계(문서화)**: `edge_goal_above` OR 집계(어느 phase든 목표-위면 True)이고 `edge_back`은 첫 발견 동선 —
  backpath는 phase-무관 grounded 타일이라 일관, 같은 edge 양-phase 시 over-emit 가능(무해, cell-up=영구 사다리).
  D2 보호도 "전역 multi-class" 발동이라 독립 리스크의 up_cell over-eval 가능(정확성 무해·결정론 유지·cap 제어).
- **⏳ codex impl-review 대기**(사용자 트리거 — model-invocation 불가).

### codex impl-review R1 (커밋 be78bb5 diff, --base HEAD~1) = needs-attention (HIGH×1) → fix
- **[HIGH] Fall-edge goal aggregation can reuse a stale phase backpath** (`model.py` diagnose): `goal_above`는
  `(col,row,dir)`로 OR 집계인데 `edge_back`은 그 키 첫 발견 동선만 기록 → 같은 fall edge를 **픽업 전**(목표-아래)과
  **운반 중**(목표-위) 통과하면, 나중 운반 샘플이 `goal_above`를 true로 플립하지만 emit된 backpath는 첫(픽업 전)
  동선이라 cell-up이 *엉뚱한 route*에 사다리를 놓고 실제 사다리가 필요한 운반 귀환 backpath를 누락한다. `_wall_targets`가
  phase 키로 명시 회피한 stale phase-merging 클래스의 재도입. (S22는 운반만 (8,6)을 지나가 우연히 일관했으나 일반 결함.)
- **수정**(`model.py`): cell-up 전용 backpath를 **목표-위를 만족한 샘플**서 따로 수집(`edge_back_above`, 첫 목표-위
  통과). reverse_targets에 `backpath_above` 필드 + propose ③ fall은 `backpath_above` 사용(① reverse는 종전 `backpath`
  = byte-identical). backpath 수집을 `_grounded_backpath` 헬퍼로 통일(기존 인라인과 동일 로직). **selfcheck ⓚ 추가**:
  같은 fall edge를 픽업 전(goal_above=false, 긴 동선 A)·운반(true, 짧은 동선 B) 통과 → cell-up이 운반 B 동선 셀만
  emit, A 전용 셀 (10,6)/(11,6) 미emit(prove-it: backpath_above 없으면 stale A 사용해 (10,6) emit = FAIL, falsifiable).
- **Self-Review Round 2 = clean (HIGH 0)**: backpath_above 결정론(ant_ids/sample 순 첫 목표-위)·`goal_above⟹
  backpath_above 존재`·byte-identical(① backpath 불변·헬퍼 동일 로직·backpath_above는 ③ fall만)·codex 시나리오 ⓚ
  해소 검토. 정직 경계: 픽업전·운반 *둘 다* 목표-위면 첫 동선 사용(둘 다 목표-위라 사다리 유효, codex 핵심 false→true 해소).
- **게이트 8/8 그린·EXIT 0(수정 후)**: Determinism×2(962f)+SkillMetadataDrift(11)+harness-test+selftest **19**(stage22
  saved=7, frame byte-identical s12=2385·s13=2719·s14=4624)+analyze4(272체크)+diverse4(145체크)+selfcheck ⓐ-ⓚ+
  rediscover **5**(4/13/19/20/22 cleared 시그니처 일치). **회귀 0(byte-identical)**: S13/14/19/20/22 재발견 solve.json
  git diff 0(backpath_above 도입이 S22 witness off2·기존 plan 불변). **⏳ codex 재리뷰.**
