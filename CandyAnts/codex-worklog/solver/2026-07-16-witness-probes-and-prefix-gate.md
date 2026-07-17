# 미해결 4종 witness 전원 확보 + prefix 의미론 게이트 (2026-07-16 밤 ~ 07-17)

> 선행: [2026-07-16-offline-unresolved-test.md](2026-07-16-offline-unresolved-test.md) "다음 세션 진입점" 1~4를
> 같은 날 밤 전부 이행. **결과: 미해결(레지스트리 미등재) 5종 중 S10·S18·S21이 사상 첫 해 확보,
> S23은 grid-정렬 재구성으로 prefix 재투입 가능, S25는 연장 런 진행.** train.py에 prefix 의미론
> fail-closed 게이트 신설(codex 6R).

## 결과 요약

| 항목 | 결과 |
|---|---|
| 1. S25 연장 런 | `--max-batches-overrides "25:400"` attempt03 실행(이 문서 작성 시점 진행 중, ~3.2h 예상) |
| 2. S23 witness grid-정렬 | `stage23.witness_grid.json` — 3중 검증 PASS(리플레이 7/7 · 왕복 fixpoint 0 · 왕복 리플레이 7/7) |
| 3. train.py prefix 게이트 | 구현 완료, codex R1~R5 HIGH 4건+MEDIUM 1건 전부 수정, 회귀 13종 그린 |
| 4. witness probe | **S18 5/5(8액션) · S21 7/7(3액션, probe #1 즉중) · S10 5/5(10액션)** — 3종 전부 사상 첫 해 |

## §1 train.py --prefix-plan 의미론 fail-closed 게이트 (코드 수정, codex 6R)

07-16 §1 후속 1의 구현. 원래 목적(S23형 밴드-붕괴 위증 차단)에서 codex 라운드를 거치며 검증 계약이
"**정책이 실제로 도달 가능한 클리어 completion의 존재 증명**"으로 강화됨:

1. witness **전체** 인코딩(잔여 포함) + `len(pacts) ≤ mdp.max_len` (R2 HIGH-1)
2. **마스크-표현 가능성**: `_grammar_canon`과 동일한 head_mask 워크(슬롯 순서·used 인벤토리 추적) —
   cell-전용 스킬의 mode:"ant" 위장 등 정책이 생성 불가능한 액션 거부 (R4 HIGH)
3. **전체 왕복 플랜**(`decode_plan(encoded_all)`)을 `solve.run_plan`으로 리플레이 — 원본이 아니라
   왕복본이 학습이 도달할 대상 (R2 HIGH-1)
4. deadline = `args.train_deadline` (witness 자체 deadline 금지 — 학습 지평 밖 클리어 위증 차단, R1 HIGH)
5. PASS 조건 = `cleared AND saved == mdp.hp` (게임 cleared는 부분 회수에서도 참 — S18 니어-해
   cleared=true saved=4/5가 실증 반례, R3 HIGH)
6. `report_fired`로 **prefix 인덱스 0..k-1 전부 발화** 검사(잔여만으로 클리어되는 죽은 prefix 거부,
   R2 HIGH-2). 잔여 미발화는 경고만
7. 기형 JSON(최상위 배열·null actions·빈 cell 등)도 traceback 아닌 rc=2 정규 거부 (R5 MEDIUM)

회귀 13종(전부 실측): 오염 원본 witness rc=2 / deadline 컷(2000) rc=2 / max_len 초과 rc=2 /
죽은 prefix rc=2 / 부분 클리어(S18 니어-해) rc=2 / sand_mound mode:ant 마스크 밖 rc=2(리플레이 전 즉시) /
기형 4종 rc=2 / S23·S18·S21·S10 정식 witness PASS.

**R6~R11(07-17): 리플레이 견고성 심화 → R11 approve 종결.** R6부터는 전부 MEDIUM(HIGH 0)으로
`solve.run_plan`의 opt-in timeout 경로 정리 견고성 연쇄:
- R6: wall-clock timeout 부재(엔진 행 시 게이트가 sweep.lock 쥔 채 영구 블록) → `run_plan(timeout=)`
  opt-in 파라미터(기본 None=기존 호출자 byte-identical) + 게이트 600s.
- R7: 정리 경로 자체의 대기/고아(taskkill 반환 무시·무한 wait·POSIX 직계만) → `_kill_tree()` 헬퍼
  (taskkill 15s 상한+rc검사→proc.kill 폴백 / POSIX killpg / reap 10s 상한 / 무블록 보장).
- R8: 중간 부모(run_test) 선종료 시 죽은 PID 기준 정리가 godot 손자를 못 잡음 → **Windows Job
  Object(KILL_ON_JOB_CLOSE, ctypes)** 로 후손 수명을 부모 PID와 분리 + POSIX는 getpgid 조회 없이
  `killpg(proc.pid)`(start_new_session 보장 pgid). 회귀 = 부모-선종료+손자 파이프 보유 시나리오 실측.
- R9: Popen 후 편입이라 "편입 전 부모 선종료" 경쟁 잔존 → **CREATE_SUSPENDED → 편입 → Toolhelp
  ResumeThread** 로 편입이 실행보다 항상 선행 + 잡 생성/편입/재개 실패 = fail-closed. 회귀 = 부모-선종료
  10회 반복 손자 잔존 0. (부수 버그 자기발견: ResumeThread 실패 판정이 c_int -1 vs DWORD 비교 오류)
- R10: 셋업(Popen/편입/재개) 중 예외가 정리·error dict를 우회 → 단일 try/except/finally 소유권
  경계(handoff 플래그). 회귀 = Popen 예외·resume 예외 주입 → 무예외 error dict + suspended proc 누수 0.
- **R11: approve** ("no material adversarial finding remains").

교훈: "리플레이 1회로 위증 차단"이라는 단순 아이디어도 프로세스 수명 관리가 얽히면 6라운드 분량의
엣지(행→고아→부모선종료→경쟁→예외 경로)가 나온다. 전부 opt-in 경로라 기존 pinned 재현성은 불변.

부수: `scripts/run_test.py`+`tools/solver/env.py`에 `suppress_crash_dialogs()` 신설 — Godot 4.6 헤드리스가
SOLVER_RESULT 출력 후 셧다운 중 간헐 access-violation으로 죽을 때 Windows WER 모달이 부모 파이썬을
블록하던 것을 SetErrorMode(자식 상속)로 억제. 판정 권위는 stdout 마커라 결과 무영향.

## §2 S18 "동굴 탐험" — 첫 완주 해 (niear-해 + max_x carry가 정답)

`data/solutions/stage18.witness.json` (8액션: floater + blocker×2 + climber×5).

- 니어-해(휴리스틱 40롤 포화 saved 4/5) 재현 → trace 판독: **5번째 운반자(ant7)가 candy 플라토
  좌단 col9 벽에 막혀 반전 → 우단 col18 낙하 → 물 익사**. 귀환 성공자들은 climber로 col9 벽을 넘음.
- 휴리스틱 carry 후보가 `select=min_x` 하드코딩(model.py:573)이라 picked_ge 5 시점에 이미 무장된
  좌측 운반자만 재선택 — **잔여 climber 1개가 최우측(=5번째) 운반자에게 영영 전달 안 됨** =
  "후보 공간 밖"(STATUS 5d① DEFER 사유)의 실체.
- 해 = 니어-해 + `climber max_x carrying picked_ge 5` 1액션. 8액션 > max_len 6 →
  prefix 시 `--max-len-overrides "18:8"`.
- **model.py 후속 과제**: carry 후보에 max_x 축 추가(1줄 수준) — S18을 휴리스틱 자동발견권으로
  가져올 개연. 코드 수정이라 별도 리뷰 트랙.

## §3 S21 "어디로 내려가지?" — 첫 해, probe #1 즉중 (3액션)

`data/solutions/stage21.witness.json` (sand_mound + slideL + blocker — 인벤토리 5 중 3 사용, max_len 이내).

- **핵심 발견: slideL/slideR = 하강 램프가 아니라 절벽 대각 상승 계단 빌더**
  (`WorkerState._place_one_tile` up-first, 정지 조건 = 전방-아래 지형 + 전방 빈칸 = 같은 높이 평지 도달).
- 경로: ① mound SIGN (15,14) — 우측 슬래브 밑 4 rung + cap-onto-ledge(S24 needle 동형, 사다리=영구
  지형이라 전 개미 통행) ② slideL — 슬래브 첫 도착 개미를 좌향 전환, col14 절벽에서 상승 계단이
  candy 플랫폼(row5)과 같은 높이에서 자동 정지·접속 ③ blocker — 슬래브 우단 물낙사 차단.
  귀환 = 플랫폼 좌단 낙하(3행)→중간렛지→낙하(3행)→홈렛지, 개입 0.
- 07-14 §3 주가설(cap-onto-ledge 니들+순차 결합) 실증 — 단 렛지는 좌측(cols3-7)이 아니라 **우측 슬래브**.

## §4 S10 "보물찾기!" — 첫 해 (10액션, 인벤토리 정확 소진, probe 5회+미세조정 4회)

`data/solutions/stage10.witness.json`. 07-14 §1 주가설(다단 순차 조합) 실증. 확정 경로와 gotcha는
witness note에 상세 박제. 핵심만:

- leaf_jump 패드 = **재사용 장치·1개미 직렬 처리**(busy ~90f)·전방 4칸 내 착지 바닥 없으면 발동
  거부(can_apply) — 물골2(매시프 벽으로의 점프)는 원천 불가.
- slideR 상승 계단이 (9,10) 절벽→공동 입구 (12,7) 정확 접속(S21과 같은 메커니즘, 대칭 방향).
- digger SIGN은 **col19(챔버 좌벽 col18 인접)**가 관건 — col20 굴착은 picked 5/5여도 climber가 잡을
  벽면이 없어 전원 감금(P4 실증). (19,7)은 plant 절단 후에야 설치 가능 → at_frame 900 지연.
- cutter/digger는 r2.1 마스크에서 **cell 전용** — mode:ant 무장 형태는 리플레이는 통과하나 정책 생성
  불가(마스크 워크가 잡음). cell SIGN 형태가 정본.
- climber 릴리스 = max_x carrying + at_frame 600f 간격(1200~3600): min_x는 무장 여행자 재선택으로
  간격 붕괴, 300f는 트립 편차(굴착공 클라임 대기열)에 잠식 — 패드 직렬 처리와 충돌해 saved 4/5 고정.
- digger는 무장/도착 즉시 수직 굴착(스폰 무장 시 홈 바닥 관통 전원 추락사, P3) — 위치 고정 필수.
- 클리어 f4746 → prefix 시 `--train-deadline 9000` + `--max-len-overrides "10:10"` 필요
  (스윕 RECIPE의 4500으론 게이트가 거부 — 러너에 train-deadline 오버라이드 부재, 후속 배선 필요).

## §5 후속 이행(07-17 오전): model.py carrymax 축 + 러너 train-deadline 배선 — S18 자동발견 완결

§2 후속 과제("carry max_x 축")를 같은 날 이행. **witness → 휴리스틱 보강 → 자동발견의 완결 사례.**

- `model.py` carry 후보에 `%s@carrymax%d`(select=max_x) 추가. **1차 동일-가중안은 S13 rediscover
  회귀**: carry{n}-min 채택 후 다음 라운드에 dup-가드로 빠진 min{n} 순번에서 carrymax{n}이 선평가,
  carry{n+1}-min과 점수 동률 시 선평가자 채택 → min-체인 오염(cleared는 유지되나 pinned 시그니처
  불일치). "동률 시 min 선평가라 경로 보존" 판단의 오류 — 순서 보존 ≠ 점수-동률 채택 차단.
  → 가중을 min 블록 전체보다 엄격히 아래(`-cnt`)로 강등: min 진척 중엔 평가 순위 밖, min 정체·
  Phase B(빔=frontier 순위, 가중 무관)에서만 기여.
- 실증: rediscover-verify **5/5 PASS**(S4/13/19/20/22 — S13 26롤 pinned 시그니처 복원) +
  **S18 휴리스틱 자동발견 SOLVED 2회 연속**(Phase B depth3, 220/223롤,
  floater+blocker×2+climber×5 — 어제 witness로 수동 확보한 해를 오늘 솔버가 스스로 발견) →
  `stage18.solve.json` 신규 pin(최종 가중 코드로 재생성) + `EXPECTED_SOLVE_STAGES` 18 등재 →
  **selftest 20/20 PASS**(stage18 replay f2380).
- `sweep_stages.py --train-deadline-overrides "10:9000"` 배선(기존 오버라이드 4종 동일 패턴:
  파스 fail-closed + 지문 결속 + RECIPE in-place 교체). 파스·지문 유닛 PASS. S10 prefix 투입 준비 완료.
- 교훈: 후보-공간 확장은 "기존 경로와의 동률"이 최대 리스크 — rediscover-verify가 정확히 그걸 잡았다.
  가중 설계는 "새 후보가 기존 채택과 경쟁 불가능한 위치"가 안전 기본값.
- **codex 배치 리뷰 R1~R6 → R6 approve**: R1(hp=7 절단 매몰 → `_ensure_carrymax_quota` bounded +1)
  → R2(채택된 carrymax의 조기 항등 → live=미채택만) → R3(LA2 base2 오판 → live 기준을 speculative
  베이스로, `cellup_base` 선례 동일 인자) → R4(스냅샷 비원자 → 트랙 15파일 스테이징 / 임시 유닛 →
  `_selfcheck_carrymax_quota` 게이트 박제) → R5(생성부 미검증 → ⓖ 행동 검증: 실제 propose 호출 +
  **변이 테스트**로 max_x→min_x 파손 검출 입증) → R6 approve. 최종 게이트 = selfcheck(ⓐ~ⓖ) +
  재발견 5/5 rc=0. quota 계약 = "min 블록이 절단을 채워도 base-미포함 최상위 carrymax 1개는 항상
  평가 도달"(main eval·LA2 모두).

## 다음 세션 진입점

1. **S25 연장 런 판독**(attempt03, 이 세션에서 완료 예정) — bestR 0.477 돌파 여부.
2. **witness-prefix 스윕 재투입**: S23(k 재시도, witness_grid) · S18(`18:8` max-len) · S21(그대로) ·
   S10(`10:10` + train-deadline 9000 — 러너 오버라이드 배선 선행).
3. model.py carry 후보 max_x 축 추가(§2) — S18 휴리스틱 자동발견 재도전.
4. 레지스트리 등재는 RL 발견 해만 대상(witness는 힌트) — 정책 유지.
