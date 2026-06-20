# Phase 3a impl 적대적 리뷰 — analyze.py (최소화 + 윈도우 측정)

대상: `tools/solver/analyze.py`(신규) + `data/solutions/stage{11,12,13,14}.analysis.json`(신규) +
`phases/solver/auto-solver-plan.md`(verify 편입) + `codex-worklog/solver/STATUS.md`.
PlanRunner 가산①②는 선커밋 `02c2d43`(이 phase 범위 밖). 엔진/PlanRunner/테스트씬 **무변경**.

게이트(verify) 전부 그린 + analyze.py --verify 4스테이지 58체크 그린 + 회귀 0.

---

## Self-Review Round 1 (자체 적대, clean)

엔진=진실(D4)·결정론·fail-closed·plan v3 충실성·hypothetical 위험까지 가혹 검토.

### 검토한 위험과 결론
- **measure↔verify 결정론 정합**: 측정·검증이 `sweep_time_plan`(공유) + 저장된 `minimal_plan`/`sweep_target`로
  동일 plan JSON 재구성 → 결정론 헤드리스가 byte-identical verdict. 실증: 58 verify 경계체크 전부 정확
  (interval 내부=clear / 양 끝 밖=fail / 1-minimal clear). ✓ 위험 없음.
- **sweep_target에서 y_min/y_max/dir 드롭**: `_select_ant`가 y-band/dir를 spawn_index 매칭 *전에* 거르므로,
  핀한 개미가 스윕 프레임에 밴드 밖이면 잘못 배제됨 → 드롭이 정답. `state`만 보존(walker 기본이면 carrying
  미선택, R2-H2). 실증: S13/S14 carry climber 윈도우가 정상 측정됨. ✓.
- **incomplete → 게이트 FAIL 전파 무결**: cap 소진 시 `test`가 None 반환하며 `incomplete[0]=True`, expand/
  refine가 None을 만나면 incomplete. coverage 선검증이 incomplete 필수 액션을 FAIL 처리(미완을 통과로 위장
  금지). 빈 intervals(비-incomplete)도 FAIL. baseline_pin 미클리어도 incomplete=True. ✓ silent pass 경로 없음.
- **fail-closed**: ① 빈 stage_ids → verify FAIL(빈 통과 위장 차단) ② `_selfcheck_gate`가 6 변형(count/
  dup/range/label/incomplete/빈intervals)을 모두 거부하는지 자가검증(검출기 약화 시 verify 선FAIL) ③ coverage
  index/label 1:1 + 누락 검출. 단위 모킹 + 실측 통과. ✓.
- **위치 윈도우 포화 정직성**: ge/le 단방향 임계는 무한 스윕 시 "즉시 발화"로 포화 → 도메인을 trace 도달
  x로 제한 + `saturated_lo/hi` 플래그. verify 게이트 비포함(plan: 위치는 "보조", 시간이 1급). 오해성 거대
  width(100000) 제거 실증. ✓.
- **gap 검출**: `_reconstruct_runs` 토글 로직 — 연속(intervals=[[lo,hi]],gaps=[]) + 비연속(2 interval +
  1 gap, frame 정밀) 단위 검증. 현 S11~S14는 전부 단일 연속(gap 0). ✓.
- **prove_cardinality(opt-in)**: 기본 off·verify 미포함. 단위로 양분기(소집합 클리어→1-minimal+보고 /
  무→cardinality-minimal) 검증. 커밋 산출물은 `minimal_kind:"1-minimal"`(정직, R3-H1: 기본 게이트는
  1-minimal만 요구). ✓.
- **회귀 0**: analyze.py = 신규 툴, 엔진/PlanRunner/씬 무변경. 기존 verify 5종 + selftest 9/9 byte-identical
  (s12=2385/s13=2719/s14=4624). ✓.

### 잔존(LOW, 비차단)
- `exec_one` 일시오류 1회 재시도 — 양쪽 다 error면 비클리어(거짓 경계 가능). ~1000 롤아웃 무오류 실측, 위험 낮음.
- prove_cardinality 실엔진 미실측(opt-in·미게이트). 로직 단위 검증.

**Self-Review Round 1 결론: CRITICAL/HIGH 0 → clean. codex 적대 리뷰 진행.**

---

## Round 1 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×2

`node codex-companion.mjs adversarial-review --wait --base f3f0a10`. verdict=needs-attention.
> No-ship: the gate can still silently accept incomplete or overclaimed window measurements.

- **[HIGH-1] 위치 윈도우 미완이 게이트에 전파 안 됨** (`analyze.py` measure_pos_window / _coverage_check /
  any_incomplete). `pos_window.incomplete=true`(pos cap 소진)여도 `_coverage_check`은 `time_window.incomplete`만
  보고 `any_incomplete`도 시간만 집계 → 필수 ant_reaches_x 액션의 위치 측정이 미완인데 `--verify`가 통과 =
  degraded 측정을 숨김(Phase 3a가 fail-closed 해야 할 바로 그 케이스). 제어흐름상 실재(가설 아님).
- **[HIGH-2] 희소 gap 샘플이 연속 interval을 과대주장, verify가 못 잡음** (`analyze.py` 시간 윈도우).
  내부 gap 검출이 고정 `GAP_PROBES` 점만 샘플 → 점 사이 좁은 fail island이면 `_reconstruct_runs`가 단일
  연속 interval로 보고, verify는 interval mid·lo-1·hi+1·선언 gap만 확인 → 숨은 내부 fail island을 영영
  미재생 = 조용히 부풀린 반응 윈도우 + byte-재현되나 거짓인 artifact.

## 수정 (HIGH-1·HIGH-2, 둘 다 fail-closed 강화)

- **HIGH-1**: `_coverage_check`가 `pos_window.incomplete=true`(측정된 보조 윈도우 한정)도 coverage FAIL 처리 +
  `any_incomplete`에 pos 미완 포함 + `_selfcheck_gate`에 pos-incomplete 거부 케이스 추가(통과 불가 증명). 단,
  `saturated_lo/hi`(도달 범위 끝까지 클리어 = 정당한 결과)는 incomplete 아니므로 비-게이트.
- **HIGH-2**: gap 스캔을 **균일 stride**(`stride = 폭//(GAP_PROBE_BUDGET+1)`)로 하고 `gap_check_stride`를
  time_window에 **명시 기록**(해상도 한계의 coverage proof — "stride 이하 간격에서 gap 미검출"; sub-stride
  island은 배제 못 함을 정직 표기, 과대주장 제거). `--verify`가 각 interval 내부를 **같은 stride로 dense
  재스캔**(`_stride_points`)해 sampled-clear 주장을 측정 해상도에서 강제(숨은 gap·analysis 변조 차단).
  넓은 interval일수록 stride 큼 = 적은 점이지만 측정과 동일 해상도라 정직(좁은 binding 윈도우는 stride 작아
  촘촘). 회귀: 측정값(lo/hi/intervals) 불변, `gap_check_stride` 필드만 추가.

## Self-Review Round 2 (수정 후 자체 적대, clean)

- HIGH-1 수정 검증: 단위 — pos incomplete → `_coverage_check` FAIL, pos complete → pass, `_selfcheck_gate`
  양/음(pos 포함) 통과. `any_incomplete`가 pos 미완 반영. ✓.
- HIGH-2 수정 검증: `_stride_points` 단위(0/100/30→[30,60,90], 좁은 구간→[]). 측정·verify가 동일 stride로
  같은 점 재생성 = 결정론. gap_check_stride 명시 → 과대주장 제거(연속 "증명" 아닌 "stride 해상도 sampled-clear").
  verify dense 재스캔이 측정 해상도에서 sampled-clear 강제. ✓.
- 부작용 점검: gap_check_stride 추가로 analysis.json 스키마 변경 → S11~S14 **재측정 필요**(값 불변·필드 추가).
  verify 비용 증가(interval당 ~stride 점) — binding 윈도우 촘촘, 넓은 윈도우 성김이라 과도하지 않음. ✓.
- 새 HIGH/CRITICAL 없음.

**Self-Review Round 2 결론: HIGH 0 → clean. 재측정 후 codex 재리뷰 진행.**

---

## Round 2 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×2 (신규)

R1 H1·H2 수정 **확인됨**. 그러나 verify에 신규 fail-closed 누수 2건:
- **[HIGH-1] verify가 analysis.json을 solve.json에 재바인딩 안 함**. `solution_ref` 기록만 하고 verify_one이
  그 파일을 열어 "현재 발견 해에서 산출됐는지" 확인 안 함 → embedded stage/deadline/required/minimal_plan을
  그대로 신뢰. solve.json이 바뀌거나 사라져도 stale analysis가 계속 통과 = 난이도/윈도우가 옛 해를 조용히 기술.
- **[HIGH-2] gap_check_stride가 누락·약화돼도 verify 통과**. verify가 `tw.get("gap_check_stride", fallback)`로
  임의 정수 신뢰 → 필드 없는 옛 analysis 통과, 과대 stride면 `_stride_points`가 점 0개 → dense 재스캔 무력화.
  R1-H2 수정이 실효성 없음(필드가 실제 강제 아님).

## 수정 (R2 HIGH-1·HIGH-2)

- **HIGH-1**: analyze가 `solution_sha256`(solve.json 바이트 해시) 저장. verify_one이 `solution_ref` 로드
  (없으면 FAIL) → 해시 재계산·비교 + stage/deadline/required 정합 + minimal_plan이 solve.json actions의
  부분집합인지(파생 정합). 순수 비교기 `_solution_binding_fails`로 분리해 `_selfcheck_gate`가 6 케이스
  (일치 통과 / 파일없음·해시·stage·required·파생 불일치 거부) 자가검증.
- **HIGH-2**: `_coverage_check`가 `gap_check_stride`를 lo/hi에서 **결정론 재계산값 `(hi-lo)//(budget+1)`과
  정확히 일치** 강제(누락·비양수·과대·변조 거부). verify_one은 fallback 제거하고 검증된 값 직접 사용.
  `_selfcheck_gate`에 stride 누락·과대(999)·비양수(0) 거부 케이스 추가.

## Self-Review Round 3 (수정 후 자체 적대, clean)

- HIGH-1: 단위 — `_solution_binding_fails` 해시 불일치/파일없음 거부, 일치 통과. `_selfcheck_gate` binding 6
  케이스 통과. verify_one이 실제 solve.json 로드·해시 비교. stale/삭제/변경 전부 fail-closed. ✓.
- HIGH-2: 단위 — `_selfcheck_gate` stride 누락/과대/비양수 거부. `_coverage_check`가 정확값만 허용 →
  verify가 dense 재스캔을 항상 측정 해상도로 수행(약화 불가). ✓.
- 부작용: analysis.json 스키마에 `solution_sha256` 추가 → S11~S14 재측정 필요(값 불변·필드 추가). minimal_plan
  부분집합 비교는 dict ==(JSON round-trip float 정합) — 실데이터로 검증 예정. ✓.
- 새 HIGH/CRITICAL 없음.

**Self-Review Round 3 결론: HIGH 0 → clean. 재측정 후 codex 재리뷰 진행.**

---

## Round 3 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R2 H1·H2 수정 **확인됨**. 신규 1건:
- **[HIGH-1] 기본 verify가 orphan analysis를 건너뜀 → 삭제된 solve.json이 fail-closed 안 됨**. `--verify`
  (stage 미지정)가 대상을 `stage*.solve.json`에서만 뽑음 → `stageNN.solve.json`이 삭제/rename됐는데
  `stageNN.analysis.json`이 남으면 ids에서 누락돼 `_solution_binding_fails`의 삭제 가드를 영영 못 거침. 기본
  프론트매터 게이트에서 stale 커밋 artifact가 조용히 생존(R2-H1 계약 우회).

## 수정 (R3 HIGH-1)

- 기본 verify 대상을 **analysis ∪ solve id 합집합**(`_verify_target_ids`)으로. solve만 있고 analysis 없으면
  verify_one이 analysis 부재로 FAIL; analysis만 있고 solve 없으면(orphan) `_solution_binding_fails`가 solve
  부재로 FAIL → 양방향 fail-closed. 순수 코드(스키마 무변경 → 재측정 불요).

## Self-Review Round 4 (수정 후 자체 적대, clean)

- **prove-it**: stage11.solve.json을 rename → 기본 `--verify`가 stage11을 (analysis glob에서) 포함하고
  "solution-binding FAIL: solution_ref 파일 없음(stale/삭제)"로 거부, 복원 후 4스테이지 PASS. ✓.
- 회귀: 특정 stage_id verify·측정 경로 불변, 엔진 무변경. ✓.
- 새 HIGH/CRITICAL 없음.

**Self-Review Round 4 결론: HIGH 0 → clean. codex 재리뷰 진행.**

---

## Round 4 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R3 수정 확인. 신규 1건:
- **[HIGH-1] verify가 분석 파일명-stage를 참조 solve id에 안 묶음**. `verify_one(stage_id)`이
  `stage{id}.analysis.json`을 로드하되 binding은 `analysis.solution_ref`만 신뢰 → `stage11.analysis.json`이
  stage12 내용 + `solution_ref: stage12.solve.json`이면 stage12에 깨끗이 바인딩·Stage12 리플레이·"stage11
  PASS" 보고(stage11.analysis.json 존재라 union도 누락 안 잡음) = silent-pass.

## 수정 (R4 HIGH-1)

- verify_one이 solve를 **이 stage_id의 정규 경로**(`stage{id}.solve.json`)에서 로드(분석이 지정한 ref가
  아니라) + `_solution_binding_fails`가 `analysis.solution_ref == expected_ref`(정규 경로)인지 강제. 다른
  stage 분석을 stageNN.analysis.json으로 위장하면 ref 불일치 + 정규 solve 해시 불일치로 이중 거부.
  `_selfcheck_gate`에 ref-가 다른-stage 케이스 추가.

## Self-Review Round 5 (수정 후 자체 적대, clean)

- **prove-it**: stage11.analysis.json의 solution_ref를 stage12.solve.json으로 변조 → verify 11 "solution-binding
  FAIL", 복원 후 PASS. 정상 4스테이지 default verify 218체크 그린(각 analysis.solution_ref=자기 stage solve). ✓.
- 회귀: 측정·엔진 무변경, 스키마 무변경(재측정 불요). ✓.
- 새 HIGH/CRITICAL 없음.

**Self-Review Round 5 결론: HIGH 0 → clean. codex 재리뷰 진행.**

### 선제 강화 (R1~R4 패턴 = "verify가 변조 가능 analysis 필드를 신뢰" 클래스 전면 차단)

codex R1~R4가 모두 "verify가 analysis.json의 어떤 필드를 무검증 신뢰"하는 fail-closed 누수였다(pos
incomplete / gap_check_stride / solution 바인딩 / 파일명-해 바인딩). 같은 클래스의 마지막 표면 = **파생
필드**(width_frames/width_s/tier/provisional_flags/stage_min_window_s/any_incomplete)를 verify가 무검증
신뢰. → 선제로 `_derived_consistency_fails` 추가: 검증된 intervals + **권위 caps**(capabilities.tres 재로드,
저장 caps와 일치 강제)에서 전부 재계산해 대조. 난이도 주장 변조를 fail-closed. prove-it: tier를
machine_only로 변조 → "derived-field FAIL: tier machine_only != 재계산 comfortable", 복원 PASS. selfcheck
6 케이스(일치 통과 / width_frames·width_s·tier·stage_min·any_incomplete 변조 거부). 순수 산술 → 재측정 불요.

---

## Round 5 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R4 + 파생 정합 확인. 신규 1건:
- **[HIGH-1] verify가 1-minimal임을 증명 안 함**. binding은 minimal_plan 각 액션이 solve actions에 있는지만,
  replay는 minimal_plan이 clear됨만 증명 → **deletion 트라이얼 부재**. stale/buggy/변조 analysis가 잉여 액션을
  품은 비최소 플랜을 "전부 필수"로 통과시킴(최소-스킬 proxy·난이도 오염, 잉여가 더 빡빡한 윈도우면 특히).

## 수정 (R5 HIGH-1)

- verify_one에 **deletion 트라이얼** — 각 액션 제거 시 깨져야(non-clear) 강제. + `_coverage_check`에
  `minimal_kind` 가드(1-minimal 또는 cardinality-minimal+증명메타(cardinality==len)만 허용). selfcheck
  minimal_kind 케이스 추가.

## Self-Review Round 6 (수정 후 자체 적대, clean)

- **prove-it**: stage11 분석에 잉여 blocker 중복 주입(per_action도 복제해 다른 검사 통과) → verify가
  "1-minimal: a0/a1 제거 → 깨져야 (got cleared=True)"로 FAIL, 복원 후 4스테이지 PASS(236체크 = +18 deletion
  트라이얼). S11~S14가 실제 1-minimal임 deletion으로 확증. ✓.
- 회귀: 측정·엔진·스키마 무변경(재측정 불요). ✓.
- **R1~R5 종합**: verify가 신뢰하던 모든 analysis 필드(pos incomplete/gap stride/solution 바인딩/파일명-해/
  파생/minimality)를 권위 출처(solve.json·capabilities.tres·엔진 deletion 리플레이)에서 재검증·재계산 →
  "변조 가능 필드 무검증 신뢰" 클래스 전면 차단. 새 HIGH/CRITICAL 없음.

**Self-Review Round 6 결론: HIGH 0 → clean. codex 재리뷰 진행.**

---

## Round 6 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R5 + R1~R5 종합 확인. 신규 1건:
- **[HIGH-1] 음성 단언이 infra 실패에 fail-open**. `Rollouter._run`이 no-result 시 `{error}` 반환 →
  `is_full_clear`가 False로 뭉갬 → verify가 음성 단언(deletion 트라이얼·경계·gap)에서 그 False를 "정상
  non-clear"로 인정. 서브프로세스 실패·malformed 경로·stdout 손실이 진짜 게임 non-clear와 구분 불가 →
  깨진 하니스로도 1-minimal·경계가 통과(양성 단언만 fail-closed, 음성은 fail-open).

## 수정 (R6 HIGH-1)

- verify를 **tri-state**로: 순수 `_verdict_check(res, expect_clear, required)` — error/`cleared` 부재 =
  infra 실패 → **항상 거부**(음성 단언도 fail-closed). 음성 단언은 진짜 게임 verdict(cleared=false)만 인정.
  verify_one이 `batch_clears`(bool) 대신 `batch_results`(원시 dict)로 받아 tri-state 평가. `_selfcheck_gate`에
  verdict 7 케이스(진짜 클리어/非클리어 통과 + error·verdict부재·기대불일치 거부).

## Self-Review Round 7 (수정 후 자체 적대, clean)

- 단위: `_verdict_check` — `{error}`+expect非 거부, 진짜 non-clear 통과, verdict 부재 거부. selfcheck verdict
  7케이스 통과. 4스테이지 full verify 236체크 그린(전부 진짜 게임 verdict). ✓.
- 측정(batch_clears)은 종전대로 보수적(error→fail) + exec_one 1회 재시도 — 측정은 게이트 아님(verify가 권위).
  verify만 strict tri-state. ✓.
- 회귀: 엔진·스키마 무변경(재측정 불요). ✓. 새 HIGH/CRITICAL 없음.

**Self-Review Round 7 결론: HIGH 0 → clean. codex 재리뷰 진행.**

---

## Round 7 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R6 + 누적 확인. 신규 1건:
- **[HIGH-1] verify가 완료 pos_window를 무검증 수용**. `_coverage_check`은 pos를 incomplete=true일 때만 거부,
  replay 루프는 시간 interval/gap만 sweep. 위조 pos(incomplete=false + 가짜 lo_x/hi_x/width/intervals)가 시간
  검사만 통과하면 verify 통과 → 보조 공간 측정의 silent-pass.

## 수정 (R7 HIGH-1)

- analyze가 `cell_size` 저장(width_cells 재계산용). `_coverage_check`이 완료 pos의 스키마/파생 정합 강제
  (lo_x≤hi_x, width_x==hi-lo, intervals==[[lo,hi]], gaps==[], width_cells==round(width_x/cs,3)). verify_one이
  pos를 **리플레이**: 내부(mid)=clear + **비-포화 경계**(lo_x-1/hi_x+1)=fail(포화 경계는 도달 밖이라 스킵).
  `_selfcheck_gate`에 pos 스키마 변조 5케이스. cell_size 추가 → S11~S14 재측정.

## Self-Review Round 8 (수정 후 자체 적대, clean)

- 단위: selfcheck pos 정합 통과 + width_x/width_cells/intervals/lo>hi 변조 거부. ✓.
- pos 리플레이 포화 처리: S12 blocker#1(saturated_lo)·blocker#2(saturated_hi) 경계는 스킵, 내부만 검증 —
  도달 범위 끝까지 클리어가 정당하므로 "밖" 단언 ill-defined 회피. 비-포화 경계만 fail 단언. ✓(재측정 후 실증).
- 회귀: cell_size 필드 추가(값 불변), 재측정 필요. ✓.

**Self-Review Round 8 결론: HIGH 0 → clean(재측정·verify 후 확정). codex 재리뷰 진행.**

---

## Round 8 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R7 + 누적 확인. 신규 1건:
- **[HIGH-1] 윈도우 경계(lo/hi/lo_x/hi_x)를 clear 리플레이 안 함**. verify가 내부 mid/stride + 양 끝 밖
  (lo-1/hi+1)만 찍고 경계 자체는 미검증 → 경계를 fail 프레임으로 넓히고 폭 필드를 일관 갱신하면 내부 샘플이
  clear인 한 통과(시간·위치 공통). 포화 플래그도 도메인 끝 대응 미증명으로 밖 검사 스킵.

## 수정 (R8 HIGH-1)

- verify_one이 각 interval의 **경계(lo,hi) 및 pos(lo_x,hi_x)를 clear 리플레이**(내부에 lo/hi 포함). +
  `_coverage_check`이 pos `domain` 스키마 + 포화 정합(saturated_lo⟹lo_x==domain[0], saturated_hi⟹hi_x==
  domain[1], domain[0]≤lo_x≤hi_x≤domain[1]) 강제 → 위조 포화로 밖 검사 우회 차단. selfcheck domain/포화 4케이스.

## Self-Review Round 9 (수정 후 자체 적대, clean)

- **prove-it**: time hi를 fail 프레임으로 20넓힘 + width/stride/tier/stage_min 전부 일관 갱신(파생·스키마
  우회) → verify가 "interval[466,622] 622=clear (got cleared=False)"로 **경계 리플레이 FAIL**, 복원 PASS.
  4스테이지 full verify 301체크 그린(경계 포함). ✓.
- 위조 포화: selfcheck saturated_lo+lo_x!=domain[0] 거부, 정당 포화(lo_x==domain[0]) 통과. ✓.
- 회귀: 스키마 무변경(domain/saturation 이미 존재, 재측정 불요). ✓. 새 HIGH/CRITICAL 없음.

**Self-Review Round 9 결론: HIGH 0 → clean. codex 재리뷰 진행.**

---

## Round 9 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R8 + 누적 확인. 신규 1건:
- **[HIGH-1] pos_window가 gap 미검출로 연속 과대주장**. measure_pos_window가 [lo_x,hi_x] 한 쌍만 잡고
  무조건 `gaps:[]` 단일 interval 기록(내부 비-clear island 미스캔). _coverage_check은 gaps 빈 것을 강제,
  verify는 lo_x/hi_x/mid/밖만 리플레이 → midpoint 아닌 내부 실패 x가 통과(시간 윈도우 R1-H2와 동일 문제가
  pos엔 미적용). ant_reaches_x.x 변경이 발화 시점·선택 상태를 바꿔 단조 보장 없음.

## 수정 (R9 HIGH-1) — pos를 시간 윈도우와 **완전 동형**으로

- measure_pos_window가 [lo_x,hi_x] 확정 후 균일 stride 스캔 + `_reconstruct_runs`로 intervals/gaps 복원 +
  `gap_check_stride` 기록(width_x=max-interval). `_coverage_check`이 pos를 시간과 동형 검증(intervals 엔벨로프·
  max-interval width·gap_check_stride 정확). verify_one이 pos를 시간과 동형 리플레이(각 interval 경계+내부
  stride=clear, 엔벨로프 밖=fail, 각 gap 내부=fail). selfcheck pos gap·stride 케이스. pos 스키마 변경 → 재측정.

## Self-Review Round 10 (수정 후 자체 적대, clean)

- 단위: selfcheck pos gap 정합(2 interval+1 gap) 통과, gap_check_stride 과대 거부, 위조 포화 거부. ✓.
- pos가 이제 시간과 동일한 gap 검출·검증 모델 → R1~R9의 "pos 비대칭" 클래스 완전 종결. cell_bracket_frames만
  informational(trace 교차참조, plan 명시 보조). ✓.
- 재측정 후 verify(시간+위치 동형 gap 검증) 그린·prove-it(pos 내부 gap 누락 거부) 확인 예정.

**Self-Review Round 10 결론: HIGH 0 → clean(재측정·verify 후 확정). codex 재리뷰 진행.**

---

## Round 10 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R9 + 누적 확인. 신규 1건:
- **[HIGH-1] pos 리플레이가 baseline spawn_index를 핀하지 않음**. `sweep_pos_plan`이 원본 `max_x`/`min_x`
  셀렉터로 x만 스윕 → x 변경 시 *다른 개미*가 발화를 가로채, baseline 개미가 아닌 다른 개미 덕에 클리어되는
  intervals/gaps를 수용(기록된 spawn_index/domain/cell_bracket은 baseline 개미를 기술). pos가 시간과 진짜
  isomorphic이 아니라 R9의 핵심 보장이 selector drift에 silent-pass.

## 수정 (R10 HIGH-1)

- `sweep_pos_plan(minimal, idx, sweep_target, cmp, x)` — 시간과 **동일한 spawn_index 고정 target** + ant_reaches_x
  {cmp,x}로 치환(x만 스윕). measure/verify 양쪽이 baseline 개미를 핀해 그 개미의 공간 윈도우만 측정·재검증.
  analyze가 sweep_target+cmp 전달, verify가 저장 sweep_target + minimal[idx].trigger.cmp 사용. pos 측정값
  변할 수 있어 재측정.

## Self-Review Round 11 (수정 후 자체 적대, clean)

- 단위: sweep_pos_plan이 target=spawn_index-pinned + trigger=ant_reaches_x{cmp,x} 생성 확인. selfcheck 통과. ✓.
- 이로써 시간·위치 윈도우가 **완전 isomorphic**(둘 다 baseline 개미 spawn_index 고정, 한쪽은 at_frame_exact
  시간 스윕·다른쪽은 ant_reaches_x x 스윕, 동일 gap 검출·경계·내부·밖 리플레이). selector drift 차단. ✓.
- 재측정 후 verify 그린 확인 예정.

**Self-Review Round 11 결론: HIGH 0 → clean(재측정·verify 후 확정). codex 재리뷰 진행.**

### R10 디버그 (사용자 지시 "버그 디버그 완료") — 근본 원인 2건 + pos 재설계

R10 핀 적용 후 재측정·verify에서 stage14 blocker#2가 깨짐. 진단:
- **버그①: UnicodeEncodeError로 `--all` 중단**. incomplete 경고의 `⚠` print가 cp949 콘솔에서 예외 →
  stage12 직후 크래시 → stage13/14가 **stale(옛 unpinned 데이터) 잔존**. 이게 여러 차례 재측정이 stage14를
  안 고친 진짜 이유(stored≠fresh-measure). → **수정: 모듈 로드 시 stdout/stderr UTF-8 강제**(`reconfigure`).
- **버그②: pos x-스윕이 bouncing 개미에 근본적으로 모호**. stage12 blocker#2(cmp=le, select=min_x): 개미 2번
  궤적이 cx 6→1→8→6으로 **위치 재방문** → `ant_reaches_x{le,312}`는 *첫* 교차(frame~275)서 발화, baseline은
  *나중* 복귀(frame 1423)서 발화 → 핀해도 baseline 재현 불가 → incomplete. 직접 롤아웃으로 x=48~633 전부
  time_out(fail) 실증, x≥1080만 clear. 즉 **위치 윈도우는 단방향 임계 스윕으로 권위 측정이 불가능한 케이스
  존재**(개미가 x를 여러 번 지남).

**해결 = pos를 권위 게이트에서 빼고 informational 파생으로**(codex R7이 명시 허용한 옵션 + plan "pos=보조,
시간=1급" 정합): `measure_pos_window`/`sweep_pos_plan`/`_reachable_x_domain` 제거 → `_pos_hint`로 교체.
**유효 시간 윈도우(1급 권위) 프레임 동안 핀된 개미가 점유한 x-셀 범위를 baseline trace에서 파생만** 한다
(별도 롤아웃·게이트 없음, `authoritative:false` 마킹). verify는 pos를 재검증 안 함(파생값 — 시간 윈도우/궤적이
이미 권위). _coverage_check은 pos_hint가 권위 위장(authoritative≠false)만 가볍게 거부. → **R7~R10가 파고든
pos 비대칭·silent-pass 클래스 자체를 "pos는 게이트 대상이 아니다"로 종결**. 시간 윈도우 + 최소화(deletion) +
solution 바인딩 + 파생 + tri-state가 1급 권위 게이트로 남음.

## Self-Review Round 12 (재설계 후 자체 적대, clean)

- 시간 윈도우는 at_frame_exact(정확 프레임)라 bouncing 무관·항상 재현 → 1급 권위로 견고(불변). pos만 모호해서
  파생-informational로 격하 — 권위 주장 0이라 silent-pass 불가능(주장을 안 하니까). ✓.
- UTF-8 수정으로 `--all`이 끝까지 완주(중간 stale 차단). ✓.
- 단위: selfcheck(pos 케이스 제거, pos_hint authoritative-위장 거부) + _pos_hint 파생 통과. ✓.
- 재측정(pos_window→pos_hint, 시간 윈도우 값 불변) + verify 그린 확인 예정. 새 HIGH/CRITICAL 없음.

**Self-Review Round 12 결론: HIGH 0 → clean(재측정·verify 후 확정). codex 재리뷰 진행.**

---

## Round 11 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1 (신규)

R10 디버그/재설계 확인. 신규 1건:
- **[HIGH-1] verify가 레거시 권위 pos_window를 거부 안 함**. 새 coverage는 pos_hint만 보고 옛 `pos_window`
  필드를 거부 안 함 + 스키마/analyzer 버전 바인딩 부재 → 같은 solve.json 해시의 **R9-스타일 stale analysis**(옛
  pos_window 권위 측정 포함)가 시간/deletion 검사만 통과하면 verify 통과 → "pos 권위 0" 불변식 위반.

## 수정 (R11 HIGH-1)

- `ANALYSIS_SCHEMA_VERSION=2` 도입 + analysis에 `analysis_schema_version` 저장. `_coverage_check`이 정확
  일치 강제(불일치/누락 → FAIL) → analyzer 의미 변경 후 같은 해시 stale analysis를 재생성 강제. + 레거시
  `per_action.pos_window` 잔존 시 명시 거부(이중 방어). selfcheck 스키마버전 누락·옛버전·레거시 pos_window 거부.

## Self-Review Round 13 (수정 후 자체 적대, clean)

- 단위: selfcheck schema_version(누락·v1·레거시 pos_window) 거부 통과. 현 데이터(버전 부재)가 즉시 coverage
  FAIL → 재측정 강제 실증. ✓.
- 스키마버전 = 일반 가드: 앞으로 어떤 analyzer 의미 변경도 bump로 stale 차단(R7~R11류 "의미 변경 후 옛 산출물
  통과" 클래스 종결). ✓.
- 재측정(schema_version 추가) + verify 그린 확인 예정. 새 HIGH/CRITICAL 없음.

**Self-Review Round 13 결론: HIGH 0 → clean(재측정·verify 후 확정). codex 재리뷰 진행.**

---

## Round 12 (codex adversarial-review, --base f3f0a10) — needs-attention, HIGH×1

R11 확인. 신규(실은 R1-H2 회귀 — 시간 윈도우 gap 샘플링):
- **[HIGH-1] 샘플 gap을 연속 권위 윈도우로 보고**. `measure_time_window`가 gap을 `stride=(hi-lo)//9` 간격만
  샘플 → stride>1(넓은 윈도우, S13 climber stride=481)이면 sub-stride fail-island 미배제인데 `intervals`를
  **연속**으로, `width_s`/난이도를 전 범위로 보고 → 과대주장. 전 프레임 검증은 넓은 윈도우(4334f)에 비현실적.

## 결정(사용자) = "정직한 sampled 표기"(빠름) — full-scan 대신 과대주장 제거

전 프레임 스캔(권위)은 verify를 ~10분으로 만들어 frontmatter 게이트에 비현실적. 사용자 선택 = **sampled를
명시 표기해 과대주장만 제거**(codex가 제시한 두 옵션 중 "represent sampled coverage explicitly").

## 수정 (R12 HIGH-1)

- time_window에 `gap_verified`(=stride==1)·`gap_coverage`("full@1"|"sampled@N") 명시 — stride>1이면
  intervals/width는 **그 해상도의 sampled 추정**(sub-stride 미배제)임을 정직 표기, 연속-권위 위장 차단.
- stage 레벨 `stage_min_window_gap_verified`(binding 윈도우가 full인지) + `gap_coverage_note`. 대부분
  sampled@stride라 난이도는 **sampled 추정**(정직 disclosure; 권위 난이도는 3b/정밀 full-scan 시).
- `_coverage_check`: gap_verified==(stride==1)·gap_coverage 문자열 정합 강제(sampled를 full로 위장 거부).
  `_derived_consistency`: stage_min_window_gap_verified=binding gap_verified 재계산. schema v2→v3(stale 차단).
  selfcheck gap_verified/gap_coverage/stage_min_gv 변조 케이스.

## Self-Review Round 14 (수정 후 자체 적대, clean)

- 과대주장 제거 = codex 핵심 우려 해소(연속-권위로 오해 불가, 명시 sampled). binding 난이도가 sampled면
  `stage_min_window_gap_verified:false`로 정직 disclosure. ✓.
- 단위: selfcheck gap_verified/coverage/stage_min_gv 변조 거부 통과. schema v3로 옛 산출물 stale 차단. ✓.
- 추가 롤아웃 0(라벨링만) → verify 빠름 유지. 재측정(필드 추가·시간값 불변) + verify 그린 확인 예정. 새 HIGH 없음.

**Self-Review Round 14 결론: HIGH 0 → clean(재측정·verify 후 확정). codex 재리뷰 진행.**

---

## Round 13 (codex adversarial-review, --base f3f0a10) — needs-attention, **MEDIUM×1** (HIGH 0 — 수렴 신호)

R12 확인. **첫 비-HIGH**(MEDIUM):
- **[MEDIUM] verify가 sampled disclosure note를 강제 안 함**. R12가 `gap_coverage_note`로 난이도가 sampled임을
  알리는데 `_coverage_check`은 per-action gap_verified/coverage만 검증, top-level note는 미요구 → 편집/생성된
  v3 analysis가 note를 지우고 stage_min/tier를 권위처럼 보이게 해도 통과. disclosure 계약의 silent-pass.

## 수정 (R13 MEDIUM — cheap·정공법, defer 대신 즉시 닫음)

- `_coverage_check`: 결과가 sampled(완성 윈도우 중 gap_verified=false OR binding sampled)면 `gap_coverage_note`
  present+non-empty 강제. note 삭제로 sampled를 권위로 위장하는 silent-pass 차단. selfcheck sampled(note O/X) 케이스.
  코드 전용(현 파일이 이미 note 보유 → 재측정 불요), verify 그린.

## Self-Review Round 15 (수정 후 자체 적대, clean)

- 단위: selfcheck sampled+note 통과 / sampled-note부재 거부. 4 실데이터 coverage 통과(note 보유). ✓.
- **수렴 신호**: R1~R12 전부 HIGH였는데 R13은 MEDIUM 1건(그마저 cheap fix). 권위 게이트 표면이 거의 닫힘. ✓.
- 새 HIGH/CRITICAL 없음.

**Self-Review Round 15 결론: HIGH 0 → clean. codex 재리뷰 진행.**
