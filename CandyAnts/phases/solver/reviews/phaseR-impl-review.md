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
