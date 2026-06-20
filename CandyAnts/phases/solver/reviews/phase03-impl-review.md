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
