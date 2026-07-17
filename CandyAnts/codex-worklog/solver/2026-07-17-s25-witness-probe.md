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
- **실측 확증**: escape 후 개미가 박스 내부(cols15-19, rows2-5) 재진입 = **0건**(전 런). picked_total도
  전 런 0. RL attempt03 400b×3seed도 picked_total 0(0.562 = "천장 도달" shaping뿐).

## 결론
- **S25는 현 인벤토리로 saved>0 불가 → 클리어 witness가 존재하지 않음.** 이는 solver-capability 갭
  (S21/S24처럼 "beam은 못 풀지만 손witness는 됨")이 **아니라** 레벨 자체의 **구조적 결함**:
  home이 일방통행 출구뿐인 밀폐 박스에 있어 사탕 회수 후 배달 경로가 물리적으로 없음.
- 정합 근거: beam "유효 후보 0"(STATUS §5g) · 사용자 잠정 "못 깬다고 봐야"(STATUS beam 결론) · RL 0/3.

## 수정 옵션 (사용자 결정 필요 — 레벨 디자인)
1. **박스에 재진입 가능한 개구부**: 천장/벽 1칸 제거하거나 사다리를 양방향(정적 sand_mound 지형)으로 —
   왼쪽 "눈" 박스(col5에 정적 sand_mound 사다리 보유)처럼 home 박스도 통행 가능하게.
2. **인벤토리에 타일-파괴 스킬**(basher/digger/cutter) 추가 → 천장 뚫어 재진입.
3. **home을 박스 밖(도달 가능 지점)으로 이설**.
- 어느 쪽이든 **레벨 재설계**라 사용자 승인 후 진행. 재설계 시 위 하강 경로(floater 분배자 + blocker
  라우팅)가 candy 접근 witness의 뼈대가 됨.

## 산출물
- 코드/데이터 변경 **없음**(probe만, 임시 스크립트는 scratchpad). solve.json/witness.json 미생성(해 없음).
- witness-prefix 스윕 4종(S10/18/21/23)은 S25와 독립 — 별도 진행 가능(본 probe는 S25만 종결).
