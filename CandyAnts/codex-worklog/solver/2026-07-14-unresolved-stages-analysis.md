# 미해결 스테이지 심층 분석 — S10·S18·S21·S25 (2026-07-14)

> 선행: [2026-07-13-sweep-fail-analysis.md](2026-07-13-sweep-fail-analysis.md) (2차 스윕 12 FAIL 유형 분류).
> 본 보고서 = 그 후속. 07-13 스윕(S17~25)·오늘 엔진 실측(replay+trace, D4)으로 **잔여 미해결 4개
> (S10·S18·S21·S25 — 등재 해·witness 전무)** 를 스테이지별 원인 추정→추정 근거→해결안→해결 근거로
> 심층 분석하고, 과정에서 발견된 **보상 정규화 결함(total_ants 분모 버그)** 을 실증과 함께 등재한다.
>
> 방법론: 모든 주장에 엔진 실측을 우선(D4 — 추측 금지). 사용 도구 = `scripts/run_plan.py`
> (베이스라인 빈 플랜 + RL best plan을 `trace:true`·`report_fired:true`로 리플레이) +
> `tools/solver/model.py` 순수 함수(레이아웃 파싱·`best_goal_dist`·`blocker_redirect_value`) +
> `mdp.py` 보상 공식 오프라인 재계산.

> **⚠ 2026-07-14 실전 후속 갱신 (커밋 `b6b9eba`, 다른 PC 무인 스윕)**: 본 보고서 작성 후 도구①②③
> 실전 학습 런이 돌았다. 결과가 §0 표와 replay-검증 해석을 일부 **정정**한다:
> - **S20 SOLVED 3/3**(max_len=7·300배치): "문법천장이 유일 장벽" 가설 **확증**.
> - **S24 SOLVED 2/3**(witness-prefix k=2): §3(07-13)의 witness curriculum 권고 **실전 첫 성공** —
>   6액션 해 2종 등재(`hint{k:2}` provenance). ※S24는 total_ants 분모버그 영향 스테이지지만 클리어는
>   엔진 검증(D4)이라 등재 해 유효 — 버그가 클리어를 막지 못함(§4.1과 무모순).
> - **S15 1/3**(max_len=7·500배치): seed2 해 첫 등재. max_len 필요 + 예산 상향 필요.
> - **S14 0/3 FAIL**(max_len=8): **max_len은 필요조건이나 불충분** — blocker×3 후 carry 연쇄 미조립
>   (탐색·신용할당 장벽, solve.py 예측솔버가 score 2-fix로 넘은 바로 그 지점). **이 세션 초의
>   "replay 5/5 → max_len 오버라이드 가설 확정"은 과했다** — replay는 *해가 길이 7/8에 존재*만
>   증명하지 *RL이 발견*을 보장하지 않는다(S20만 순수 천장, S14는 별도 장벽).
> - **S23·S18·S10 무진척**(prefix k=3 / stall-any 60): 보조격발·부분 prefix만으론 부족.
> → 아래 §0 표의 "S14/15/20 = max_len 오버라이드"·replay-검증 함의는 이 결과로 대체(S20 완료,
>   S14 장벽 잔존, S15 예산 이슈). 상세 = STATUS.md "실패 분석 후속 도구 실전 검증 착수" 절.

## 0. 현황 정정 — 12 FAIL의 현재 상태 (2026-07-14 기준)

07-13 스윕 이후 상태가 갈렸다. 잔여 작업 대상을 먼저 고정한다.

| 분류 | 스테이지 | 상태 | 다음 액션 |
|---|---|---|---|
| 해 등재됨(문턱만 미달) | S6·S9·S17 | 레지스트리에 클리어 해 실재 | attempt02(seeds 3,4,5) 저비용 재시도 — 07-13 보고서 §4 그대로 |
| witness/solve 실재·**현 레벨 유효 검증 완료(오늘)** | S14·S15·S20·S23·S24 | **replay 5/5 전부 cleared**(아래 표) | S14/15/20 = max_len 오버라이드 스윕(8/7/7), S23/24 = witness-prefix curriculum |
| **진짜 미해결(해 미확보·solvability 미검증)** | **S10·S18·S21·S25** | 본 보고서 §1~4 | 스테이지별 상이 — §6 우선순위 |

오늘 replay 검증(전제 확립 — 07-13 보고서 §6 권장 1번 실행 결과):

| 파일 | 결과 | 액션 수 | 함의 |
|---|---|---|---|
| stage14.solve.json | cleared saved 5/5 f4624 | **8** | max_len=6 초과 확정 |
| stage15.solve.json | cleared saved 5/5 f2635 | **7** | 〃 |
| stage20.solve.json | cleared saved 5/5 f1869 | **7** | 〃 |
| stage23.witness.json | cleared saved 7/7 f2375 | 5 | 표현 가능한데 못 찾음 = 순수 탐색 실패 재확인 |
| stage24.witness.json | cleared saved 7/7 f2072 | 4 | 〃 (+§4.3 분모 결함 기여 의심) |

부수 규명(부록 A): S17·S20·S21·S23·S24·S25의 attempts.jsonl level_digest가 로컬과 불일치했으나,
**전부 HEAD 콘텐츠의 CRLF 변형과 정확 일치** — 레벨 내용 불일치가 아니라 크로스PC 개행 차이.
07-13 스윕 데이터는 현 레벨 콘텐츠에 대해 유효하다(단 digest의 EOL 민감성은 개선 대상, 부록 A).

---

## 1. S10 "보물찾기!" (Ch5 종합) — 베이스라인 즉몰 + 다단 조합 해 + 문법 한계 개연

스테이지 상수: total_ants 5 · candy_hp 5 · 150s · 인벤토리 {slideR 1, climber 5, cutter 1, digger 1, leaf_jump 2} = 10개.
구조(레이아웃 실측): 스폰·홈 좌측(1,11~12), **물웅덩이 2개**(col5 폭1 · cols10-11 폭2, rows13-16),
우측 대형 매시프(cols12-23) 상단 플랫폼(rows3-4) 아래 내부 공동(rows5-7)에 **plant 기둥(cols17-19)** 과
**물 포켓(cols20-22, row7)**, 최하부 공동(rows10-11, cols19-22)에 candy(21,11).

### 원인 추정
① **베이스라인 전멸**: 무개입 시 전 개미가 첫 웅덩이(col5)에 익사 — 어떤 부분 진척도 없는 상태에서 학습 시작.
② **해 미확보**: witness/solve 전무(stage10.rl2.json은 actions=0 빈 파일) — solvability 자체 미검증.
③ **[주가설 — probe 대상] 필요 해가 다단 순차 조합**: 인벤토리 구성이 시사하는 경로 —
leaf_jump×2(웅덩이 2개 통과) → 매시프 등반/진입 → cutter(plant 기둥 절단 하강) → digger(공동 진입
굴착) → climber×N(회수 체인). 성립 시 스킬 종류 4~5종·액션 수 ≥7 → max_len=6 표현 밖.
단 이는 레이아웃·인벤토리에서 유도한 **가설**이지 입증이 아니다 — cutter/digger의 필수성, climber
필요 수, slideR 우회(하강 전용 경사로라 동일 높이 1칸 갭 통과에는 부적합 개연이나 **미검증**) 배제를
witness probe가 판정해야 한다.
④ **RL 신호 부재 + 구제 미발동**: bestR 0.31~0.34 3-seed 동결(픽업 0의 goal-shaping 고원),
governor dup_share 0.02~0.03으로 stall 미격발(다양-고원 공백 — 07-13 §3과 동일 메커니즘).

### 추정 근거
- 엔진 실측(빈 플랜 trace): 5마리 전원 x[1..5]에서 종료, 최종 셀 (5,13)=웅덩이 내부, f713 no_more_ants.
- 엔진 실측(RL best plan seed1 replay): picked_total 0 · saved 0 — RL 최고점도 웅덩이조차 못 넘음.
- 로그: 3 seed bestR 0.310/0.340/0.310, batch 40~150 완전 동결. stall 이벤트 = blocked_first(SIL 차단)뿐.
- 레이아웃·인벤토리 대응: bridge/floater/blocker 부재로 낙하 안전화·역주행 유도가 불가한 인벤토리 —
웅덩이 통과의 정공은 leaf_jump(점프대)로 보이나, ③에 적었듯 slideR 우회 배제는 미검증(주가설의
일부로 probe가 판정).

### 해결안
1. **witness 확보 선행**(RL 예산 투입 금지 — 07-13 §3 원칙): (a) 수동 probe — leaf_jump 배치→웅덩이
통과 검증부터 엔진 트레이스로 단계 구축(S24 witness 확보 방법론 재사용), 또는 (b) 휴리스틱
`try_solve search` — 단 model.propose에 leaf_jump(jump)/digger(down)/cutter(break) routing 확장 필요
(현재 S8 계열 NO-PROPOSE 이력).
2. witness 길이 L 확정 후: L>6이면 `--max-len-overrides "10:L"` + `--prefix-plan/--prefix-k` curriculum.
3. `--stall-any-batches 60` 보조 격발(전 스테이지 공통 — §5).

### 해결 근거
- witness→curriculum은 §15 v2.1에서 "관건=정답 발견 비용"으로 정식화된 문제의 정공법이고, S15
seed1 니어클리어(6액션에서 3.42)가 "표현·발견 비용만 문제"인 사례의 실증.
- 오늘 replay 5/5로 witness replay 파이프라인 자체는 검증 완료 — witness만 서면 이후 단계는 기계적.

---

## 2. S18 "동굴 탐험" (Ch1 기초) — 베이스라인 낙사 전멸 + 국소최적 동결 + 문법 한계 개연

스테이지 상수: total_ants 8 · candy_hp 5 · 100s · 인벤토리 {blocker 2, climber 5, floater 1} = 8개.
구조: 스폰·홈 좌상(1,6), col5에서 8행 낙하 절벽, 미로형 내부(정적 sand_mound 사다리 3개), candy(16,5)
우상단, 물(cols13-16, rows15-16) 우하단.

### 원인 추정
① **베이스라인 전멸**: 전 개미가 col5 절벽에서 8행 낙하 → 착지 사망(f847 no_more_ants).
② **국소최적 동결**: 3 seed가 **동일 플랜**(floater min_x @600 — "1마리 안전낙하")에 bestR 0.396으로
수렴·동결. dup_share 0.02~0.05로 stall 미격발.
③ **완성 해는 7~8액션 개연 + 휴리스틱은 후보 공간 한계로 포화**: 휴리스틱 트랙 최종 기록
(STATUS 5d①, 2026-06-25)은 `--max-rollouts 80`까지 실행해 **40롤에서 포화** — best plan =
floater+blocker×2+climber×4(**이미 7액션**) saved 4/5 고정, 5번째 개미 물 익사(carry5 추가 불변),
1·2-스텝 lookahead 진척 0. 결론은 "**cap 문제 아님 — model.py 휴리스틱 손질 필요**"로 박제됨.
니어-해가 7액션이므로 완성 해의 max_len=6 초과 개연은 실측으로 지지되나, 마지막 한 수(5번째 익사
해소)는 현 휴리스틱 후보 공간 밖이다.

### 추정 근거
- 엔진 실측(빈 플랜 trace): 8마리 전원 x[1..5]·y[6..14], 최종 (5,14) fall 상태로 소멸.
- 로그: bestR 0.396 3-seed 동일값·동일 플랜(select/state 필드까지 사실상 일치) — 어트랙터의 전형.
- 휴리스틱 이력(STATUS.md 5d① S18=DEFER 절): cap80 실측·40롤 포화·saved 4/5 고정 — "cap 부족"
가설은 **이미 반증**됨(초기 Option C의 "37/40롤 cap 더 필요" 판독을 후속 실측이 뒤집음).

### 해결안
1. **니어-해 기반 수동 witness probe(최우선)**: 박제된 7액션 니어-해(floater+blocker×2+climber×4,
saved 4/5)에서 5번째 개미 익사만 막는 변형을 엔진 trace로 소탐색 — 인벤토리상 blocker 2는 이미
소진이므로 가용 수단 = **잔여 climber 1 추가(carry5) 재조정 또는 기존 blocker 재배치·발화 조건
조정**(STATUS 5d①은 carry5 단순 추가가 불변임을 이미 실측 — 재배치·타이밍 축이 관건). 후보 공간
문제를 사람이 우회하는 가장 싼 경로. 실패 시 model.py 휴리스틱 보강(코드 변경 → plan/impl-review
대상, STATUS 5d① 분리 사유 그대로).
2. witness 길이 확정 후 max_len 오버라이드(예상 "18:7" 또는 "18:8") + prefix curriculum.
3. stall-any-batches 보조 격발(§5).

### 해결 근거
- 동형 선례 = S20: 같은 "포화(cap 부족 아님)" 진단에서 휴리스틱 손질(early-climber 체이닝)로
SOLVED(STATUS 2026-06-25) — 니어-해가 7액션까지 서 있는 상태에서 마지막 수는 국소 개입으로 닫힌 전례.
- RL만으로 재시도(seed 추가)는 비권장: 3 seed가 같은 어트랙터로 붕괴한 지형에서 seed 복권 기대값이
낮고, witness 없는 상태의 RL 재투입은 §3(07-13) 원칙 위반.

---

## 3. S21 "어디로 내려가지?" (Ch2 건설) — 니들 배치 + 무거운 에피소드 + 예산 컷

스테이지 상수: total_ants 8 · candy_hp 7 · 100s · 인벤토리 {blocker 2, bridge 1, sand_mound 1, slideL 1} = 5개.
구조: candy(9,5)가 **공중 플랫폼**(row6, cols5-11) 위. 홈·스폰 좌측 렛지(1,11). 바닥(row15) 전폭,
중간 렛지 row9 두 조각(cols3-7·cols14-19), 우측 타워(cols17-19). 물은 바닥 좌우 바깥(x<0, x>19)뿐.

### 원인 추정
① **[주가설 — probe 대상] 정밀 건설 조합**: 무개입 개미는 죽지 않고 바닥을 무한 배회(6000f
time_out) — 사망 신호도 진척 신호도 없는 지형이라 어떤 건설 개입 없이는 candy 도달 불가(이 부분은
실측). 도달 경로로는 sand_mound **1개**의 cap-onto-ledge 니들 배치(S24 needle과 동형) +
bridge/slideL의 순차 결합이 유력하나 — witness 전무·solvability 미검증이므로 이는 레이아웃·
인벤토리에서 유도한 **가설**이다(§15 trap_v2의 순차 의존(p²) 발견-비용 구조와 동형이라는 판단
포함). probe가 경로 실재와 순서를 판정한다.
② **문법 길이는 무죄**: 인벤토리 총 5 ≤ max_len 6 — S14/15/20과 다른 부류.
③ **예산 내 미수렴 중첩(seed0 한정 개연)**: 3 seed 모두 batch 150·2400eps를 **완주**했다 —
wall 최장(1802~1888s/seed)은 시간 비용이지 샘플 수 감소가 아님. "상승 중 컷"은 seed0(0.523→0.639,
batch 140에도 갱신)에만 성립하고, seed1은 batch 110 이후 0.531 정체·seed2는 batch 140 이후 무개선 —
07-13 §5의 유형⑤는 seed0 개연으로 한정해야 정직하다.
④ solvability 미검증: witness 전무 + 휴리스틱 트랙 난공 이력(auto-solver "S21 별개").

### 추정 근거
- 엔진 실측(빈 플랜 trace): 8마리 전원 x[1..16]·y[11..14] 바닥 배회, 픽업 0, 사망 0 — ①의 직접 증거.
- 로그: 3 seed best plan 전부 sand_mound를 렛지 인근(9,10)/(10,7)/(10,12)에 배치 시도 — 니들
근방까지는 갔으나 정답 조합 미달. bestR 추이는 seed별 상이(seed0 갱신 지속 / seed1·2 후반 정체 — ③).
- 인벤토리 제약(주가설 지지 정황): mound가 1개뿐이라 — 주가설 경로가 맞다면 — 오배치 시 그
에피소드는 회복 불능이 되는 구조.

### 해결안
1. **witness 수동 확보**: row9 좌측 렛지(cols3-7) 인접 열 × sand_mound cap-onto-ledge 후보 소탐색
(엔진 trace로 개미 도달 확인 후 bridge/slideL 결합) — S24 witness 확보 방법론(2026-07-02) 재사용.
2. witness 확보 시 prefix curriculum(길이 ≤6이므로 max_len 불필요 개연).
3. witness 실패 시에만 resume 연장(150→300, `--save-ckpt` SOP 준수) — 단 기울기 생존은 **seed0
한정**이므로 연장도 seed0부터. 병행 금지(§15.8: 재시작·연장의 양날 — 대조 없는 중복 투입은 원인
격리를 망침).

### 해결 근거
- cap-onto-ledge 니들의 수동 해소 전례 = S24(carrying blocker + col9 cap, 2026-07-02).
- resume 등가성은 §R2에서 검증 완료(재개 등가성 PASS), 연장이 클리어로 이어진 전례 = §11(S12
batch 후반 돌파)·§14(S17 s2 @75).

---

## 4. S25 "야옹~" (Ch2 건설) — **보상 정규화 결함(실증) + 리다이렉트 과대계상 정황 + solvability 미검증**

스테이지 상수: **total_ants .tres 미지정**(엔진 기본 10 스폰 — trace 실측 10마리) · candy_hp 7 · 100s ·
인벤토리 {blocker 2, bridge 2, floater 2, sand_mound 4, slideL 1, slideR 1} = 12개.
구조(고양이 그림 레벨): 스폰·홈이 **우측 밀폐실**(cols14-20 상자, 내부 cols15-19 rows2-4) 안 (19,4).
candy(11,13) 최하단 중앙. 좌측 밀폐실(cols3-9)에 정적 사다리(5,2-4).

### 4.1 원인 ① — total_ants 분모 결함 (신규 발견, 구체 버그·수치 실증)

**결함 체인**: `tools/solver/solve.py:190` `"total_ants": _int("total_ants", 0)` — .tres에 필드가 없으면
**0**(엔진 StageData `@export var total_ants: int = 10`과 불일치) → `mdp.py:308`
`ants_total = max(1, int(meta["total_ants"]))` = **1** → shaped retired 항·blocker_bonus의 분모가
엔진 실제(10) 대비 **10배 축소**.

**수치 실증(소수점 일치)**: seed1 로그 bestR **2.280** = 로컬 리플레이 재구성치.
입력값(goal_dist=6, redirect_value=101, retired=0)은 저장 로그에 없는 값이 아니라 **로그의 best plan
JSON을 로컬 결정론 리플레이(trace:true·report_fired:true)로 재실행해 독립 재측정**한 것이다 —
훈련 데드라인 4500f로 절단해 재계산해도 동일(gd=6은 f1912 최초 도달, redirect 101 불변).
- base = (saved 0 + picked 0 + lost 0)/7 − 0.02×6 − 0.1(deadline) = **−0.220**
- goal shaping = 0.5 × (1 − 6/49) = **+0.4388** (best_goal_dist=6 리플레이 실측, D0=W+H=32+17)
- blocker_bonus = 1.0 × 101/(49×**1**) = **+2.0612** (redirect_value=101 리플레이 실측)
- 합 = **2.280** ✅ (ants_total이 엔진 정합 10이었다면 blocker 항 0.206 → bestR ≈ 0.43)

**확정과 미확정의 경계(정직 표기)**:
- **확정**: S24·S25의 정규화 관련 신호 — shaped retired 항·blocker_bonus·trace 집계 스칼라의
total_ants 분모 채널 — 는 엔진 실제(10) 대비 10× 불일치. 따라서 07-13 보고서의 S25 유형⑤ 판독
("상승 중 — resume 연장 후보")의 근거였던 bestR/meanR 수치는 **판독 근거로 신뢰 불가 → 분류 철회**.
오염 제거 전 resume 연장은 배제(파밍 신호를 연장할 위험).
- **미확정(수정 후 판정 대상)**: ① "2400eps×3seed가 파밍에 소모됨" — bestR 재구성 1건과 meanR
1.6~1.8의 정황(blocker 항 없이는 도달 불가한 수준)이 시사하나, episode별 항 분해 로그가 없어
일반화는 개연 수준. ② 분모 결함이 S25 **미클리어의 원인**이라는 인과 — 구조 난이도(§4.2)가
공존하므로 단독 인과 확정 불가. 판정 실험 = 수정 전후 동일 seed A/B(§해결안 4).

**S24 파급(개연·범위 축소)**: S24도 total_ants 부재 → shaped retired 항이 −0.1×retired/**1**
(의도 대비 10배) — 사망 1마리당 −0.1로 goal 항 상한(+0.5)의 20%를 상쇄. floater 하강·낙하 실험이
필수인 S24 witness 구조에서, retired>0 에피소드의 배치-보상을 눌러 **학습(gradient) 단계의 탐험
억제** 방향으로 작용 가능 → "완전 동결"(0.398)의 기여 요인 후보. 단 **S24 bestR 자체는 결함
무영향** — 3 seed best plan 모두 blocker가 없고, 0.398 = len_penalty(−0.02) + goal shaping(0.418)
산술상 retired=0 필연(retired≥1이면 −0.1 이상 차감돼 이 값이 나올 수 없다). S24 동결의 주인은
여전히 순차 의존 발견 비용(07-13 §3)이고 이는 가설 수준 — 수정 후 A/B가 판정한다.
**오염 범위의 정확한 서술**: retired=0이고 blocker 리다이렉트가 없는 에피소드의 reward는 분모와
무관하게 동일하고, total_ants 정규화 **관측**(trace 스칼라/채널)은 r3 refine 경로(`obs_flat_r3`)
전용이라 이번 스윕(r2.1)의 학습 관측은 애초에 비오염이다. 정확한 범위 = "**S25의 bestR/meanR
전반 + S24의 meanR 중 retired>0 또는 blocker-리다이렉트 에피소드가 낀 부분 + 해당 에피소드들의
reward**"가 신뢰 불가.

### 4.2 원인 ② — 구조 난이도: 밀폐실 왕복 체인 + solvability 미검증

- 엔진 실측(빈 플랜): 10마리 전원 x[15..19]·y=4 — **밀폐실 안에서 6000f 내내 배회**(탈출 경로 0).
- 엔진 실측(RL best plan 리플레이): sand_mound(15,4)로 **방 지붕 위 탈출은 가능**(개미 row0 도달,
best_min_y=40px) — 밀폐실이 감옥은 아님. 그러나 상부 구조물 배회 후 (9,8) 부근 낙하 반복,
candy(11,13) 미도달(goal_dist 최소 6), 픽업 0.
- 왕복 성립 조건이 길다: 탈출(mound in-room) → 하강 루트(floater/slide) → candy → **밀폐실 재진입**
(홈이 방 안 — 같은 mound 사다리 역등반 또는 외부 mound 체인) — sand_mound 4개 인벤토리가 설계
의도를 시사하나, **완주 witness 전무 = solvability 미검증**. 필요 액션 ≥7 개연(12개 인벤토리).

### 해결안
1. **버그 수정 1줄** ✅ **구현됨(2026-07-14, 본 보고서 후속)**: solve.py `_int("total_ants", 0)` →
`_int("total_ants", 10)` (엔진 StageData 기본과 정렬). **부수 정렬**: 같은 함수의
`time_limit_seconds` 기본 100.0도 엔진 기본 120.0과 불일치 → 함께 정렬(누락 스테이지 = S7 단 1개,
deadline 7500→8700로 안전망만 넓어짐 — 엔진 스테이지 타임아웃 7200f가 항상 먼저라 판정 불변,
rl/mdp는 time_limit 미소비). candy_hp는 10=10 기존 정합. **파급의 정확한 범위**:
   - 보상/롤아웃 **의미론**: total_ants 명시 스테이지(현 캠페인 1~23)는 meta 불변 — pinned 재현
     게이트의 보상 경로 보존. S24/25만 정규화 정상화.
   - 그러나 **스윕 완료 지문은 전역 무효화**: 캠페인 지문이 solve.py 소스 sha를 전 스테이지 공통으로
     포함(FINGERPRINT_MANIFEST)하므로, 수정 시 **모든** 스테이지의 done 기록이 스킵 자격을 잃는다.
     또한 runtime_digest도 solve.py를 포함해 replay memo cache가 전역 무효화된다. 의미론 불변
     스테이지의 재실행은 낭비이므로 **수정 후 스윕은 반드시 `--stages 24,25`처럼 범위를 제한**해
     실행한다(전 범위 재스윕은 별도 결정 사안).
2. 수정 검증 ✅ **수행됨(2026-07-14 — 실험(RL 학습 런) 제외 파이썬 레벨 완결)**:
(a) S25 best-plan 보상 재계산을 **실제 mdp 코드 경로**(StageMDP(25).reward/shaped_bonus/
blocker_bonus)로 수행 — 수정 후 ants_total=10 → 합 **0.4249**(예측 ~0.43 적중), 분모 1 재현 시
**2.2800 = 훈련 로그 bestR 정확 일치**(인과 사슬 실코드 재확인)
(c)+(d) **`tools/solver/rl/experiments/meta_defaults_probe.py` 신설 — 13/13 PASS**: StageData.gd
@export 기본값을 직접 파싱해 stage_meta 필드-생략 기본값과 대조(하드코딩 기대값 없이 엔진 소스가
SoT — 재이탈 구조 차단) + 명시값 경로 + 명시↔기본 동치 + 실전(S24/25→10, S21=8·S10=5 명시 유지)
(b) verify 게이트(Godot 헤드리스)는 미실행 — 이번 diff는 meta 상수 파싱만 변경(보상 공식·엔진·
PlanRunner 무변경)이고 pinned 스테이지(S11~13·17·19)는 전부 필드 명시라 StageMDP 상수
byte-identical. 다음 학습/스윕 실행 전 게이트 1회 권장.
3. **S25 witness 확보 선행**(수동 probe: mound 탈출 → floater 하강 → candy → 재진입 체인을 엔진
trace로 단계 구축). solvability 확정 전 RL 재투입 금지(07-13 §3 원칙). 확보 시 길이 따라
max_len 오버라이드 + prefix curriculum.
4. 수정 후 **동일 seed A/B**(`--stages 24,25` 범위 제한): 엄격한 인과 판정이 되려면 **같은 머신·
런타임에서 수정 전 arm과 수정 후 arm을 모두 실행**해야 한다 — 기존 07-13 결과는 크로스PC 자료라
(EOL 대조는 레벨 콘텐츠만 입증, 엔진 바이너리·Python/PyTorch 환경 미통제) 직접 비교하면 차이를
분모 수정 하나에 귀속할 수 없고, 그 비교는 "역사적 동일-seed 대조(참고)"로만 쓴다. 측정 대상도
정확히: 분모 수정 후 blocker 항은 소실이 아니라 **~0.206으로 축소**될 뿐이므로, "과대 정규화 제거
후 리다이렉트-지향 행동과 학습 궤적이 어떻게 변하는지"를 본다(§4.1 미확정 ①② 판정 + S24 가설
판정 겸용). 07-13 §3의 witness 선행 원칙과의 순서는 사용자 결정 사안(A/B는 저비용 2스테이지
한정이라 병행 가능).

### 해결 근거
- 분모 결함은 R1 계약("shaping 분모 = 스테이지 상수, result 파생 금지")의 **상수 값 자체가 엔진과
불일치**한 사례 — 엔진=진실(D4) 원칙상 엔진 기본(10)과의 정렬이 정공법.
- 수치 실증(2.28 정확 재구성)은 **bestR 수치의 출처**를 고정한다(분모 1의 blocker 항 없이는 도달
불가) — 단 이것이 미클리어의 인과까지 고정하지는 않으며(§4.1 미확정), 판정은 A/B(해결안 4)가 한다.
- blocker_bonus 자체의 게이트(반전×진척, §6.4)는 정상 레벨(S12·13·17)에서 검증된 자산 — 문제는
게이트가 아니라 정규화이므로 보너스 은퇴가 아닌 분모 수정이 맞다.

---

## 5. 공통 메커니즘 공백 — stall 격발 조건이 다양-고원을 못 잡음 (07-13 §3 재확인)

S10(dup 0.02~0.03)·S18(0.02~0.05) 모두 "다양하게 시도하며 전부 실패"형 고원이라
격발 조건(미개선≥30 **AND** dup≥0.5)의 dup 문턱에 걸려 구제 레짐(knowledge=always 재시작)이
한 번도 발동하지 않았다. `2cdd74b`에서 구현된 `--stall-any-batches N`(dup 무관 보조 격발)이 정확히
이 공백을 겨냥하나 **학습 실행 미검증** — 다음 스윕 레시피에 `--stall-any-batches 60`을 포함해
첫 실전 검증을 겸하는 것을 권장(07-13 §6.5 표기와 동일: 첫 사용 런 = 실전 검증).
**비용 정직 표기**: 이 플래그는 train.py CLI일 뿐 sweep_stages.py RECIPE에는 아직 없고 러너 CLI도
받지 않는다 — 편입 = RECIPE 수정(코드 변경) → **캠페인 지문 전역 변경 → 전 스테이지 done 기록
재시도 유발**. 따라서 "구현 소 / 실행 대"이며, 편입 시점은 어차피 전 범위를 다시 도는 재스윕과
묶는 것이 낭비가 없다(개별 스테이지 실험은 train.py 직접 호출로 지문 비오염).

## 6. 권장 액션 (우선순위)

| 순위 | 액션 | 대상 | 비용 | 근거 |
|---|---|---|---|---|
| 1 | **total_ants 분모 수정**(solve.py 1줄) + 검증 4종(§4 해결안 2) | S24·S25 (+이후 모든 미지정 스테이지) | 수정 극소 / 부작용: 스윕 지문·replay cache **전역 무효화** → 이후 스윕은 `--stages` 범위 제한 필수 | 수치 실증된 구체 버그 — 이것 없이 S25 bestR/meanR 전반 + S24 meanR의 retired>0·blocker-리다이렉트 에피소드 부분은 신뢰 불가(정확한 범위 §4.1; r2.1 관측·S24 bestR은 무영향) |
| 2 | 오버라이드 스윕 `--stages 14,15,20 --max-len-overrides "14:8,15:7,20:7"` | S14·S15·S20 | 중(수 시간) | replay 5/5로 전제 검증 완료 — 준비된 실행 (순서: **1번 수정을 먼저** 반영하면 done 기록이 새 지문에 결속돼 이후 무효화 낭비가 없음) |
| 3 | 니어-해 기반 수동 witness probe(실패 시 model.py 휴리스틱 보강) | S18 | 소~중 | cap 상향은 **반증됨**(STATUS 5d①: cap80→40롤 포화·saved 4/5 고정) — 5번째 익사 해소가 관건, S20 휴리스틱-손질 선례 |
| 4 | witness 수동 확보 probe | S21 → S25 → S10 순 | 중 | S21이 가장 가까움(니들 1점), S25는 1번 수정 후, S10은 주가설 검증 겸 routing 확장 병행 |
| 5 | attempt02 (seeds 3,4,5) | S6·S9·S17 | 소 | 07-13 §4 그대로(해 실재, seed 복권) |
| 6 | `--stall-any-batches 60` 스윕 레시피 편입 | 재스윕 전체 | 구현 소 / **실행 대**(지문 전역 변경 → 전량 재시도 유발 — §5) | 12 FAIL 중 10개가 구제 미발동이었던 공백의 첫 실전 검증 — 전 범위 재스윕과 묶어 편입 |
| 7 | 동일 seed A/B 재스윕(1번 수정 후, `--stages 24,25`) | S24·S25 | 중 | §4.1 가설·미확정 인과의 판정 실험 겸용 |

## 부록 A — level_digest EOL 민감성 (크로스PC 대조 시 오탐 주의)

attempts.jsonl의 S17·S20·S21·S23·S24·S25 level_digest가 로컬 산출과 불일치했으나, 6건 전부
**HEAD 콘텐츠의 CRLF 정규화 변형과 정확 일치**(git blob → `\n`→`\r\n` 변환 후 sha256 절단 대조).
즉 콘텐츠 동일·개행만 상이(autocrlf 체크아웃 차이). `solution_registry.level_digest`가 파일 raw
바이트를 해시하므로 EOL에 민감 — 크로스PC 스킵 판정·해 파기(레벨 변경 오인) 양쪽에 오탐 위험.
개선 후보(별도 결정 사안): digest 산출 전 `\r\n`→`\n` 정규화. 단 기존 등재 레지스트리의
level_digest와의 호환(파기 트리거)을 검토해야 하므로 본 보고서는 등재만 하고 구현 보류.

## 부록 B — 근거 데이터·재현 커맨드

- 스윕 로그: `tools/solver/rl/experiments/sweep_out/stage{10,18,21,25}.attempt01.log`
- 시도 이력: `tools/solver/rl/experiments/sweep_out/attempts.jsonl` (S17~25 = 크로스PC, fingerprint 098b…)
- 베이스라인/best-plan 리플레이: `PYTHONIOENCODING=utf-8 python scripts/run_plan.py <plan.json>` —
  plan = `{"stage": "res://scenes/stages/StageNN.tscn", "actions": [...], "trace": true, "report_fired": true}`
  (RL best plan은 attempt 로그 FAIL 줄의 JSON 그대로)
- 보상 재구성: mdp.REWARD/SHAPING 공식 + `model.best_goal_dist`·`model.blocker_redirect_value`
  (D0=W+H는 학습 로그 헤더 `grid=HxW`에서 확인 — S25는 17x32 → 49)
- **S25 bestR 2.280 재구성의 정확한 재현 절차**(L2 보존 — 수치가 문서 자기보고로만 남지 않도록):
  1. `stage25.attempt01.log`의 `[seed 1] FAIL bestR=2.280 best plan:` 줄에서 actions JSON 추출
  2. plan 파일 구성: `{"stage": "res://scenes/stages/Stage25.tscn", "actions": <추출 JSON>,
     "trace": true, "report_fired": true}` → `python scripts/run_plan.py <plan.json>`
  3. 결과 res에서 — base: `(saved+0.3·picked−0.2·lost)/7 − 0.02×6 − 0.1(훈련 reason=deadline)` /
     goal: `0.5×(1 − model.best_goal_dist(res.trace, layout)/49)` / blocker:
     `model.blocker_redirect_value(res.trace, layout, {fired blocker 셀}) / (49×1)` — trace를
     frame≤4500으로 절단해 재계산해도 동일(gd=6 최초 도달 f1912, redirect_value=101 불변)
  4. 실측값: saved=0·picked=0·lost=0·gd=6·redirect=101 → −0.22 + 0.4388 + 2.0612 = **2.280**
- 오늘 witness/solve replay 검증: stage14/15/20.solve.json·stage23/24.witness.json → 전부 cleared
