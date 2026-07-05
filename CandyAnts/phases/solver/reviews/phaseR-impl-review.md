# Phase R R0 (RL 파이프라인) — impl-stage 적대적 리뷰 트레일

> 대상: `tools/solver/rl/{mdp.py,train.py,requirements.txt}` + `data/solutions/stage11.rl.json`.
> codex `adversarial-review --scope working-tree`(신규 파일 staged). 사용자 Ch2 WIP(stage17/project.godot/
> stage26~33)·plan/review 문서는 리뷰 범위 밖으로 명시.

## Round 1 (2026-07-03) — needs-attention (HIGH 1 · MEDIUM 2)

- **[high] verify-r0 does not enforce the pinned acceptance contract or stage binding** (train.py:299-336)
  — 키 존재·seed 3개·≥2 cleared만 검사. pinned seeds 0,1,2 / envs_requested=4 / max_episodes=20000 /
  max_wall=7200 / grammar_version / meta.pass / stage·stage_id·deadline 바인딩 미검증 → 다른 config·다른
  스테이지 산출물이 replay만 통과하면 인증됨(fail-closed 계약 위반).
- **[medium] Preflight is sequential** — 순차 e.step 루프라 학습이 쓰는 ThreadPoolExecutor 병렬 경로를
  미검증. 동시성-전용 실패가 preflight를 통과해 학습 중 표면화 가능.
- **[medium] EnvPool construction can leak Godot processes on partial failure** — list comprehension 중간
  실패 시 이미 부팅된 env의 close 경로 없음(포트/프로세스 누수).

### 처리 (전부 수정)
- HIGH → `R0_PIN` 상수 + verify_r0에 스테이지 바인딩(stage_id/stage/deadline_frames==config.replay_deadline/
  expect.saved==hp_stage) + pinned 계약(seeds 정확히 [0,1,2]·envs_requested·예산·grammar_version·pass·no_hint)
  전부 fail-closed. **음성 실증 4종**: seed 2개 변조→FAIL / 예산 pin 변조→FAIL / stage 변조→FAIL / 복원→PASS.
- M1 → preflight를 `pool.evaluate([plan]×2N)`(학습과 동일 ThreadPoolExecutor 경로)로 변경, 재실행 PASS
  (envs=4 runs=8 parallel identical=True).
- M2 → EnvPool 생성을 try/except 증분 구성으로 — 부분 실패 시 만든 env 전부 close 후 재던짐.

## Self-Review Round 1 (2026-07-03) — clean (HIGH 0)

수정 후 자체 적대 리뷰(코드 전체 재독):
- verify_r0 R0_PIN이 S12 stretch에도 적용(plan §R0 item 6 "동일 예산·동일 predicate"와 정합) — OK.
- run_training이 pass:false manifest를 쓰는 경우(부분 성공) → verify-r0가 meta.pass!=true로 FAIL — 거짓 인증 없음.
- 집계식 `n_clear*2 >= len(seeds)+(len(seeds)%2)` = 3-seed에서 ≥2 (pinned 케이스 정확), 1-seed 스모크에서 ≥1.
- SUBMIT 스텝0 마스킹: Categorical(-inf logit) 확률 0·entropy 기여 0 — torch 시맨틱 안전. 마스킹으로
  logps 최소 1개 보장(zero-tensor fallback은 방어용 잔존).
- 결정론: 샘플링은 메인 스레드 순차(torch.manual_seed), 스레드는 평가만(결과 인덱스-순서 보존) — 학습 곡선
  seed-재현 주장 유지. pool.evaluate 예외는 전파(crash = 정직 실패), run_training finally가 pool.close().
- 게이트 비커플링 실증: stage11.rl.json 존재 상태에서 기존 verify 8종 전부 그린(selftest 19/19 — glob
  `*.solve.json` 비매칭 확인). no_hint = model.propose 미import(구조적).

## Round 2 (2026-07-03) — needs-attention (HIGH 1)

- **[high] verify-r0 accepts artifacts that move the replay deadline** (train.py:314-350) — deadline 검사가
  "artifact 자기-일관"(top-level == 자기 config.replay_deadline)뿐이라, deadline_frames=16000 +
  config.replay_deadline=16000으로 재생성/변조된 산출물이 통과 → 느슨한 deadline으로 거짓 인증 가능.

### 처리
- `R0_PIN["replay_deadline"]=7000` 추가 — verify_r0가 `config.replay_deadline == pinned` AND
  `deadline_frames == pinned` 둘 다 강제(순환 신뢰 제거). 학습-전용 knob(train_deadline 등)은 인증 실체가
  아니므로 pin 비대상(사유 주석 명문화).
- **음성 실증**: deadline_frames+config.replay_deadline 동시(자기-일관) 16000 변조 → FAIL("deadline_frames
  != pinned 7000") / 복원 → PASS.

## Self-Review Round 2 (2026-07-03) — clean (HIGH 0)

- R0_PIN 확장이 run_training 산출 경로와 정합(deadline_frames=cfg.replay_deadline=7000 그대로) — 정상 산출물
  재검증 PASS 확인. S12 stretch manifest도 동일 경로라 pin 일치.
- 남은 manifest 자기-신뢰 = seed별 episodes/wall 수치(train.py 기록값) — R3-plan-review LOW로 이미 수용
  (독립 replay + 예산 pin이 보완, 로컬 비게이트 검사).

## Round 3 (2026-07-03) — **approve**

> Ship: the Round 2 deadline self-consistency bypass is closed, and I cannot support a remaining material
> fail-open finding in the staged R0 files. **No material findings.**

**impl-stage 종결**: R1(H1·M2) fix+음성실증 → Self-R1 clean → R2(H1) fix+음성실증 → Self-R2 clean → R3 approve.

---

# Phase R R1 (trace-shaped 보상+SIL) — impl-stage 적대적 리뷰 트레일 (사후 경로)

> 대상: 커밋 `431fdd6` diff(base `dc68a47`) — `tools/solver/rl/{mdp.py,train.py}` +
> `data/solutions/stage{11,12,17}.rl.json`. R1 커밋이 명시 박제한 "codex 리뷰 미실시 — 다음 세션 첫 작업"
> 이행. 사후(post-commit) 리뷰이므로 HIGH는 hot-fix 커밋(`fix: … (phase R sweep)`) 경로.

## Round 1 (2026-07-04) — needs-attention (HIGH 1 · MEDIUM 1)

- **[high] verify-r1 replays arbitrary actions without proving they are encodable by grammar r1.1**
  (train.py verify 경로) — grammar_version 문자열만 검사하고 `d["actions"]`를 그대로 replay. StageMDP
  encode→decode 왕복 검증·액션 수 vs pinned max_len 검사 부재 → grammar_version="r1.1"로 위조/수기 산출물
  (더 큰 max_len·ant-target/y_row 어휘 밖 액션 포함)이 replay만 통과하면 인증됨. "R1 문법의 산출물"이라는
  계약 파괴.
- **[medium] Trace preflight evidence can be self-forged with nonsensical run counts** — {ok,wall_s,runs}
  키 존재만 검사. runs가 preflight 계약(2×envs)과 일치하는지·zero/음수 wall·zero runs 거부 없음 →
  `preflight_trace={"ok":true,"wall_s":0,"runs":0}` 위조가 통과(trace 결정론 증거가 fail-closed 아님).

### 처리 (전부 수정 — hot-fix 커밋)
- HIGH → ① `R0_PIN`/`R1_PIN`에 `max_len=6` 추가(기존 extra_cfg 메커니즘이 cfg 존재+값 자동 강제) +
  `_verify_pinned`의 StageMDP를 pinned max_len으로 구성. ② `len(actions) ≤ 실효 max_len`(=min(ant-target
  인벤토리 합, pin.max_len)) + 빈 actions 거부. ③ **각 액션 encode→decode 라운드트립 자기재생산 검사** —
  문법 밖 액션은 격자 투영이 값을 바꾸거나(오프-그리드 x·비정렬 y밴드) 어휘 `.index`가 예외(미지 스킬·
  state) → fail-closed. 키 누락/잉여 키(at_frame 등)도 decode의 명시 키 재생산과 불일치로 검출. ④ replay
  대상을 라운드트립 canonical plan으로(문법 산출이 replay 권위; 통과 시 원본과 값 동일), 문법 실패 시
  replay 생략(이미 FAIL 확정).
- MEDIUM → `preflight_trace.runs == 2*envs_requested`(preflight 계약: env당 정확히 2회) + `wall_s > 0`
  (bool 배제 타입 검사) + `envs_effective≤1(강등)인데 ok=true`인 모순 manifest 거부.
- **음성 실증 6종 + 복원**(스크래치 하네스, stage12.rl.json 변조): ① off-grid trigger.x(+7px, 엔진 replay
  가능·문법 밖) → FAIL(라운드트립 불일치) ② 행 비정렬 y밴드 → FAIL ③ 액션 복제 길이 초과 → FAIL(4>실효 3)
  ④ config.max_len=8 변조 → FAIL(pin) ⑤ preflight runs=0 → FAIL ⑥ wall_s=0 → FAIL / 복원 → **verify-r1
  PASS**. verify-r0(S11)도 강화 후 PASS(회귀 0).
- 하네스 사고 1건 정직 기록: 1차 실행이 cp949 print로 중단돼 변조본이 디스크에 잔존 → 2차 실행 orig가
  오염본을 읽음(전 케이스 "actions 4개" 혼입). git restore로 원본 복원 후 재실행 = 클린 결과. 교훈:
  변조-복원 하네스는 git 권위 복원 + UTF-8 reconfigure 필수.

## Self-Review Round 1 (2026-07-04) — clean (HIGH 0)

- 위조 경로 전수 재점검: 키 누락(select/state/mode) → decode가 명시 키 재생산 → 불일치 FAIL / NaN·Inf x →
  round() 예외 → FAIL / picked_ge n 범위 밖·비정수 → clamp/int 불일치 FAIL / 잉여 키 → 불일치 FAIL — 열린
  경로 발견 못 함.
- `envs_effective==1 & ok==true` 모순 검사의 거짓 양성 없음: 강등은 preflight FAIL시에만 발생(build_pool
  유일 경로), N=1 요청 placeholder(runs=0)는 envs_requested pin에서 선차단.
- replay 생략 게이트(grammar_fails>0)는 fails 비어있지 않은 FAIL 확정 경로 — 거짓 통과 불가. PASS 경로
  digests[0] 접근 안전(fails 없으면 replay 2회 보장).
- 학습 경로(run_training/train_seed)·mdp.py·--coverage 무변경 — 게이트 강화만. HIGH 0.

## Round 2 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] preflight_trace remains self-forgeable because verify-r1 only validates claimed fields**
  (train.py:450-467) — 구조 검사(runs==8, wall>0, ok 일관성)는 위조 *값*을 좁힐 뿐, verify가 trace
  preflight를 재실행하거나 검증자 측 실측에 바인딩하지 않음 → `{"ok":true,"runs":8,"wall_s":0.01}`
  위조가 통과. preflight()/build_pool()/EnvPool.evaluate() 회귀를 JSON 편집으로 은폐 가능.

### 처리 (수정 — MEDIUM이지만 defer 대신 즉시 해소: 비용 낮고 finding의 원리(자기-보고≠증거)가 정당)
- `_verify_pinned` trace 블록에 **검증자 측 live preflight** 추가 — pinned env 수(4)로 EnvPool 구성 →
  `preflight(with_trace=True)` 직접 실행 → `ok==True AND runs==2*pin.envs` 실측 강제. 부팅/실행 예외는
  catch → fail-closed. finally에서 pool.close()(Godot 누수 0). manifest preflight_trace 구조 검사는
  *정직성 검사*로 유지하되 권위는 live 실행. wall_s는 진단 출력.
- 실측: verify-r1 PASS(live preflight envs=4 runs=8 identical wall=0.60s) + verify-r0 PASS(회귀 0 —
  R0 pin은 shaping 없음 → live preflight 비대상).

## Self-Review Round 2 (2026-07-04) — clean (HIGH 0)

- live preflight의 fail-closed 완결성: EnvPool 부팅 실패(RuntimeError)·preflight 내부 예외 전부 catch →
  fails 등재(크래시로 인한 미판정 없음). finally close로 부분 실패에도 프로세스 정리.
- 위조 관점 재점검: 이제 preflight 경로 회귀는 검증자 실행에서 직접 드러남 — manifest 편집으로 은폐
  불가. 남은 자기-신뢰 = seed별 episodes/wall 수치(R0 때 LOW 수용 — 독립 replay+예산 pin이 보완) 동일.
- 학습 경로 무변경. verify 실행 비용 +4 env 부팅(~0.6s) — 게이트 성격상 무시 가능.

## Round 3 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] Live trace preflight accepts missing traces as valid evidence** (train.py preflight) —
  `with_trace=True`가 `r.get("trace")` 동등성만 비교 → trace 수집이 조용히 사라지면(전부 None) 공허
  통과 = live 검증이 "빈-plan 결정론"으로 격하, trace-shaped 경로 인증이 무근거화.

### 처리 (수정)
- `preflight()`에 **trace 유효성 fail-closed**: 비어있지 않은 dict + 개미별 비어있지 않은 샘플 리스트 +
  첫 샘플 len>=4(소비자 `s[3]` 접근 정합) 전 결과 요구. 위반 시 `ok=False` + 반환에 `trace_present`
  필드 신설. `_verify_pinned` live 검사가 `trace_present is True`까지 명시 요구.
- **음성 실증(probe, EnvPool 서브클래스로 회귀 시뮬레이션)**: ① trace 필드 누락 풀 → ok=False·
  trace_present=False ② trace 빈 dict 풀 → 동일 FAIL ③ 정상 풀 대조 → ok=True·trace_present=True.
  verify-r1/r0 회귀 0 (verify-r1 live preflight trace_present=True 확인).
- 부수 정합: 학습 경로(build_pool)도 같은 guard를 타므로 trace 수집 회귀 시 N=1 강등+ok=False가
  manifest에 정직 기록되고, verify 측 live preflight가 독립적으로 FAIL — 이중 차단.

## Self-Review Round 3 (2026-07-04) — clean (HIGH 0)

- `_trace_valid` 경계: dict 아님/빈 dict/빈 샘플 리스트/기형 샘플(len<4) 전부 거부 — 소비자
  (best_goal_dist/count_retired)가 접근하는 최소 구조와 일치. 과잉 검증(값 시맨틱)은 하지 않음(형태만).
- `trace_present=None`(with_trace=False 경로)은 반환에 미포함 — R0 manifest 형태 불변.
- 동등성 비교는 trace_present 확인 후에만 수행 — None 간 공허 동등 경로 제거 확인.

## Round 4 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] Trace shaping can silently degrade after an empty-plan-only preflight** (mdp.py
  shaped_bonus + train.py) — trace 검증이 빈-plan preflight에만 있고, 실제 학습 롤아웃(actions 발화)은
  `shaped_bonus`가 부재 trace를 `{}`로 fail-safe 변환해 shaping 0으로 침묵 진행 → "빈 plan은 trace 정상·
  액션 발화 시 trace 소실" 회귀가 manifest·live preflight 둘 다 통과하면서 `shaping='trace'` 라벨 산출물이
  base 보상+SIL만으로 인증될 수 있음.

### 처리 (수정)
- `_trace_valid`를 모듈 공용 헬퍼로 승격(3 소비자: preflight / 학습 롤아웃 / verify replay).
- **train_seed 롤아웃별 trace 검증**: use_trace면 각 배치 롤아웃의 trace 유효성 확인, 위반 시
  `RuntimeError`로 run 전체 fail(정직 크래시 — silent shaping 격하 산출물 원천 금지). run_training의
  finally가 pool.close() 보장.
- **verify-r1 ⑤ trace 재생 replay**: pinned actions(canonical)를 `trace=True`로 1회 재생 — ⓐ trace
  유효성 ⓑ digest가 non-trace replay와 동일(trace 관측이 시뮬레이션 비교란) 실측. 빈-plan preflight가
  못 보는 "액션 발화 시 소실"을 인증 대상 plan 자체로 검증.
- **음성 실증(probe)**: ActionTraceDropPool(빈 plan trace 정상·액션 plan만 소실 = R4 정확 시나리오) →
  ① train_seed RuntimeError fail-closed ② 빈-plan preflight는 통과(지적 재현 = 롤아웃 검증 필수 입증).
  정상 경로 스모크: S11 seed0 trace+SIL 80 eps 클리어(회귀 0) + verify-r1/r0 PASS(trace replay 포함).

## Self-Review Round 4 (2026-07-04) — clean (HIGH 0)

- RuntimeError 전파 경로: train_seed → run_training(catch 없음) → finally pool.close() → 프로세스 비정상
  종료 = 정직 실패(manifest 미기록이 옳음 — 부분 성공 위장 없음).
- greedy 평가 rollout은 trace 미요청·shaping 미사용 — 검증 비대상이 정확.
- verify ⑤는 grammar_fails==0 && replay 성공 경로 안에서만 실행 — canon 유효성 전제 성립.
- shaped_bonus의 {} fail-safe는 잔존하되(순수 함수 방어) 학습 경로에선 롤아웃 검증이 선행해 마스킹 불가.

## Round 5 (2026-07-04) — needs-attention (MEDIUM 1 · HIGH 0)

- **[medium] Single-seed sweep artifacts are certified with the >=2/3 pass label** (train.py
  run_training) — pass_rule이 ">=2/3 seeds…"로 하드코딩돼 단일-seed 탐사 스윕 산출물(S17: seeds=[0],
  pass:true)이 pinned 3-seed acceptance와 구별 불가 = 증거 과대표시. (게이트 자체는 seeds pin으로 스윕
  산출물을 거부하므로 인증 우회는 아니나, manifest 자기서술이 fail-open.)

### 처리 (수정)
- **writer 정직화**: `pass_rule = f">={need}/{len(seeds)} seeds…"`(verify와 동일식 need) + `mode` 필드
  신설(`pinned-acceptance` iff seeds==pinned [0,1,2], else `exploratory-sweep`). 3-seed 경로의 pass_rule
  문자열은 기존과 바이트 동일(">=2/3…") — stage11/12 pinned 산출물과 자연 정합, verify 무영향.
- **S17 메타 다운그레이드**(재학습 없는 정직 relabel — run 사실과 일치): pass_rule ">=1/1…" +
  mode "exploratory-sweep". actions/결과 무변경(탐사 스윕 증거로서 유효).
- **실증**: S11 단일-seed 저장 스모크 → 신규 필드 정확(">=1/1"+exploratory-sweep) 확인 후 git 복원 →
  verify-r0/r1 PASS(pinned 산출물 비영향).

## Self-Review Round 5 (2026-07-04) — clean (HIGH 0)

- need 식이 verify `_verify_pinned`와 동일((n+(n%2)+1)//2) — 판정 이원화 없음, 집계 print에도 need 표기.
- mode 판정 기준 seeds==R0_PIN["seeds"]: R0/R1 pin 동일 세트라 단일 기준으로 충분. 스윕이 우연히
  [0,1,2]를 쓰면 pinned-acceptance로 표기되나 그 경우 예산/shaping pin은 verify가 잡음 — mode는
  가독 라벨이지 인증 필드가 아님(인증 권위=verify pin 검사 전체).
- S17 hand-edit 범위 = 서술 메타 2필드만, actions/seeds/curves 등 측정치 무변경 — 위조 아님(다운그레이드).

## Round 6 (2026-07-04) — **approve**

> Ship: no material fail-open path found in the scoped RL solver diff. The R5 evidence-label fix is
> present in the writer and S17 artifact; pinned certification still relies on independent
> seed/config/grammar/preflight/replay checks rather than the readability labels. **No material findings.**

**R1 impl-stage 종결(사후 경로)**: R1(HIGH 1·MED 1) → hot-fix `cd826dd`+음성 6종 → Self-R1 clean →
R2(MED: 검증자 실행 요구) → `cc9f1f4` live preflight → Self-R2 clean → R3(MED: trace 부재 공허 통과) →
`7d1ae6d` trace_present fail-closed+probe → Self-R3 clean → R4(MED: 롤아웃 trace 소실 침묵) →
`9a06f6e` 롤아웃 검증+trace 재생 replay+probe → Self-R4 clean → R5(MED: 스윕 라벨 과대표시) →
`93f58a5` pass 시맨틱 정직화+S17 다운그레이드 → Self-R5 clean → **R6 approve**.

# §R2 impl 사후 리뷰 (2026-07-04, base=1079481^)

## Round 1 (codex adversarial-review --base HEAD~1)
Verdict: needs-attention

- [high] verify-r2 allows pinned acceptance to pass with missing pinned seeds (train.py 결측-seed subset 허용)
  → 결측 seed를 "암묵 FAIL 집계"로만 다뤄 cherry-pick 경로(나쁜 seed 생략) 존재. 권고: 전원 기록 요구
  또는 결측의 상류-실패 근거 검증.
- [high] Transfer checkpoint provenance is verified only against mutable JSON, not checkpoint bytes
  → ckpt_loaded.sha를 chain/상류 JSON과만 대조 — 상류 ckpt "파일"의 실존·해시·내용 미검증. 위조/스테일
  JSON으로 임의 transfer 출처 위장 가능. 권고: 상류 ckpt 파일 resolve→sha 실측→load→내부
  stage/seed/cleared/digest/chain 검증(byte-backed).
- [medium] Saved checkpoint validation omits the per-stage mask digest
  → 저장 ckpt 무결 블록이 mask_digest 미대조 — exact-resume 계약 비이행 ckpt를 게이트가 인증 가능.
  권고: ck.mask_digest == mdp.mask_digest() 추가.

## Round 1 hot-fix (적용)
- HIGH-1: 결측 pinned seed = **상류 산출물의 미클리어 실증이 있어야만 허용**(from-scratch 사슬은 전원
  기록 필수) — "결측=FAIL 집계" 시맨틱은 유지하되 결측의 *근거*를 fail-closed 검증(cherry-pick 차단).
- HIGH-2: transfer 출처 **byte-backed** — 상류 ckpt 파일 실존+sha 실측(ckpt_loaded·상류 manifest 양쪽
  대조)+load 후 grammar/vocab·stage/seed/cleared_seg·layout/mask digest(상류 mdp 기준)·내부 사슬 검증.
- MED-3: 저장 ckpt 검증에 mask_digest 대조 추가.

## Self-Review Round 1 (hot-fix 자체 적대 리뷰)
- 결측-근거 로직: 상류 JSON 위조로 "미클리어 근거"를 조작해도 결측 seed는 여전히 FAIL 집계 —
  predicate 부풀림 경로 없음(근거 위조의 이득 = 0). 상류 산출물/기록 부재 = fail-closed FAIL 확인.
- byte-backed 블록은 JSON 교차 통과 후에만 진입(중복 보고 없음), 상류 mdp digest 기준값은 pinned
  cap(4500)·max_len(6)으로 학습 config와 정합(stage11/19 PASS 실증).
- 음성 실증 3종(P1 결측 무근거/P2 상류 ckpt 바이트 변조/P3 mask_digest+sha 정합 위조) 전부 검출,
  복원 PASS. verify-r0/r1 비접촉(코드 경로 분리). → HIGH 0, clean.

## Round 2 (codex adversarial-review --base HEAD~2)
Verdict: needs-attention

- [high] Missing ckpt_saved bypasses the mask_digest and byte-backed checkpoint checks
  → ckpt_saved가 dict일 때만 검증 — 항목 자체를 생략하면 파일/sha/digest/내부사슬 검사 전부 스킵
  (MED-3 픽스가 부재-fail-open). 권고: --save-ckpt가 pinned 계약인 스테이지(11/12/13)는 부재 = FAIL.
- [high] Missing-seed evidence still trusts unverified upstream JSON
  → 결측 근거로 상류 rl_meta.seeds[].cleared==false를 raw JSON에서 읽음 — 스테일/편집된 상류
  JSON으로 합성 실패 기록을 만들어 seed 생략 가능. 권고: 상류 검증을 fail-closed 공용 검사로 —
  최소한 상류 stage/config/grammar 정합 + 해당 실패 기록의 byte-backed ckpt 증거 요구.

## Round 2 hot-fix (적용)
- ckpt 파일 byte-backed 검증을 공용 helper(`_validate_ckpt_file`)로 통합(현-스테이지/transfer 출처/
  결측-근거 3경로 동일 계약): 실존+sha 실측(+대조 sha)+load 후 grammar/vocab·stage·seed·layout/mask
  digest·cleared_seg·내부 사슬.
- `R2_SAVE_CKPT_STAGES = {11,12,13}` pin 신설 — pinned 커맨드에 --save-ckpt 포함 스테이지는
  ckpt_saved **부재 = FAIL**(부재-fail-open 봉합; S19는 pinned 커맨드에 저장 없음 = 비대상).
- 결측-seed 근거 강화: 상류 산출물의 stage 바인딩/grammar/vocab digest/config 정합 + seed 중복 거부 +
  해당 seed 실패 기록의 **byte-backed ckpt 증거**(cleared_seg==False 실측) 요구 — raw JSON 신뢰 제거.

## Self-Review Round 2 (hot-fix 자체 적대 리뷰)
- 결측-근거 루프 제어흐름 검증: 상류 클리어 → 다음 상류로 continue / 기록 없음·pin 비정합 → 근거
  불인정 fail. 근거 위조는 여전히 predicate 부풀림 불가(결측=FAIL 집계 불변).
- helper 통합으로 3경로(현-스테이지/transfer 출처/결측 근거)가 동일 계약 — 계약 드리프트 원천 제거.
  expect_sha 배선(transfer=ckpt_loaded sha, 현-스테이지=말단 세그먼트 sha 별도 대조) 확인.
- 음성 실증 3종(Q1 ckpt_saved 생략/Q2 상류 근거 sha 위조/Q3 상류 config 위조) 전부 검출, stage11/19
  PASS·stage13 정직 FAIL(결측 근거는 byte-backed 인정, predicate만 미달) 회귀 확인. → HIGH 0, clean.

## Round 3 (codex adversarial-review --base HEAD~3)
Verdict: needs-attention

- [high] Checkpoint validator does not enforce the same load contract as training
  → _validate_ckpt_file이 메타데이터 필드만 검사 — dtype/model_cfg/policy·optimizer state_dict
  실재·shape 미검증. 메타데이터-온리 위조 .pt(+JSON sha 정합)가 결측 근거/transfer 출처로 통과 가능.
  권고: 검증자가 학습 로드 계약을 재사용(state_dict 실로드) + resume 직렬화 전수 필드 요구 +
  메타-온리 .pt 거부 회귀 픽스처.

## Round 3 hot-fix (적용)
- `CKPT_REQUIRED_KEYS`(직렬화 전수 계약) 상수화 — train_seed state와 validator가 같은 목록 공유,
  누락 필드 = FAIL.
- _validate_ckpt_file이 **학습과 동일한 로드 계약을 실행**: dtype·model_cfg(pinned DEFAULTS 파생)
  대조 + pinned 정책/옵티마이저 인스턴스에 `load_state_dict` 실로드(shape/key 불일치 = 예외 =
  FAIL) + torch_rng uint8 텐서 검증. 메타-온리 위조 .pt 음성 픽스처로 거부 실증.

## Self-Review Round 3 (hot-fix 자체 적대 리뷰)
- CKPT_REQUIRED_KEYS = train_seed state 구성과 대조(greedy_plan만 비필수 — 게이트 판정에 미사용,
  위조 이득 0). model_cfg 기준값 = DEFAULTS 파생(hidden/conv는 CLI 비노출 = pin의 실체) — 인증
  산출물 3종으로 정합 실증. 검증자는 전역 RNG 비오염(set_rng_state 미호출, 타입/shape 검사만).
- 음성 픽스처 2종(R3-N1 메타-온리 .pt + sha 정합 위장 / R3-N2 hidden-64 shape 위조 state_dict)
  전부 거부 + 복원 PASS. stage11/19 PASS 회귀 0. → HIGH 0, clean.

## Round 4 (codex adversarial-review --base HEAD~4)
Verdict: needs-attention

- [high] Checkpoint validation only compares internal chain stage IDs
  → ck['chain']를 stage-id 열로 축약 비교 — 내부 세그먼트의 seed/mode/cleared/ckpt_sha/path 위조가
  통과(resume/transfer 시 chain이 그대로 복사되므로 오염 전파). 권고: 신뢰 사슬(검증된 외부 JSON
  chain)과 세그먼트 전체 메타데이터 대조 + 회귀 픽스처.

## Round 4 hot-fix (적용)
- `_validate_ckpt_file`의 기대값을 stage-id 열 → **세그먼트 레코드 리스트**로 승격: 내부 chain을
  contract 키 전체(stage_id/seed/mode/episodes/batches/wall_s/cleared/ckpt_sha/ckpt_path)로
  세그먼트별 대조 + **ckpt 자기-세그먼트 결속**(seg_mode/batch_i/episodes_seg/wall_seg/cleared_seg가
  외부 사슬 말단 레코드와 일치 요구 — 내부 카운터 위조로 구간 예산 회계 우회 차단).
- 회귀 픽스처: 유효 state_dict + 내부 chain seed/mode 위조 ckpt → 거부 실증.

## Self-Review Round 4 (hot-fix 자체 적대 리뷰)
- 3 호출부 기대 사슬 배선(현-스테이지=chain / transfer 출처=chain[:-1] / 결측 근거=ue.chain — 전부
  자기-세그먼트를 말단으로 포함) 실 산출물 3종 PASS로 정합 실증. wall_s float 등가(json repr 왕복) 확인.
- 남은 신뢰 루트 = 산출물 JSON ↔ ckpt 바이트가 링크마다 상호-앵커(사슬 sha 교차 + 내부 세그먼트 전
  키 + 자기-세그먼트 결속 + state_dict 실로드) — 위조하려면 pinned shape의 실 학습 상태를 재구성해야
  하는 수준. 음성 픽스처 2종(R4-N1/N2) 검출·복원 PASS. → HIGH 0, clean.

## Round 5 (codex adversarial-review --base HEAD~5)
Verdict: needs-attention

- [high] S19 cleared-seed predicate can be forged without per-seed evidence
  → predicate가 JSON cleared 불리언 자기-보고 — ckpt 비대상(S19)에선 seed별 증거 0, top-level
  actions만 replay(출처 미결속). 권고: 클리어 seed의 greedy_plan을 seed별 replay 실증 후에만
  predicate 가산 + actions=best_seed greedy_plan 결속 + 픽스처.

## Round 5 hot-fix (적용)
- 문법 검사 helper(`_grammar_canon`) 공용화 — top-level actions와 seed별 greedy_plan이 동일
  계약(라운드트립+마스크-표현 가능성+길이).
- **predicate = 검증된 클리어만**: cleared seed마다 greedy_plan 존재 요구 + 문법 canon + 엔진
  replay(pinned deadline, cleared & saved==hp 실측) — 실패 시 그 seed는 predicate 비가산 + FAIL.
- top-level `actions` == `best_seed`의 greedy_plan(검증-클리어 seed) 결속 — 출처 불명 plan 차단.
- 픽스처: stage19 cleared 불리언 위조(+무관 top-level actions) 거부 실증.

## Self-Review Round 5 (hot-fix 자체 적대 리뷰)
- predicate가 seed별 replay 실측으로만 가산 — stage13 정직 FAIL 불변(검증-클리어 0), stage11/19
  PASS(클리어 seed 전원 replay 실증, 스테이지당 +3 replay 비용 수용). best_seed 결속은 actions 존재
  시에만(비어 있으면 별도 fail 기존재). helper 공용화로 top-level/seed-plan 계약 드리프트 0.
- 음성 픽스처 2종(R5-N1 cleared 위조=미클리어 plan replay 실측 거부 / R5-N2 top-level actions 출처
  결속 위반) 검출·복원 PASS. → HIGH 0, clean.

## Round 6 (codex adversarial-review --base HEAD~6)
Verdict: needs-attention

- [high] R2 verifier trusts unpinned config.batch for episode-budget enforcement
  → 구간 에피소드 예산 오버슛 허용치(+batch)가 산출물 자기-보고 config.batch — 부풀리면 예산 초과
  세그먼트 통과. 권고: 실효 knob 전량(batch/lr/entropy 스케줄/hidden/conv/greedy_every/
  baseline_decay) 값-pin + 오버슛은 pinned 상수로.

## Round 6 hot-fix (적용)
- R2_PIN에 실효 학습 knob 전량 편입(batch/lr/entropy/entropy_min/entropy_decay/hidden/
  conv_channels/greedy_every/baseline_decay/reward) — verify-r2가 pin 전 키를 값-대조(비-config
  키 seeds/envs/grammar 제외). 오버슛 허용 = pin["batch"](자기-보고 config 비신뢰).
- 동일 결함류 선제 봉합: R0_PIN/R1_PIN에도 같은 knob 편입(기존 extra_cfg 값-대조 메커니즘이 자동
  강제 — stage11/12 pinned 산출물은 DEFAULTS와 일치라 PASS 불변) + _verify_pinned 오버슛도
  pin 상수화.
- 픽스처: config.batch 부풀림 → pin 대조 FAIL 실증.

## Self-Review Round 6 (hot-fix 자체 적대 리뷰)
- _KNOB_PIN(batch/lr/entropy 3종/hidden/greedy_every/baseline_decay/reward)을 r0/r1/r2 pin에 공통
  편입 — 기존 pinned 산출물 DEFAULTS 일치로 4게이트 PASS 불변(강화-무회귀 실증). verify-r2 config
  대조를 pin 전 키 루프로 일반화(누락 위험 제거), 오버슛 상수 = pin["batch"]·+60s.
- 픽스처(R6-N1: config.batch 999999 + 예산 초과 세그먼트) → pin 대조와 예산 검사 이중 검출, 복원
  PASS. → HIGH 0, clean.

## Round 7 (codex adversarial-review --base HEAD~7)
Verdict: needs-attention

- [critical] Pinned stage13 R2 artifact cannot pass its own verifier
  → 커밋된 stage13.rl2.json이 pass=false·actions=null인데 독스트링이 `--verify-r2 --stage 13`을
  검증 커맨드로 광고 — 정직 FAIL 실험과 shippable 산출물의 구별 부재. (참고: 메인 execute 게이트
  (frontmatter verify)에는 verify-r2 미편입 — CI 차단은 없음.)
- [high] Checkpoint provenance is byte-backed but not repository-pinned
  → rec['path']를 그대로 resolve — 절대경로/저장소 밖 경로 허용, chain 메타에 절대 D:\ 경로 잔존
  (비이식). 권고: `ckpt_path(sid,seed)` repo-상대 정본 경로 강제 + 기존 메타 정규화.

## Round 7 hot-fix (적용)
- [critical] 광고/문서 정합: 독스트링 verify 예시를 `--stage {11,19}`(인증 산출물)로 교정 +
  stage12/13 rl2.json = acceptance 2 FAIL의 **정직 박제 기록**(verify-r2 거부가 기대 동작)임을
  독스트링·plan §R2 실측 결과에 명시. FAIL 조작(재생성 강제·박제 삭제)은 plan "silent 재스코프
  금지"에 반하므로 채택하지 않음 — 구별은 문서+rl_meta.pass가 담당.
- [high] `_validate_ckpt_file`에 **정본 경로 pin**(rec.path == ckpt_path(sid,seed) repo-상대,
  이탈 거부) + chain 세그먼트·ckpt_loaded의 ckpt_path 정본 검사 + `_ckpt_segment` 경로 _rel 정규화
  (forward) + **기존 ckpt/rl2 메타 마이그레이션**(절대경로 → repo-상대, sha 연쇄 재계산: S12 ckpt
  3개 → S13 ckpt → 산출물 사슬 기록).

## Self-Review Round 7 (hot-fix 자체 적대 리뷰)
- 정본 경로 pin이 3경로(rec 해석·chain 세그먼트 메타·ckpt_loaded)를 전부 커버 — 절대경로/이탈/임의
  로컬 파일 공급 우회 차단. 마이그레이션 후 stage12/13 정직 FAIL의 사유가 predicate/pass/actions
  **만**임을 실측(무결-오류 0 = sha 연쇄 재계산 정합; stage12 seed2 클리어는 replay-실증 1/3 반영).
- CRITICAL 처리 방식 검토: FAIL 산출물 재생성/삭제는 plan 정직-박제 원칙 위반 — 문서 정합(독스트링
  게이트 예시 교정 + plan 산출물 상태 명시)이 정공법. 메인 verify 게이트 비편입 재확인(CI 차단 없음).
- 픽스처(R7-N1 절대경로) 검출·복원 PASS, stage11/19 PASS. → HIGH 0, clean.

## Round 8 (codex adversarial-review --base HEAD~8)
Verdict: needs-attention

- [high] Checkpoint verification does not prove optimizer state is usable
  → opt.load_state_dict는 attach만 — Adam 슬롯 텐서(exp_avg/exp_avg_sq) shape/dtype 오염 ckpt가
  통과하고 첫 재개 opt.step()에서 크래시. 권고: 파라미터별 슬롯 검증 또는 dummy step + 픽스처.

## Round 8 hot-fix (적용)
- _validate_ckpt_file에 **optimizer 슬롯 전수 검증**: 파라미터별 exp_avg/exp_avg_sq shape·dtype
  일치 + step 카운터 존재 + param_groups lr == pinned — attach-만 통과하는 재개-불능 위조 거부.
- 픽스처: exp_avg shape 오염(+정합 sha 재기록) ckpt → 거부 실증.

## Self-Review Round 8 (hot-fix 자체 적대 리뷰)
- 최초 구현("슬롯 부재=위조")이 **실 ckpt에서 거짓양성** — Adam lazy 초기화: 스테이지에서 활성
  불가능한 head(S11의 col 등)는 그래프 밖 = 슬롯 없음이 정상이고 그 resume은 lazy 재초기화로 기능
  (실측으로 잡음). 계약 정정 = **존재 슬롯의 shape/dtype 정합**(진짜 재개-크래시 위험)만 fail-closed +
  step 존재 + 파라미터-범위 + lr pinned. 빈-state 위조는 기능적으로 재개 가능하므로 이 검사의 관할
  아님(학습-됨 여부는 카운터·사슬 결속이 별도 강제) — 근거 코드 주석 박제.
- 픽스처(R8-N1 exp_avg shape 오염+sha 정합 재기록) 거부·복원 PASS, stage11/19 PASS. → HIGH 0, clean.

## Round 9 (codex adversarial-review --base HEAD~9)
Verdict: needs-attention

- [high] Malformed torch RNG state can pass checkpoint verification but break exact resume
  → torch_rng 검사가 uint8·non-empty만 — 1바이트 텐서로 교체(+sha 재기록)하면 verify 통과 후
  --resume-ckpt의 set_rng_state에서 즉사. 권고: set/restore 왕복(전역 RNG 복원) 또는 정확 길이 대조.

## Round 9 hot-fix (적용)
- _validate_ckpt_file이 **set_rng_state 실왕복** 실행: old 저장 → set(tr) try/except → finally
  restore(old) — 로더와 동일 계약, 전역 RNG 무오염. 픽스처(1바이트 uint8 RNG) 거부 실증.

## Self-Review Round 9 (hot-fix 자체 적대 리뷰)
- set/restore 왕복이 로더와 동일 계약(실측: 1바이트 위조 → "size 5056 기대" RuntimeError 거부),
  finally 복원으로 검증자 전역 RNG 무오염(verify는 어차피 학습 RNG 미사용이지만 위생 유지).
- 픽스처 거부·복원 PASS, stage11/19 PASS. → HIGH 0, clean.

## Round 10 (codex adversarial-review --base HEAD~10)
Verdict: **approve** — "No ship-blocking fail-open, forgery, or verifier-bypass path found."
(codex 권고 런타임 확인 = verify-r2 --stage 11/19: 검증자 측에서 기실행 PASS — 아래 종결 스윕.)

## §R2 impl 리뷰 루프 종결 (2026-07-04)
- 경로: codex R1(2H+1M) → R2(2H) → R3(1H) → R4(1H) → R5(1H) → R6(1H) → R7(1C+1H) → R8(1H) →
  R9(1H) → **R10 approve**. 누적 = CRITICAL 1·HIGH 11·MED 1 전부 hot-fix(9커밋), 매 라운드
  자체리뷰 clean + 음성 픽스처 실증(누적 ~20종).
- 종결 스윕(전부 그린): verify-r0(3/3)·verify-r1(2/3)·verify-r2 stage11(3/3)/stage19(3/3)·
  coverage r1.1·coverage r2.1 — stage12/13은 정직 FAIL 박제(무결-오류 0, 사유=predicate/pass/actions).

## §R3 impl 리뷰 (2026-07-05) — trace-refinement MDP

### Round 1 (codex adversarial-review, working-tree) — verdict: needs-attention (HIGH 2·MED 2)
- **[HIGH-1] exec digest가 stage 파일 미해시(추정)** — *오탐*. codex가 `:02d`를 `:03d`("stage013.tres")로
  오독. 실측 반증: `data/stages/stage13.tres` 등 존재·content 해시(stage13 exec digest ≠ stage11).
  → **인접 유효점 채택**: `_exec_config_digest`가 스테이지 리소스 누락 시 `FileNotFoundError`(silent None 금지).
- **[HIGH-2] verify_r3가 자기보고 `throughput.floor_reached` 신뢰** — *유효*. 위조 floor_reached=true로
  under-budget FAIL을 legit model_fail로 위장 가능(replay 스킵 경로라 특히 위험). → **수정**: `_floor_reached()`
  = raw 카운터(episodes_completed/distinct_prefix_rollouts) 재계산. verify_r3가 산출물 bool과 대조(불일치
  FAIL) + outcome을 재계산 floor로 재판정. train_seed도 동일 헬퍼로 회계.
- **[MED-3] obs_schema_digest가 rasterize 시맨틱 미결속** — *유효*. 채널/스칼라 이름·분모만 pin →
  clamp·state→채널 매핑·마커·물사 로직 변경이 digest 불변(ckpt/산출물이 비호환 obs로 통과). → **수정**:
  rasterize를 순수 함수 `rasterize_channels/rasterize_scalars`로 추출 + 고정 합성 (layout,trace,res)의
  `_obs_golden()` 벡터를 obs_schema에 결속. 시맨틱 변경 = golden 변경 = obs_schema_digest 변경.
- **[MED-4] R3 ckpt가 `.r2.pt` 경로 재사용 → R2 ckpt 덮어씀** — *유효·파괴적*. `--refine --save-ckpt`가
  추적된 `stage13_seed2.r2.pt`(R2 byte-backed) 덮어씀 실측 확인. → git 복구 + **수정**: `ckpt_path(refine=True)`
  = `.r3.pt`. run_training r3 저장이 이 경로 사용.
- **자체 적대 리뷰(수정 후) clean**: floor 재계산·ckpt 경로·golden 결속·fail-closed 인접 전부 정합, 회귀 0.

### 수정 후 재검(전부 그린)
- verify-r3(S13, mode=primary, outcome=pass, 3/3, telescoping OK) + **음성 9/9 검출 + 복원 PASS**
  (refine_false·trace_channels·obs_digest·memo_members·off_grid·nonpinned_seed·max_len·floor_tamper·
  outcome_forge). floor_tamper 음성이 HIGH-2 수정 실증.
- 회귀 0: coverage-r2·verify-r0(3/3)·verify-r1(2/3)·verify-r2(S19 3/3) PASS(기존 frame byte-identical).
- 결정론: memo(on vs --no-memo) byte-identical·재개 등가성(refine, 파라미터 비트동일+곡선 일치) PASS.
- 산출물 재생성: stage13.rl3.json(new obs digest) + stage13_seed{0,1,2}.r3.pt(3/3 클리어, 결정론 동일 해).

### Round 2~6 (codex 재리뷰 — verify_r3 fail-closed 조이기, 매 라운드 자체리뷰 clean + 음성 확장)
- **R2 (1 MED)**: verify_r3가 `exec_config_digest` 재계산만 하고 값 미대조. → 재계산 digest == 산출물 대조
  (rollout 의존 drift/위조 fail-closed) + 음성 `exec_digest`.
- **R3 (2 MED)**: (a) exec digest가 raw `GODOT_BIN` env(미설정 시 빈 문자열, find_godot 폴백 미반영) →
  `str(Path(find_godot()).resolve())` 바인딩·fail-closed. (b) verify_r3가 mode=primary에 variant/trace_blind
  미강제 → variant↔mode + `config.trace_blind` falsy 강제 + 음성 `variant_masq`/`trace_blind_masq`.
- **R4 (2 MED)**: (a) 선택 경로↔mode 미결속(dense 아티팩트 primary 경로 복사 통과) → 선택 경로가 기대
  mode/variant/pin 결정(self-report pin 선택 폐기) + 음성 `mode_masq`. (b) `ckpt_saved` 생략 시 ckpt 검증
  침묵 스킵 → `rl_meta.save_ckpt` 플래그 계약(true=seed별 필수·false=부재 필수) + 음성 `ckpt_strip`.
- **R5 (2 MED)**: (a) `trace=True` replay 에러 침묵 통과(`"error" not in rt2` 조건) → error 명시 FAIL.
  (b) ckpt가 seed/경로 미결속 → 정확 경로(`_rel(ckpt_path(stage,seed,refine=True))`) + `_ckpt_compat(resume)`로
  seed/stage/grammar/vocab/layout/mask/model_cfg 대조 + 음성 `ckpt_crossseed`.
- **매 라운드 사이 자체 적대 리뷰 clean** + 산출물 재생성(R2·R3·R4는 digest/save_ckpt 필드 변경으로 재학습;
  전부 3/3 결정론 동일 해). 수정 후 스윕: verify-r3 PASS + 음성 **16/16 검출 + 복원 PASS** +
  회귀 0(verify-r0/r1/r2·coverage-r2·memo 결정론·재개 등가성).

### Round 6 (1 MED) — plan-pin 모순 → **사용자 표면화 → plan 개정(AND) 결정**
- codex 권고: `_floor_reached()` model_fail 인증을 OR→**AND**(episodes≥3000 **및** distinct≥1500)로.
- plan §R3가 THROUGHPUT_FLOOR를 명시적 "또는"(OR)로 pin했으므로 impl 임의 변경 불가 → **사용자 표면화**
  (AskUserQuestion, OR/AND 트레이드오프 설명). **현재 영향 0**(전 seed PASS라 floor 로직 dormant).
- **사용자 결정(2026-07-05) = AND**: MIN_DISTINCT의 pin 근거("해 공간 격자 하한 = 실패라 말할 자격이 되는
  최소 탐색 커버리지")와 정합. → `_floor_reached` AND + **plan §R3 텍스트 개정(또는→AND)** + 음성
  `floor_single_axis`(5000ep/100dist claiming floor_reached=true → AND면 미도달 → 대조 FAIL).

### Round 7 (1 MED) — verify_r2 §R2-R5 패턴 미계승 → 수정
- codex: verify_r3의 n_clear가 seed별 자기-보고 `cleared` bool 신뢰 + replay는 top-level plan만 검증
  (multi-seed predicate replay-미실증). verify_r2는 이미 `verified_clear`로 강화된 표준.
- **수정**: seed별 `greedy_plan`을 `_grammar_canon` + 엔진 replay(pinned deadline, saved==hp)해 **실증된
  것만** `verified_clear`에 가산 → `n_clear=len(verified_clear)`. outcome/mechanical_pass는 verified_clear
  파생. top-level `actions == best_seed.greedy_plan` ∧ `best_seed ∈ verified_clear` 결속. 음성
  `seed_evidence_forge`(2 seed cleared=true·greedy_plan 제거 → verify FAIL).

### Round 8 — **approve (no material findings)** = impl 리뷰 루프 종결
- verdict=approve("Ship: no remaining material fail-open or correctness gap"). 매 라운드 사이 자체 적대
  리뷰 clean + 음성 픽스처 **18종** 누적 전부 검출 + 복원 PASS.
- **8 라운드 요약**: R1(실버그 3 — 파괴적 ckpt 덮어쓰기·false-green)·R2~R5·R7(verify fail-closed 조이기
  = exec digest 대조·godot resolve·A/B 경로격리·ckpt seed결속·trace error·predicate replay실증)·
  R6(plan-pin OR→AND 사용자 결정). CRITICAL 0·HIGH 2(R1, 전건 수정)·MED 다수(전건 수정).
