# auto-solver Phase 3 — Plan Stage Adversarial Review

> 정책: CLAUDE.md plan stage — CRITICAL/HIGH 발견 시 최대 2회 수정+재리뷰(3-round cap).
> 대상 = `phases/solver/auto-solver-plan.md` 새 Phase 3 섹션(3a 윈도우 측정+최소화, D12).
> 구동: `codex-companion.mjs task --effort high`(read-only) — plan 문서+코드 직접 검토(diff 아님).

## Round 1 — codex task read-only (2026-06-20)

## Verdict: needs-attention (CRITICAL 2 + HIGH 4 + MEDIUM 2 + LOW 1)

### CRITICAL
- **[C1] `f*` 획득 경로가 현재 설계로 성립하지 않음.** plan은 baseline 발화 frame을 "PlanRunner 발화
  로그/`_fired_frame`"에서 얻는다 하나, `_fired_frame`은 내부 `after`용 dict로 결과 미노출
  (`PlanRunner.gd:48,300-310`), `SOLVER_RESULT`엔 `actions_fired`만 있고 per-action frame 없음
  (`PlanRunner.gd:465-477`), `run_plan.py`는 SOLVER_RESULT만 파싱·stdout 버림(`run_plan.py:49-55`).
  stdout regex는 duplicate climber 5개 매핑 깨짐. → 수정: PlanRunner opt-in 필드로 fired action별
  `{index,label,skill,frame,spawn_index,pos}`를 SOLVER_RESULT에 넣거나 "엔진 무변경" 철회.
- **[C2] `picked_ge`→`at_frame` 정규화의 "너무 이르면 실패=하한" 가정이 코드와 반대.** `at_frame`은
  `_frame >= frame`이라 그 프레임에 대상 없어도 실패가 아니라 다음 프레임 재시도(`PlanRunner.gd:275-298,
  321-338`). → 수정: "exact at frame, no retry" 의미 추가 또는 baseline fired `spawn_index`를 고정
  target으로 변환. 현재 `at_frame`으론 하한 측정이 거짓으로 넓어짐.

### HIGH
- **[H1] carry 연쇄 `select=min_x,state=carrying`은 프레임마다 다른 개미를 골라 per-action 윈도우 의미
  불안정.** (`stage13/14.solve.json` climber×5, `PlanRunner.gd:366-400`, `model.py:284-316`.) → 수정:
  baseline fired `spawn_index` 기록, 윈도우 스윕은 원본 selector + spawn_index 고정 둘 다 산출, 다르면
  `selector_instability=true`, 난이도는 고정-ID 측정만 사용.
- **[H2] `ant_reaches_x` 위치 윈도우의 trace 시간 환산 대상 개미 식별 미정의.** solve.json·result에
  fired target identity·trace 없음(`stage11.solve.json:40-54`, `solve.py:254-261`). → 수정: baseline·각
  boundary rollout에서 fired `spawn_index` 기록, boundary가 같은 target에 발화했는지 검증, 다르면
  "selector changed" 별도 interval.
- **[H3] 최소화가 "필수 최소 플랜"을 보장 못 함.** 1-pass/greedy는 1-minimal이지 cardinality-minimal
  아님. → 수정: 액션 수 ≤8이므로 subset 탐색/ddmin으로 cardinality 증명, 아니면 산출명을 "1-minimal"로
  낮추고 Acceptance에서 "최소" 제거.
- **[H4] "현재 solve.json 분석"과 D6/Phase2 max-margin 난이도 정의 모순.** `solve.py`는 첫 full clear
  즉시 저장·종료(`solve.py:188-189,238-239`), margin 탐색 근거 없음. → 수정: 3a 산출을 "발견된 해의 윈도우
  측정"으로 격하하거나 max-margin 후보 선택 단계 추가.

### MEDIUM
- **[M1] `analyze.py --verify`가 비연속 interval/불완전 측정 검증에 약함.** 경계 안/밖 2점만 재검증. →
  수정: analysis.json에 search domain/grid/interval/gap/cap-incomplete 저장, verify는 interval 내부·양 끝
  밖·gap 내부 모두 샘플, cap 초과 "하한만"은 verify-green 제외.
- **[M2] "직관 일치 sanity"는 반증 불가.** 측정 후 라벨 수집 = 사후 해석. → 수정: 라벨 pre-register 또는
  Spearman 순위상관/불일치 쌍 기록 + flags 원인분석으로 바꾸고 pass/fail 게이트 제외.

### LOW
- **[L1] `T_human` 3a "캘리브레이션 불요"라면서 값 분류 요구.** 현재 하드 기본값(`capabilities.tres:10-12`).
  → 수정: `tier_source="default_uncalibrated"` 명시, "정합성 오류"→"provisional_machine_only_flag" 격하,
  최종 판정 3b.

> **처리(Round 2 plan 반영)**: C1+C2+H1+H2를 단일 수정으로 해소 — D12를 "엔진 무변경"→"엔진 가산 opt-in
> 확장(trace 패턴, 기존 동작/verdict/결정론 불변)"으로 정직화: (a) fired-action 보고(spawn_index+frame),
> (b) `at_frame_exact` 가산 트리거 + spawn_index 고정 target으로 측정. H3=산출명 "1-minimal" 정직화
> +액션≤K subset cardinality 옵션. H4="발견된 해(현 solve.json)의 윈도우 측정"으로 범위 정정, max-margin은
> 3b/비전. M1=analysis.json domain/grid/gap 저장+verify 강화. M2=직관대조 게이트 제외(정보 산출)+pre-register.
> L1=tier_source 명시+provisional 격하.


## Round 2 — codex task read-only (2026-06-20)

## Verdict: needs-attention (HIGH 3 + MEDIUM 3; R1 C1/C2/H4/M2/L1 해소 확인)

> codex 확인: C1(fired_actions 구현 가능 — `_mark_fired(act,fired_info)`로 target 정보 전달), C2(at_frame_exact
> `_frame==frame` branch 추가, 기존 at_frame `>=` 불변·다음 프레임 재시도 없음), H4/M2/L1 격하 충분, H3 정직화.

### HIGH
- [R2-H1] `report_fired:true(또는 trace 동반)`이 바이트동일 주장과 충돌 — solve.py는 모든 롤아웃에
  trace:true(`solve.py:52-53`), 저장 시 trace만 제거(`solve.py:261`). trace 동반으로 fired 켜면 solve.json
  변동. → 처리: `report_fired` 전용 flag(trace 독립), `_save`가 trace·fired_actions 둘 다 제외 명시.
- [R2-H2] spawn_index 고정 변환이 state 필터 버려 S13 깨짐 — 기본 state="walker"(`PlanRunner.gd:372`),
  S13 climber는 state:"carrying" 필수(`stage13.solve.json:45`). → 처리: 원본 target 필터 보존(특히 state,
  없으면 "any"), select/spawn_index만 덮어쓰기.
- [R2-H3] `incomplete:true` verify-green "제외"가 미완 측정을 통과시킴(의도와 반대). → 처리: 필수 액션 중
  incomplete 하나라도 있으면 게이트 FAIL, 탐색용 `--allow-incomplete`만 허용.

### MEDIUM
- [R2-M1] fired_actions 스키마가 cell-target(SIGN/DEVICE) 미표현. → 처리: target_kind:"ant"|"cell" +
  spawn_index/target_pos(ant) + target_cell(cell, place_on_cell 결과).
- [R2-M2] MINIMIZE_SUBSET_CAP=8 2^n 비용(최악 1024 롤아웃 ~ 수십분). → 처리: `--prove-cardinality` opt-in,
  크기순 조기종료·plan-hash 캐시·--workers, 기본 verify 미포함.
- [R2-M3] 위치/시간 윈도우 교차검증이 trace 정밀도(cell 변화 시만 기록)보다 강한 서술. → 처리: cell-bracket
  교차검증으로 격하, 정밀 필요 시 report_fired authority.

> **처리(Round 3 plan 반영)**: 7개 verified replacement으로 v3 수정 — R2-H1/H2/H3 + M1/M2/M3 전부 plan 문구
> 정밀화(설계 방향 불변, C1/C2 구현 가능 확인). Round 3 최종 검증 대기.


## Round 3 (최종) — codex task read-only (2026-06-20)

## Verdict: needs-attention (HIGH 1 + MEDIUM 3 + LOW 1) → plan stage 3-round cap 도달, 사용자 결정 필요

> CLAUDE.md 정책: Round 3 HIGH 1건이라도 나오면 즉시 중단·사용자 보고. R2-H1/H2/H3 방향 해소 확인,
> at_frame_exact 결정론·spawn_index 고정(0-기반 스폰 시 고정) 타당 확인.

### HIGH (R2-M2 재오픈 — 내부 모순)
- [R3-H1] `--prove-cardinality` opt-in(기본 off·verify 미포함, plan §3a-A)과 Acceptance "액션≤8이면
  cardinality-minimal 증명"이 충돌. S13=6·S14=8 액션이라 opt-in 비용 제어가 사실상 무효화(증명 강제됨).
  → 수정: Acceptance를 "minimal_kind 정직 명시; `--prove-cardinality` 지정 시에만 cardinality 증명"으로,
  기본 3a 게이트는 1-minimal만 요구. (R2 수정 시 설계는 opt-in으로 바꿨으나 Acceptance 줄 동기화 누락
  = 자명한 일관성 결함.)

### MEDIUM
- [R3-M1] report_fired/trace "동반 금지"가 cell-bracket 교차검증(trace 필요)과 충돌. → baseline을 결정론
  동일 plan 2회 실행(report_fired run = f*/target, trace run = cell bracket) 명시, 또는 동시 허용 + _save
  제외로만 바이트동일 보장.
- [R3-M2] --verify가 per-action coverage(minimal_plan.actions <-> per_action index/label 1:1, 중복 없음,
  모든 필수 액션 window 존재) 선검증 명시 누락 → 버그난 analyze.py가 어려운 액션 per_action 누락 시
  incomplete 검사 우회 가능.
- [R3-M3] analysis.json per_action이 ant 전용처럼(spawn_index 평면) → cell-target 표현 안 됨. →
  per_action.target={kind:"ant",spawn_index,target_pos?}|{kind:"cell",target_cell}로 통일.

### LOW
- [R3-L1] Phase 3 heading/D12/3a 표기가 아직 "v2" 잔존(v3 미갱신). → v3 표기 갱신.

> **구현 주의(codex 확인)**: solve.py._save는 현재 trace만 제외 → impl 시 fired_actions도 제외 필수.
> **3-round cap 도달 → 사용자 결정 대기**(아래 보고).


## Round 4 — codex task read-only (2026-06-20, 사용자 cap 연장 승인)

## Verdict: APPROVE (CRITICAL/HIGH 0; MEDIUM 2 + LOW 2 → plan 내 처리 종결)

> R3-H1/M1/M2/M3/L1 해소 확인. R3-M1 byte-identical은 codex가 코드(_record_trace가 게임 상태 미변경,
> PlanRunner.gd:223/238/244/474)로 검증. CRITICAL/HIGH 차단 사유 없음 → plan stage 종결.

### MEDIUM (plan 내 처리)
- [R4-M1] 최소화 "각 액션 원본 나머지 빼보기"는 대체가능 A/B를 둘 다 redundant 오분류 위험.
  → 처리: **고정 순서 순차 제거**(제거 확정 시 candidate에서 빼고 진행) = deletion-minimal(1-minimal) 보장.
- [R4-M2] per_action 스키마에 label만 있고 index 없어 coverage 검증 약함. → 처리: per_action에 index
  required 추가, verify는 index 기준 전체 커버리지·duplicate index 0·label 일치.

### LOW (plan 내 처리)
- [R4-L1] v3 노트에 "baseline 2회 실행" 잔재(본문은 1회 동시). → 처리: "baseline 1회 실행(report_fired+
  trace 동시)"로 갱신.
- [R4-L2] report_fired "trace 동반 금지"가 전역 규칙처럼 읽힘. → 처리: 처음부터 "solve.py 저장 경로 한정,
  analyze.py baseline은 예외적 동시 사용" scope 명시.

> **plan stage 종결(2026-06-20)**: R1(C1C2H1H2H3H4M1M2L1) → R2(H1H2H3M1M2M3) → R3(H1M1M2M3L1) →
> **R4 approve**. 4 라운드 후 CRITICAL/HIGH 0. 핵심 진화: "엔진 무변경"→"엔진 가산 opt-in 확장"
> (fired_actions 보고 + at_frame_exact 트리거 + spawn_index 고정 측정), max-margin→"발견된 해 윈도우
> 프로파일", 1-minimal(deletion-minimal) 정직화, provisional T_human, cell-bracket 교차검증, incomplete=
> 게이트 FAIL. **다음 = impl(3a: PlanRunner 가산①② → analyze.py → 4스테이지 측정 → verify 편입 → 회귀)**.
