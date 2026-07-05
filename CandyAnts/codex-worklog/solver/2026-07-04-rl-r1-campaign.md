# RL R1 캠페인 세션 로그 (2026-07-04) — trace-shaped 보상 + S25까지 스윕

> 사용자 지시: ① S12에서 멈추지 말고 **stage25까지 클리어 목표로 계속 진행** ② 학습 wall 예산
> **최대 30분(1800s)/run** (기존 7200s에서 하향) ③ **중요 발견·이슈는 본 로그에 전부 박제**.
> plan SoT = `phases/solver/auto-solver-plan.md` §R1·§R1-스윕. 게이트/acceptance와 별개의
> 발견 기록(정직 박제 — 실패도 데이터).

## 발견 (설계 단계)

- **F1 · S12 prefix 단조성 실측 (plan §R1 grounding 박제)**: known 해 prefix별 shaped bonus가
  엄격 단조 — 빈 plan `goal_d=19 retired=8 → +0.206` / blocker#1 `goal_d=6 retired=7 → +0.351` /
  #1+#2 `goal_d=6 retired=0 → +0.439` / #1+#2+#3 `+0.490+cleared`. **goal 항 단독으론 #2에서
  plateau(6→6)** — retired(7→0) 항이 그 구간을 구별한다. **w_retired는 옵션이 아니라 필수.**
- **F2 · 학습 deadline 함정 (자기-발견)**: 격자-인코딩 S12 해 클리어 frame=**2981** vs R0 학습
  cap **3000f** — 19프레임 차. 근사-해 변형이 학습 중 전부 timeout으로 읽혀 최적점 근방에서
  cleared 보너스가 굶는 구조. → `--train-deadline` 신설, R1 pinned=4500. (판정 replay는 7000 불변.)
- **F3 · plan-review 3R**: R1(HIGH: R1_PIN under-pin) → R2(HIGH: train_deadline 미pin + MED:
  preflight 증거) → **R3 approve**. 교훈: "학습-전용 knob는 pin 비대상"(R0 원칙)도 **plan이 스스로
  material하다고 입증한 knob(train_deadline)은 예외** — pin 대상.

## 이슈

- **I1 · max_len=6 표현 함정 (스윕 선결)**: R0 기본 슬롯 cap 6이 S14(known 해 = blocker3+climber5 =
  **8액션**)·S15(7)·S18(8)·S20(7)·S25(ant 8)의 known/필요 해를 **표현 자체를 못 함**. → `--max-len`
  CLI 신설, 스윕은 스테이지별 `min(ant 인벤토리 합, 8)` 사용. (S12 acceptance는 known=3이라 무영향,
  R1_PIN 비대상 — manifest로 추적.)
- **I2 · 인벤토리에 cell-target 혼재 (스윕 선결)**: S21~S25 인벤토리에 sand_mound(cell) 포함 —
  R0 mdp는 인벤토리 전체를 스킬 head로 썼음(S11/S12는 blocker-only라 잠복). 그대로면 정책이
  "sand_mound를 ant 모드로 발동"하는 무효 액션을 학습 공간에 갖게 됨 → StageMDP에 **메타 덤프 기반
  ant-target 필터**(D7 하드코딩 0) 추가. ant-target 0인 스테이지(S19=sand_mound만)는 명시 에러 = SKIP.
- **I4 · Godot 좀비 프로세스 누적 (Windows)**: F5 재실행 시점에 Godot 헤드리스 **24개** 잔존 발견
  (이전 실행들의 EnvPool이 hard-kill 시 미정리 — PlanServerHarness의 "클라이언트 끊김→quit"이
  Windows pipeline kill에서 안 탐/못 탐). `--fixed-fps`라 전속 스핀 = CPU 잠식 → **1차 실행의 낮은
  처리량(3.7 eps/s)에 기여했을 가능성**. 조치: taskkill 전체 정리 + 이후 학습 전 프로세스 카운트
  확인 습관화. (동일 계열 선례: 5g beam stretch "잔류 프로세스 정리".)
- **I5 · `| tail` 파이프 + 백그라운드 조합의 무출력 실패**: F5 probe 1차 시도가 exit 0·출력 0바이트로
  끝남(원인 미상 — 좀비 자원 경합 의심). 파이프는 exit 마스킹(기지)에 더해 **출력 유실**도 가능 —
  이후 학습 실행은 **무파이프 + `python -u`**(스트리밍)로 표준화.
- **I3 · S11 스모크에서 관측된 preflight base**: 빈 plan 600f preflight의 digest가 `hp=-1`(deadline
  verdict) — R0에서 알려진 PlanRunner 보고 관례(보상 분모는 상수라 무해). 스윕 로그 해석 시 참고.

## S12 acceptance (pinned, wall 1800s/seed)

- 커맨드: `python tools/solver/rl/train.py --stage 12 --seeds 0,1,2 --envs 4 --max-episodes 20000
  --max-wall 1800 --shaping trace --train-deadline 4500`
- 음성 대조: 동일 grammar·예산(20k eps, wall 7200)에서 `shaping none` = **0/3 FAIL**(`dc68a47`).
- 선행 확인: verify-r0 리팩터 회귀 PASS / **S11 shaping 비파괴 스모크 PASS**(seed0, 240 eps 클리어,
  trace preflight 8런 identical wall=1.67s, `--no-save`로 산출물 격리) — acceptance item 3·4 일부 선충족.
- **1차 결과 (r0.1 문법 + entropy_min 0.005): 0/3 FAIL** — 3 seed 전부 wall 1800s 소진(~6.7k eps/seed,
  trace 오버헤드+deadline 4500으로 ~3.7 eps/s), bestR=0.231 plateau.

### F4 · S12 1차 FAIL 원인 규명 (probe 2회 — 가설 아닌 실측)
- **bestR=0.231 = "blocker#1 + 즉시 SUBMIT"의 정확한 값**(+0.351 bonus − len 0.02 − timeout 0.1) —
  즉 **1단은 발견·수렴 완료**. 문제는 2단 이후.
- **b1은 needle이 아님**: y밴드 불요·state 무관·col 0~2 전부 +0.351 (넓은 basin).
- **마지막 단의 실체**: **#3(col6-7, min_x le)의 y밴드(row6)만 필수** — #1·#2 밴드 불요, 순서 무관,
  #2 col 17-18 OK/19 FAIL. **b3(col5) 변형 = picked=5·saved=0·+0.376** (픽업 성공·회수 실패의 중간 신호
  존재 — self-imitation 후보).
- **동역학 병목 = 길이-1 국소최적**: len(−0.02)·timeout(−0.1) 페널티 하에서 entropy가 0.005까지 감쇠
  → 2번째 슬롯 탐험 사멸 → b1+b2(+0.299)에 20k 샘플 동안 **0회 도달**. terminal shaping은 "샘플된
  것의 기울기"만 제공 — **조합 자체의 샘플링은 탐험 유지가 담당**해야 함을 실증.

### F5 · 처방 (2026-07-04, 원인-일치 수정 2건)
1. **문법 r1.1 — y_row 어휘 = layout-파생 surface rows**(any + 개미가 설 수 있는 행만): S12 head
   18→5, S11 18→3. D7-충실(레이아웃 관측 파생, 해 힌트 아님) + 비표면 행 밴드는 공집합 매칭이라
   어휘 손실 없음. 커버리지 재검 PASS(known 해 인코딩 불변).
2. **entropy_min 0.005→0.02**(지속 탐험 바닥 — 길이-1 수렴 차단): fallback 1(계수/하이퍼 튜닝) 관할,
   manifest로 추적. ⚠ GRAMMAR_VERSION 승격으로 기존 `stage11.rl.json`(r0.1)이 verify-r0에서 stale
   처리됨 — R0 pinned 커맨드로 재생성 예정(정직 절차).
- 재실행: seed 0 단독 30분 probe → 성공 시 3-seed pinned 본실행.

### F6 · fallback 1 (r1.1+entropy 0.02) probe = FAIL — 사다리는 오르나 수렴이 안 됨
- seed0 30분(7.2k eps): bestR **0.231→0.279(2액션 돌파)→0.447(픽업-부분 rung 도달)** — r1.1+엔트로피
  바닥이 탐험 사멸은 해소(1차의 0.231 고정과 대비). 그러나 batch 150~450 내내 bestR 0.447 정체·
  meanR 0.19 — **희소 고보상 에피소드가 배치 평균(16개)에 희석돼 정책이 그 경로에 커밋을 못 함**.
- 처방 = **fallback 2: self-imitation(SIL)** — top-K(8) 에피소드 buffer, (R−baseline)+ 가중 재모방
  (`--sil`, sil_coef 0.1). 정확히 "희소 발견 → 커밋" 병목의 표준 처방. probe 재실행.
- 부수 확인: 좀비 정리 후 처리량 회복(preflight wall 1.67→0.59s, ~4 eps/s).

### F7 · fallback 2 (SIL) probe = **S12 CLEAR** ✅ (2026-07-04)
- seed0, 4320 eps(~23분): **GREEDY CLEAR saved=5/5 frame=2130** — known 해(2981f)보다 **851프레임
  빠른 해를 무힌트로 발견**(RL이 휴리스틱 해와 다른/더 나은 조합을 찾음 = 학습 트랙의 첫 질적 성과).
- 수렴 동역학(모니터 실측): meanShape 0.224→0.287→0.310 단조 상승 = SIL이 buffer 방향으로 정책 평균을
  견인 → rung 커밋 후 다음 rung 탐험 확률 급증 → 클리어. fallback 1의 "발견은 되나 커밋 안 됨"과 대비.
- 결론: **R1 최종 레시피 = trace-shaped 보상 + surface-row 문법(r1.1) + entropy 바닥 0.02 + SIL** —
  세 실패 모드(기울기 없음 → 탐험 사멸 → 커밋 실패)를 각각 하나씩 해소한 합.
- 계약 이행: pinned 커맨드 `--sil` 편입, R1_PIN에 sil=true·sil_buffer=8·sil_coef=0.1 갱신(동일 커밋).
- 다음: 3-seed pinned 본실행 → verify-r1 → stage11.rl.json 재생성(문법 r1.1) → S13~ 스윕(`--sil` 포함).

### F8 · S12 acceptance **PASS** (pinned 3-seed, 2026-07-04) ✅
- **2/3 seed 클리어**: seed0 = 4320 eps·1377s·frame 2130 / seed2 = 3200 eps·1188s·frame 2239 /
  seed1 = 미클리어(5744 eps·1800s 소진, bestR 0.447 — SIL로도 seed 운에 따라 30분 내 미수렴 사례 존재,
  predicate ≥2/3의 존재 이유). 산출물 `stage12.rl.json`(best=seed2), **verify-r1 PASS**(replay ×2
  byte-identical, saved==5). seed2 수렴 후 meanR 1.53 = 정책 대부분이 클리어-근방 plan을 샘플.
- **음성 대조 대비**: 동일 문법-이전(r0.1)·terminal-only(R0) = 0/3(20k eps 완주) vs 최종 레시피 = 2/3
  (3~4k eps) — 다단 credit assignment이 보상·탐험·커밋 3축 수정으로 뚫림 = **R1 가설 실증 완료**.

### I6 · verify 예산 검사의 경계 시맨틱 버그 (fail-closed 게이트가 잡음)
- `_budget_left()`는 배치 **시작 전** 검사 → 마지막 배치+greedy 평가가 경계를 넘김(seed1 wall
  1804/1800) → verify-r1 FAIL. **게이트가 의도대로 작동해 발견된 실제 계약 모호점** — 오버슛 허용
  (에피소드 +batch / wall +60s)을 명문화해 해소, 재검 PASS. 에피소드 예산도 동형 문제 선제 수정.

## R1-스윕 S13~S25 (단일 seed 0, 30분 cap, 비게이트)

| Stage | 인벤토리(ant-target 표현성) | 결과 | eps/wall | 비고 |
|---|---|---|---|---|
| S13 | blocker1+climber5 (전부 ant) | **FAIL** | ~3.5k eps/1800s | bestR 0.660 plateau(batch~100부터) — 부분 진척(픽업 디딤돌 계열) 후 정체. 휴리스틱은 26롤 해결(carry 연쇄) — carry-climber ×5 조합이 30분 단일 seed론 미조립. FAIL best-plan 덤프는 S15+부터 |
| S14 | blocker3+climber5 (전부 ant, known 해 8액션) | **FAIL** | 8.3k eps/1800s | bestR 0.370 저위 plateau — blocker×3 계단(S12 동형)+carry×5까지 겹친 최장 조합, 초반 rung도 못 넘음. 휴리스틱 40롤 대비 격차 최대 |
| S15 | climber5+floater2 (전부 ant, 휴리스틱 해 7액션) | **FAIL** | 10k eps/1800s | bestR 0.449 = **floater 1개(safe_fall)** 길이-1 국소최적에 SIL 커밋(FAIL best-plan 덤프 첫 활용). 생존 신호가 sub-goal 사다리 없이 plateau |
| S16 | blocker3+floater1 (전부 ant, 휴리스틱 해 4액션) | **FAIL** | 5.6k eps/1800s | bestR 0.540 — **blocker×3 밴드 조합까지 조립**(S12급 진척), 마지막 floater 1개 미완. 30분 예산선 바로 밖의 아까운 실패 |
| S17 | blocker4 (전부 ant, 피라미드+천장) | **CLEAR** ✅ | 3.76k eps/~24분 | saved 5/5 **frame 2403 — 휴리스틱 해(3367, 천장 휴리스틱 2건 신설 필요했던 레벨)보다 964f 빠른 신해 무힌트 발견**. `stage17.rl.json` 산출 |
| S18 | blocker2+climber5+floater1 (전부 ant) | 중단(세션 마감) | 7.8k eps/1100s 시점 | bestR 0.358 저위 plateau 중 세션 종료로 중단 — 데이터 무효 아님(18분 관측: S14 유사 프로파일) |
| S19 | sand_mound2 (**전부 cell-target**) | **SKIP** (설계대로) | 즉시 | ant-target 필터의 명시 ValueError = 문법 비표현 정직 기록(I2 가드 실작동 확인). cell-target 어휘 = R2 |
| S20 | bridge2+climber5 | 미실행 | — | 세션 마감(스윕 중단 시 kill로 잘림 — 시도 기록 무효) |
| S21 | blocker2+bridge1+slideL1(+sand_mound1) | 미실행 | — | 〃 |
| S22 | blocker2+bridge1+floater1+slideL/R(+sand_mound2) | 미실행 | — | 〃 |
| S23 | blocker2+bridge2+floater1(+sand_mound2) | 미실행 | — | 〃 (휴리스틱 witness는 sand_mound 필수 — 현 문법으론 클리어 불가 예상) |
| S24 | blocker2+floater1+slideL/R(+sand_mound2) | 미실행 | — | 〃 (S24 needle = sand_mound 침투 사다리 — 현 문법 비표현 예상) |
| S25 | blocker2+bridge2+floater2+slideL/R(+sand_mound4) | 미실행 | — | 〃 |

### 세션 마감 요약 (2026-07-04, 사용자 지시로 여기서 종료)
- **스코어보드**: R1 acceptance **S12 PASS(2/3 seed)** + 스윕 **S17 CLEAR**(둘 다 휴리스틱 해보다 빠른
  신해) / S13·S14·S15·S16 FAIL(30분 단일 seed) / S19 SKIP(문법) / S18 중단 / S20~S25 미실행.
- **패턴(정직 결론)**: 현 레시피는 **≤4액션 조합**(S11 1·S12 3·S17 4)을 30분 내 뚫는다. 5액션+
  (carry 연쇄 S13/S15, 8액션 S14)는 미돌파 — best-plan 덤프 실측: 길이-1~3 국소최적에 SIL 커밋.
  다단 carry-연쇄는 **에피소드-내 신호는 단조인데 조합 폭이 예산을 초과** — R2 후보(curriculum:
  부분 인벤토리 사다리 / dense per-prefix shaping / 예산 상향)로 이월.
- **다음 세션 재개 지점**: ① impl-stage codex adversarial-review(자체리뷰→codex 루프) — 본 세션은
  acceptance·게이트 검증까지만 완료 ② 스윕 잔여 S18(재실행)·S20~S25 ③ R2 스코프 결정(cell-target
  어휘 + curriculum이 잔여 스테이지 열쇠).
- **프로세스 이슈(I7)**: 백그라운드 sh 루프가 TaskStop에 안 죽고 자식 kill마다 다음 스테이지로 전진
  (S20~23 시도 기록이 kill에 오염 → 무효 처리). 교훈: 스윕 중단은 **sh(루프) → python → Godot 순**
  으로, 커맨드라인 매칭 kill. 사용자 에디터 Godot(비콘솔)는 보존 확인.

- 휴리스틱 트랙 대비 기대치: S21/23/24/25는 beam 미돌파(witness 수기·S24 needle은 sand_mound 필수 =
  현 문법 비표현). RL 30분 단일 seed가 못 풀어도 기대 위반 아님.

---

## 후속 세션 (2026-07-04 오후) — impl 리뷰 종결 · 스윕 재스코프 · R2 방향 확정

### impl-stage 사후 리뷰 종결 (재개 지점 ①)
- codex R1(HIGH: verify-r1 문법 인코딩 미검증 + MED: preflight 위조)→R2(MED)→R3(MED)→R4(MED)→R5(MED)→
  **R6 approve**. hot-fix 5커밋(`cd826dd`/`cc9f1f4`/`7d1ae6d`/`9a06f6e`/`93f58a5`), 매 라운드 자체리뷰
  clean. 상세 = `phases/solver/reviews/phaseR-impl-review.md` §R1. 게이트 최종 형태: 문법 라운드트립 +
  live trace preflight + 롤아웃 trace 검증 + trace 재생 replay + pass 시맨틱(mode 필드).

### 스윕 재스코프 (재개 지점 ② — 사용자 결정으로 축소)
- **S20~S25 취소**: 사용자 지적 — 캠페인 스테이지는 단계별 학습(curriculum)을 전제로 설계된 시퀀스라
  from-scratch 전수 스윕은 구조적으로 불리한 시험이고, "전체 스테이지" 성능 시험은 R2 이후가 맞다.
  잔여 6개 중 4개(S21/23/24/25)는 sand_mound 필수 = 현 문법 비표현 기지이기도 함. from-scratch
  베이스라인은 R2 설계 확정 후 필요 스테이지만 온디맨드 재측정(스테이지당 30분).
- **S18만 재실행**(지난 세션 중단 재측정 채무): 드라이버 스윕 시작 ~10분 시점에 사용자 결정 → 드라이버
  트리 kill(I7 순서 준수, godot/train 잔존 0 확인) 후 **단독 프로세스로 처음부터 재기동**(부분 측정 오염
  제거). 결과는 표의 S18 행을 대체한다.

### R2 방향 (재개 지점 ③ — 사용자 지시 2026-07-04)
- **가중치 저장/로드 = R2 필수 요건**: "학습 결과를 저장/로드하지 않으면 제대로 된 강화학습이 아니다"
  (사용자). 현 구조의 정직 진단 — 산출물은 plan(해)뿐, 정책망은 프로세스 종료 시 폐기·재실행 시 0에서
  재학습. 단 현 아키텍처는 obs_dim/head가 스테이지 파생이라 가중치를 저장해도 **타 스테이지 로드 자체가
  불가능** → 영속화가 의미 있으려면 스테이지-불변 아키텍처(공유 인코더+통일 어휘)가 선결 = R2 본체.
- R2 스코프 축 4개(초안, plan §R2로): ① 가중치/optimizer/RNG 체크포인트(1급 산출물) ② 스테이지-불변
  정책(공유 CNN 인코더, 액션 어휘 통일+스테이지 마스킹) ③ cell-target 어휘(S19/S23/S24 열쇠) ④
  campaign-순서 curriculum(이전 체크포인트에서 계속 학습).

### S18 재실행 결과 (2026-07-04 후속 세션) — FAIL (완주 측정, 표의 S18 행 대체)
- 단독 프로세스, pinned 스윕 커맨드(`--seeds 0 --max-wall 1800 --shaping trace --train-deadline 4500
  --sil --max-len 8`): **12,000 eps/1800s 완주, bestR 0.358 정체**(batch ~100대부터 종료까지 불변) —
  지난 세션 중단 관측(18분 시점 0.358)과 동일 프로파일의 완주 확정.
- best plan 덤프 = **floater 1개**(safe_fall, max_x/le 1080/row11) — S15와 동일한 "생존 신호 길이-1
  국소최적에 SIL 커밋" 실패 계열. blocker2+climber5+floater1 조합(다단 carry 포함)은 30분 from-scratch
  예산 밖 재확인.
- **R1-스윕 최종 스코어보드**: S12 acceptance PASS(2/3) / S17 CLEAR / S13·S14·S15·S16·S18 FAIL /
  S19 SKIP(문법) / S20~S25 취소(사용자 — curriculum 관할). 이 표가 §R2의 from-scratch 베이스라인.
