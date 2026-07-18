# S25 witness probe → 구조적 UNSOLVABLE 규명 (2026-07-17)

> 선행: [2026-07-16-witness-probes-and-prefix-gate.md](2026-07-16-witness-probes-and-prefix-gate.md) "다음" ①
> (S25 attempt03 판독) + witness-prefix 스윕 4종 준비. attempt03(400b×3seed) 0/3·0.562 공유 어트랙터로
> "S25도 witness 확보 선행 대상" 결정 → 본 세션에서 probe 수행. **결론: witness 부재 — 현 인벤토리로
> 클리어 불가능한 레벨(설계 결함)이다.**

## 방법
- `tools/solver/solve.run_plan`(엔진 헤드리스, 결정론, trace+report_fired)로 후보 플랜 재생 → 개미별 셀-궤적
  판독. 임시 probe = `scratchpad/p25.py`(플랜 JSON 인자 → 결과 헤더 + per-ant end/carry/extent + full path).

## 레벨 구조 (cell 48px, +Y down)
- **spawn = home = (19,4)** (`Home.gd get_spawn_position`, 오프셋 −5px 무시가능). spawn_dir=−1.
- **home 박스 = 완전 밀폐**(프로그램 검증): 천장 row1 cols14-20 · 바닥 row5 cols14-20 · 좌벽 col14 rows1-5 ·
  우벽 col20 rows1-5 전부 solid, 내부 cols15-19 rows2-4만 빈칸. 빈손 개미는 박스 안 floor(row5)에서
  x[15,19] 무한 왕복(empty-plan trace 실측).
- candy=(11,13) 중앙 분지(row14 floor cols6-15, 벽 col5/col16 @row13). home과 분리.
- 인벤토리 = blocker2·bridge2·floater2·sand_mound4·slideL1·slideR1. **타일 파괴 스킬(basher/digger/cutter)
  없음.** hp=7, 개미 10, deadline 7000.

## 핵심 메커니즘 규명 (엔진 실측)
1. **박스 탈출 = sand_mound 상향 mantle (일방통행)**: `sand_mound (15,4)` 배치 → 개미가 내부 rung
   (15,4)(15,3)(15,2) climb 후 **천장 위로 cap-mantle** → (15,0) walk. 천장 top(row0, cols14-20)으로 나옴.
   그러나 **하강 불가**: 모든 trace에서 개미는 (15,0)→(14,0)→col13 낙하로 진행, **단 1회도 (15,2)로
   되내려가지 않음**. (15,1) 등 천장이 연속 solid라 col15에 "내려갈 ledge"가 없음(mantle은 up-only).
2. **DeadState = 영구 기절**: `STUN_FALL_CELLS=5` — floater 없이 ≥5칸 낙하 시 DeadState(터미널, 스테이지
   끝까지 stun, 회복 없음). 천장 top→중앙 언덕(row8)은 **7~8칸 낙하 = 즉사**. 무개입 escape는 전원 기절사.
3. **floater = 분배자**(`FloaterSkill`): 지면 개미에 적용→그 자리 영구 정착(개미 1 소모)+SettlementMarker가
   **지나가는 모든 개미에 floater 트레잇 분배**(낙하 1회 안전). 실측: 천장 top에 floater 1개 → 후속 9개미
   전원 col13 낙하 생존. → 대량 안전낙하 가능(설계 의도 스킬).
4. **하강 경로 존재**(candy까지): floater로 천장낙하 생존 → 중앙언덕 → blocker 우향 반전 → col14 낙하 3칸
   → row11 플랫폼(14,10) → col13 낙하 3칸 → 분지(13,13) → candy(11,13). **즉, candy 픽업 자체는 가능**
   (라우팅 blocker 2 + floater 1 + sand_mound 1). *단 본 세션에선 픽업 직전까지만 확인* — 아래 이유로 무의미.

## 결정적 사실 = **RETURN(배달) 기하학적 불가능**
- 배달 = 운반 개미가 home(19,4) = **밀폐 박스 내부 floor**에 물리 도달해야 함(Home Area2D = 72×24px,
  박스 floor에 위치 → 천장 top 4칸 위에선 트리거 불가, 실측 확인).
- 박스 재진입로 = **오직 sand_mound 사다리 cap 뿐인데 그게 일방통행(상향)**. 천장이 연속 solid라
  어떤 스킬도 하향 통로를 못 뚫음(인벤토리에 타일-파괴 0; bridge/slide/sand_mound는 타일 **추가**만).
- (probe 범위 내) escape 후 개미가 박스 내부 **천장 경유** 재진입 = 0건. picked_total도 전 probe 0.

## ⚠️ 결론 정정 (2026-07-17, 사용자 인게임 실증으로 **UNSOLVABLE 철회**)
- **S25는 풀린다.** 사용자가 인게임에서 직접 클리어 실증(스크린샷 **SAVED 6·LOST 0**, CANDY HP 1 잔여,
  사용 인벤토리 = sand_mound×3 + bridge×1 + floater×1 + blocker×1). 앞선 "구조적 UNSOLVABLE" 판정은
  **오류** — 내 분석이 박스 **천장** 경유 탈출/재진입에만 매몰돼 **바닥(floor) 아래에서의 재진입**을 검토
  안 함.
- **놓친 메커니즘 = sand_mound 바닥-관통 재진입**: home 박스 floor(row5, cols14-20) 3칸 아래 row8 플랫폼
  (cols16-22)에 sand_mound를 세우면, rung(row7,row6) + **cap이 박스 floor 타일(예 (19,5))을
  LADDER_TIER_TOP으로 reskin**(`_can_cap_ledge`→`reskin_cell_to_ladder`) → 운반 개미가 **바닥을 뚫고
  올라 home(19,4) 진입 → SAVED**. 스크린샷 우측의 수직 사다리(박스↔하단 플랫폼)와 정합. sand_mound cap은
  천장뿐 아니라 **어떤 solid 면이든 위로 관통**(위→아래 아니라 아래→위 진입)이 핵심.
- 즉 앞서 확립한 것(escape=sand_mound 상향 mantle / 하강=floater 분배자+blocker 라우팅으로 3칸 계단 →
  분지 → candy)에 **바닥-관통 sand_mound 재진입**을 붙이면 완주. 배달 경로는 실재.
- 부수 확인된 메커니즘(유효): DeadState=영구기절(≥5칸 낙하 STUN_FALL_CELLS=5), floater=분배자(1개로 다수
  안전낙하·개미1 소모), LadderClimbState=상승전용(단 cap-reskin된 사다리 셀은 climb-up 진입로가 됨).

## 저장 정책 (사용자 지시, 2026-07-17)
- **이 해는 휴리스틱 트랙에만 귀속. RL은 참조 금지 — "해가 존재한다"는 사실만.**
  - **`data/solutions/stage25.witness.json` 생성 금지**(witness = train.py `--prefix-plan`의 RL 참조
    아티팩트). S25를 **witness-prefix 스윕에 절대 편입하지 말 것**(현 스윕 4종=S10/18/21/23에 S25 없음, 유지).
  - RL 관점 = S25는 여전히 **자력 발견 대상**(UNSOLVABLE 아님·힌트 없음). 레지스트리 등재는 RL 발견 해만.
  - 휴리스틱 쪽 활용은 별개(model.py에 바닥-관통 재진입 routing 추가 시 자동발견 가능 — 후속 과제, RL과 무관).

## 산출물 (probe 단계)
- probe 단계 코드/데이터 변경 없음(임시 스크립트는 scratchpad). **witness.json 미생성**(RL 오염 방지).

## 휴리스틱 솔버 자력풀이 개조 (2026-07-18, 사용자 지시 "solver가 S25를 풀게")

> 사용자 결정: witness 저장 대신 **휴리스틱 솔버가 S25를 자력 발견**하게(RL은 여전히 미참조).
> 병목 규명 후 3개 개조 + 1 버그수정. **회귀 0 검증**(rediscover-verify S4/13/19/20/22 byte-identical).

**병목 규명(실측)**: S25 baseline은 **0 candidates**(솔버가 시작조차 못 함). 원인 = ① 밀폐 박스 개미는 낙하
가장자리가 없어 `reverse_targets`=0 ② 탈출은 **위로**(candy는 아래 row13) 가야 하는데 cell-up(`wall_targets`)이
**goal-above 게이트**라 하향-목표 상향-탈출을 미제안. → floor-breach가 아니라 **비단조 상향 탈출**이 진짜 첫 병목.

**개조 3 + 버그 1 (`tools/solver/model.py`·`solve.py`):**
1. **`_escape_targets`**(model.py) — 밀폐(전방-solid 벽 반전 + 낙하 가장자리 전무 + 미픽업) 개미의 벽-기저 셀을
   cell-up 소스로 추가(goal-above 예외). diagnose에서 **reverse/wall 타깃 전무일 때만**(마지막 수단) 산출 →
   기존 스테이지 byte-identical. propose ③에 `escape` 소스 편입.
2. **`_deliver_below_targets`+`_home_enclosed`**(model.py) — **밀폐 home**(바닥 solid AND 위 ≤4행 천장) 아래
   플랫폼의 운반 개미 grounded 셀(위 2~3행 solid=cap 대상)을 cell-up 소스로. 평지라 `wall_targets`가 못 잡는
   바닥/플랫폼 관통 상승을 연다. `_home_enclosed` False(열린 home)면 미산출 → byte-identical. propose ③에
   `deliver` 소스 편입.
3. **force_la2 escape 고정**(solve.py 채택부) — 밀폐 baseline(escape_targets 존재)이면 첫 라운드 그리디를
   건너뛰고 **LA2 강제**. 그리디는 retired-우선 score 때문에 *소심한* 탈출(개미 안 죽지만 진척 0)에 lock-in하고
   *생산적* 탈출(candy 근처 도달하나 floater 없어 낙사)을 기각하는데, LA2 frontier=goal_dist 최근접이라 생산적
   탈출을 고르고 second-step에서 floater를 얹어 **escape+floater 쌍**을 조립. `not plan`(첫 라운드) AND
   escape_targets 게이트 → 비밀폐 스테이지 byte-identical.
4. **버그수정 `_home_enclosed` 탐색폭 range(1,3)→(1,5)** — S25 천장(row1)이 home(row4) **3행 위**라 기존
   ≤2행 검사로는 `_home_enclosed(S25)=False` → **deliver-below가 내내 비활성**이던 결함. 수정 후 True·deliver
   후보 산출 확인.

**단위 검증**: `model._selfcheck_escape_deliver()`(ⓐ밀폐탈출 검출+게이트 ⓑreverse 있으면 미산출 ⓒ밀폐 바닥관통
검출 ⓓ열린home 미산출 ⓔ미운반 미산출) 신설 + `rediscover-verify`에 편입.

**성과(실측)**: escape 개조로 S25가 **0 candidates → reached=7**(개미 7마리 전원 candy 픽업). force_la2 전엔
reached=1이 한계였다. **메커니즘 전구간 엔진 실증**: 탈출(sand_mound 천장-관통 mantle) + 하강(floater 분배자+
라우팅) + 픽업(reached=7) + **바닥-관통 배달**(별도 probe: 개미가 (19,7)→(19,4) home 진입 확인).

**미완**: full `saved=7` 자동클리어는 **미달**. 남은 벽 = 운반 개미의 **home-향 상승 라우팅**(분지→row11→row8→
(19,7) breach). deliver-below가 (15,13) 후보는 내나 채택 경쟁서 좌측(막다른) 분지 사다리에 밀리고, row11 플랫폼
상 운반 개미 **방향 제어**(col16~18로 우향)가 blocker 예산(2개, 하강에 소진) 안에서 안 풀림. 사용자 실제 해는
blocker1+bridge로 더 효율적 — 미재현. → **개조는 실질 capability 향상(회귀0)이나 S25 완주는 상승-라우팅 추가 과제.**

## solve.json 정책
- 자동클리어 미달이라 **stage25.solve.json 미생성**(정직: 솔버가 아직 못 풂). RL 격리 유지(witness/prefix 없음).
