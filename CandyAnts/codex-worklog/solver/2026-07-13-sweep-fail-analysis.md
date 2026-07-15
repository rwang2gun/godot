# 2차 스윕 미클리어 스테이지 실패 분석 (2026-07-13)

> **⚠ 2026-07-14 정정**: S25의 유형⑤("예산 내 미수렴 — resume 연장 후보") 분류는 **철회**됨 —
> total_ants 분모 결함(solve.py 기본 0 vs 엔진 10, S24·S25만 해당)으로 S25 bestR/meanR이
> blocker_bonus 10× 과대계상에 오염된 판독이었음(bestR 2.280 소수점 재구성으로 실증, 결함은
> 07-14에 수정됨). §5의 S25 resume 권고와 §6 표 6번의 S25 부분도 같은 이유로 무효.
> S18의 "witness 확보(휴리스틱)" 방안도 cap 상향으로는 불가함이 확인됨(STATUS 5d① 선행 반증 —
> cap80에서 40롤 포화). 상세·후속 = [2026-07-14-unresolved-stages-analysis.md](2026-07-14-unresolved-stages-analysis.md)

> 대상: 2차 스윕 S3~S25 (레시피 = shaping trace + train_deadline 4500, grammar r2.1, max_len=6,
> seeds 0/1/2, 배치 150·2400eps/seed, acceptance ≥2/3 seed 클리어, attempts=1)
> 근거: `tools/solver/rl/experiments/sweep_out/attempts.jsonl` + `stageNN.attempt01.log`
> + `data/solutions/`(witness/solve/rl2) + `data/solutions/found/`(레지스트리·partial)

## 0. 결과 요약

25개 중 **12개 FAIL**: S6·S9·S17(1/3 문턱 미달) / S10·S14·S15·S18·S20·S21·S23·S24·S25(0/3).

| Stage | seed 클리어 | bestR 고원 | 알려진 해 | 해 액션 수 | max_len=6 표현 | 실패 유형 |
|---|---|---|---|---|---|---|
| S6  | 1/3 (s1 재발견) | 0.650 (s0·s2) | ✅ rl2 | 6 | 가능(꽉 참) | ④ 문턱 미달 |
| S9  | 1/3 (s2 **신규 등재**) | 0.58~0.66 | ✅ found | — | 가능(발견됨) | ④ 문턱 미달 |
| S10 | 0/3 | 0.31~0.34 동결 | ❌ 없음 | — | 미상 | ③ 평평 지형(+solvability 미검증) |
| S14 | 0/3 | 1.03~1.06 | ✅ solve | **8** | **불가** | ① 문법 한계 |
| S15 | 0/3 (s1 니어 3.42) | 0.449 / 3.42 | ✅ solve | **7** | **불가** | ① 문법 한계(+② 니어클리어) |
| S17 | 1/3 (s0 **신규 등재**, 레벨변경 재등록) | 3.78~4.01 니어 | ✅ found | — | 가능 | ④ 문턱 미달(+② 니어클리어) |
| S18 | 0/3 | 0.396 동결 | ❌ 없음 | — | 미상 | ③ 평평 지형(+solvability 미검증) |
| S20 | 0/3 | 0.510 상승 중 | ✅ solve | **7** | **불가** | ① 문법 한계(+⑤ 예산) |
| S21 | 0/3 | 0.53~0.64 상승 중 | ❌ 없음 | — | 미상 | ⑤ 예산 내 미수렴(+solvability 미검증) |
| S23 | 0/3 | 0.347 **완전 동결** | ✅ **witness** | 5 | 가능 | ③ 평평 지형 |
| S24 | 0/3 | 0.398 **완전 동결** | ✅ **witness** | 4 | 가능 | ③ 평평 지형 |
| S25 | 0/3 | 1.99~2.28 | ❌ 없음 | — | 미상 | ⑤ 예산 내 미수렴(+solvability 미검증) |

주: reward 스케일 대략 — 클리어 ≈ 3.7~4.0, 니어클리어(4/5 saved) ≈ 3.2~3.4, 진척 없는 shaping 고원 < 0.5.

---

## 1. 유형 ① 문법 한계 — max_len=6 < 필요 액션 수 (S14·S15·S20)

> **⚠ 2026-07-14 실전 정정 (커밋 `b6b9eba`)**: 이 유형은 **S20만 순수**로 성립했다. max_len 오버라이드
> 실전 결과 — **S20(max_len=7·300배치) 3/3 CLEAR**(문법천장이 유일 장벽 확증) / **S15(max_len=7·
> 500배치) 1/3**(문법 필요 + 예산 상향 필요) / **S14(max_len=8) 0/3 FAIL**(문법은 필요조건이나
> **불충분** — blocker×3 후 carry 연쇄 미조립 = 탐색·신용할당 장벽, 배치 연장으로 탈출 불가).
> 즉 "max_len만 올리면 풀린다"는 이 절의 함의는 S20 한정. 상세 = STATUS.md 실전 검증 절 +
> [2026-07-14-unresolved-stages-analysis.md](2026-07-14-unresolved-stages-analysis.md) §0 갱신 배너.

### 원인
RL plan 문법이 최대 6액션인데, 알려진(검증된) 해가 그보다 길다 → **정답이 정책의 표현 공간 밖**
(max_len 상향이 **필요조건**). 단 표현 공간을 열어도 보상 기울기가 해까지 이어지지 않으면
(S14) RL은 여전히 못 찾는다 — 문법 천장 제거는 필요하나 불충분(07-14 실증).

### 근거 (확정적)
- `data/solutions/stage14.solve.json` = **8액션** (blocker×3 + climber×5, auto-solver 트랙 2026-06-19
  엔진 verdict saved 5/5 확인 이력). 스윕 best plan은 blocker×3에서 정체(bestR 1.05).
- `data/solutions/stage15.solve.json` = **7액션** (floater×2 + climber×5). 스윕 seed1의 best plan은
  **정확히 이 해에서 climber 1개가 빠진 6액션 형태**(floater×2 + climber×4)로 bestR 3.416 니어클리어
  — "마지막 한 액션이 모자라다"는 직접 증거.
- `data/solutions/stage20.solve.json` = **7액션** (bridge×2 + climber×5). 스윕 best plan들도 6액션을
  꽉 채운 bridge+climber 조합 — 문법 천장에 부딪힘. batch 150에서 bestR 여전히 상승 중(0.51)이었으나
  천장 위 해에는 도달 불가.
- ~~⚠ 유보: solve.json 6월 산출 → 현 레벨 digest 미검증~~ **해소(2026-07-14)**: S14/15/20 solve +
  S23/24 witness를 `run_plan.py`로 현 레벨 replay → **전부 cleared**(saved 5/5·5/5·5/5·7/7·7/7).
  6월 auto-solver 해가 현 레벨에서 그대로 유효.

### 해결 방안
1. **per-stage max_len 상향**: `max_len = min(8, sum(inventory))` 등 인벤토리 총량 기반.
   (S14 inv 8개, S15 7개, S20 7개 — 전부 현 6 초과)
2. 착수 전 `stage14/15/20.solve.json`을 현 레벨에 replay하여 여전히 유효한지 확인
   (유효하면 max_len만으로 충분하다는 가설이 서고, 무효면 레벨이 변한 것 → witness 재확보 선행).

### 해결 근거
- S15 seed1이 6액션으로 니어클리어(3.42)까지 도달 = 부족한 것은 표현 길이뿐이라는 실증.
- 탐색공간 증가 우려는 trace shaping이 완화(§17: shaping trace 없으면 다단 기울기 0, 있으면 S12/S13급
  다단 스테이지 클리어 실증).

---

## 2. 유형 ② 니어클리어 어트랙터 — 마지막 1마리 회수 실패 (S17 s1·s2, S15 s1)

### 원인
4/5 saved 상태(R≈3.7~4.0)가 강한 국소최적. §13.5·§15.8에서 규명된 기존 패턴 —
saved 4까지의 dense 신호가 남은 1마리 회수(플랜 재배열 필요)와 충돌.

### 근거
- S17 seed1: stall 격발(batch 94, dup 0.51) → knowledge=always 재시작 → bestR 3.266→**4.011**까지
  개선했으나 클리어 실패. seed2도 3.782 동일 고원. seed0는 batch 70에 클리어 — 해 자체는 6액션 내 존재.
- S15 seed1: 재시작 후 3.170→3.416 개선 후 정체(단, S15는 유형 ①이 근본 원인 — 7액션 해).
- §15.8 선례: knowledge는 collapse 락 구출에 강하지만 "저고원 점진-확장"은 방해 가능(12쌍 중 악화 4).

### 해결 방안
1. **성공 seed ckpt에서 동일 스테이지 warm-start**: S17 seed0 클리어 ckpt → seed1/2 transfer.
   §13에서 전이 성공 = 해-토큰 중첩 조건부로 규명 — 같은 스테이지 내 전이는 중첩 100%로 성립 조건 최상.
2. **R3 trace-refinement 루프 투입**: §R3에서 0/3 실패 고원(S13 0.660)을 refine 루프 구조로 3/3 돌파 실증.
   니어클리어 고원도 동일 계열(부분 plan 재배열 문제).

### 해결 근거
- S17은 acceptance(≥2/3)만 미달일 뿐 **신규 해가 이미 레지스트리 등재됨** — "해 발견" 목적은 달성.
  seed 재현성 확보가 목표일 때만 위 조치가 필요.

---

## 3. 유형 ③ 평평 보상 지형 — 탐색 신호 0 (S23·S24 [witness 존재], S10·S18 [해 미상])

### 원인
batch 10~40부터 bestR 완전 동결(S23 0.347, S24 0.398, S18 0.396, S10 0.31), meanR≈bestR,
governor blocked_n ≈ 120(사실상 전 구간 차단). **trace shaping조차 기울기를 만들지 못하는 지형** —
witness 구조상 첫 수부터 정확한 조합이 맞아야 진척이 생기는 순차 의존(§15 trap_blocker_v2에서
규명한 p² 구조와 동형).

### 근거
- S23: witness **5액션**(floater→blocker→sand_mound×2→bridge, f41c058에서 레벨과 함께 갱신 = 현
  레벨 정합) — **풀리는 레벨인데 3 seed × 2400eps가 한 발도 못 나감**. 순수 탐색 실패의 전형.
- S24: witness **4액션**(floater→blocker→sand_mound→blocker; 2026-07-02 확립, needle=carrying
  blocker + sand_mound cap-onto-ledge). 동일 양상(0.398 동결). 문법은 carrying state·cell mode 모두
  지원 — 표현은 가능.
- S10·S18: 등재 해·witness 전무(stage10.rl2.json은 actions=0 빈 파일). 지형이 평평한 것에 더해
  **애초에 풀리는지조차 미검증**.
- 결정적 메커니즘 공백: **stall-escalate가 다양-고원을 못 잡음**. 격발 조건 = 미개선≥30 AND
  dup≥0.5인데, 이들 고원의 dup_share는 0.02~0.08 (다양하게 시도하며 전부 실패) → 12 FAIL 중 격발은
  단 2회(S15 s1·S17 s1). 나머지 10개 스테이지는 구제 레짐이 한 번도 발동하지 않았다.

### 해결 방안
1. **witness-guided curriculum** (S23·S24 우선): witness 앞 k개 액션을 고정 prefix로 주고 나머지를
   학습 — §R2 curriculum 인프라 재사용. k를 4→0으로 줄여가며 자력 비중 확대.
2. **stall 격발 기준 보강**: `(미개선≥30 AND dup≥0.5)` → `OR (bestR 미개선≥60배치)` 추가.
   다양-고원에도 knowledge=always 재시작이 닿게 함.
3. S10·S18은 **witness 확보가 선행**(수동 구성 또는 휴리스틱 솔버) — solvability 미검증 상태에서
   RL 예산 추가 투입은 낭비 위험.

### 해결 근거
- §R2에서 cell-target curriculum 사슬 인프라 검증 완료(재개 등가성 PASS).
- S15 seed1 재시작이 3.170→3.416으로 개선한 사례 = 재시작 레짐이 고원에서 유효할 수 있다는 방증.
  단 §15.8 양날(악화 4/12쌍) 유의 — 격발 기준 완화는 재시작이므로 기존 런을 망치지 않음(같은 seed
  보존, §16 레짐).
- witness가 있는데 못 찾는 것은 §15 v2.1 실험에서 "관건=정답 발견 비용"으로 정식화된 문제 —
  발견 비용을 curriculum으로 낮추는 것이 정공법.

---

## 4. 유형 ④ 문턱 미달 — 해는 확보, seed 재현성 부족 (S6·S9·S17)

### 원인
1/3 seed 클리어. acceptance(≥2/3)에 걸렸을 뿐, 클리어한 seed의 해는 레지스트리에 등재 완료.
실패 seed들은 특정 부분해 고원에 수렴(S6 s0·s2 = 0.650 동일 값·유사 plan으로 수렴).

### 근거
- S6: s1이 기존 digger 해(07-05 등재)를 재발견("중복 해 → 카운트만 갱신"). s0·s2는 climber+digger
  2액션 부분해 0.650에 고착 — dup 낮아(0.03) stall 미격발(유형 ③과 같은 메커니즘 공백).
- S9: s2가 batch 110에 **신규 해 발견·등재**. s0(0.663)·s1(0.580)은 고원.
- S17: s0가 batch 70에 클리어. **레벨 변경 감지 → 기존 3해 파기 후 재등록** 정상 동작(fail-closed 설계 검증).

### 해결 방안
1. **attempt02 재시도(seeds 3,4,5)**: 스윕 러너가 attempt 분리 기록을 이미 지원. 저비용.
2. 성공 seed ckpt → 실패 seed warm-start (유형 ②와 동일, §13 근거).
3. **acceptance 기준 재고**: 스윕 목적이 "정리된 해 레지스트리 구축"이라면 1/3 클리어+등재로 목적
   달성 — PASS 기준을 "레지스트리 신규/확인 등재 ≥1"로 바꾸는 것도 옵션 (판정 의미론 변경이므로
   사용자 결정 사안).

### 해결 근거
- S6·S9·S17 모두 클리어 plan이 실재하고 6액션 내 표현 가능함이 스윕 자체로 실증됨 —
  나머지는 seed 복권 문제이므로 시도 수 확대가 가장 싼 해법.

---

## 5. 유형 ⑤ 예산 내 미수렴 — 기울기 살아있는 채 컷 (S21·S25, 부분적으로 S20)

### 원인
배치 150·2400eps 컷 시점에 bestR·meanR이 여전히 상승 중. 학습이 실패한 게 아니라 **끝나지 않음**.

### 근거
- S21 s0: bestR 0.523→0.639가 batch 150 직전(변화 지속), meanR도 0.31→0.47 단조 상승.
  wall 1888s/seed — 총 5579s로 12 FAIL 중 최장(에피소드가 길고 무거운 레벨).
- S25: meanR 1.6~2.1, bestR 2.28(s1, batch 140에 갱신) — 부분 saved까지 도달한 채 상승 중.
  다만 s1 best plan에 sand_mound (15,2) 중복 등 비효율 잔존 — 아직 정리 전 단계.
- 둘 다 등재 해·witness 전무 → solvability 자체도 미검증.

### 해결 방안
1. **resume 이어달리기**: R2 ckpt 재개 등가성 검증 완료 — 동일 seed로 배치 150→300 연장.
2. 병행: witness 확보(수동/휴리스틱)로 solvability 먼저 확정 — S21은 휴리스틱 트랙에서도 난공
   이력이 있어(auto-solver "S21 별개") 레벨 난이도 자체가 높음.

### 해결 근거
- 기울기가 살아있는 런은 §11(S12 고원 돌파가 batch 후반에 발생)·§14(S17 s2 클리어 @75) 선례상
  연장이 실제 클리어로 이어진 사례가 반복 확인됨.

---

## 6. 권장 액션 (우선순위)

| 순위 | 액션 | 대상 | 예상 효과/비용 |
|---|---|---|---|
| 1 | solve/witness replay로 현 레벨 유효성 검증 | S14·S15·S20·S23·S24 | 싸고(롤아웃 5회) 모든 후속 판단의 전제 |
| 2 | per-stage `max_len` 상향(인벤토리 총량 기반) | S14·S15·S20 | 구조적 원인 제거 — 이것 없이는 불가 |
| 3 | attempt02 (seeds 3,4,5) | S6·S9·S17 | 저비용, 문턱 미달 3개 해소 가능성 높음 |
| 4 | stall 격발에 `bestR 미개선≥60배치` OR 조건 추가 | 전 스테이지 | 12 FAIL 중 10개가 구제 레짐 미발동이었던 공백 해소 |
| 5 | witness-guided curriculum (§R2 인프라) | S23·S24 | witness 있는 순수 탐색 실패의 정공법 |
| 6 | resume 연장(배치 150→300) | S21·S25(+S20) | 상승 중 컷 3개 회수 시도 |
| 7 | witness 신규 확보(수동/휴리스틱) | S10·S18·S21·S25 | solvability 미검증 4개 — RL 예산 투입 전 필수 |

## 6.5 구현 반영 (2026-07-13, 본 보고서 후속 — 전부 opt-in·기본값 off = 기존 경로 byte-identical)

권장 액션 중 신규 구현이 필요했던 3건을 반영. **학습/probe 실행 검증은 미수행**(사용자 지시 —
py_compile + 정적 구조 검증만). 첫 사용 런이 곧 실전 검증이 된다.

| 액션 | 구현 | 사용법 |
|---|---|---|
| ② max_len 상향 | `sweep_stages.py --max-len-overrides` — per-stage `--max-len` 전달 + **지문에 max_len 결속**(오버라이드 스테이지만 지문 분기, 기본 스테이지 지문 불변) + attempts.jsonl `max_len` 표기 | `python .../sweep_stages.py --stages 14,15,20 --max-len-overrides "14:8,15:7,20:7"` |
| ④ stall 보조 격발 | `train.py --stall-any-batches N` — 미개선 연속 ≥N이면 **dup 무관 격발**(StallGovernor 보조 규칙, 이벤트에 `rule: any_batches` 표기). N ≥ stall-batches 강제, 0=off | 스윕 RECIPE에 추가 시 `--stall-any-batches 60` 권장(주 문턱 30의 2배) |
| ⑤ witness-prefix curriculum | `train.py --prefix-plan <json> --prefix-k N` — 플랜 앞 k액션을 격자 인코딩해 강제 prefix로 고정, 정책은 이후만 학습. 강제 스텝 = logp/entropy 비기여(SIL replay 동일 규약 — 마스크 밖 -inf NaN 차단). **r2.1·non-refine·scratch 전용 + `--no-save` 필수**(pinned 산출물 불가침). 발견 기록엔 `hint`(k·source·sha) provenance가 사이드카+레지스트리에 동승 — 무힌트 발견과 명시 구별 | `python .../train.py --stage 23 --seeds 0 --grammar r2.1 --envs 4 --sil --shaping trace --train-deadline 4500 --no-save --prefix-plan data/solutions/stage23.witness.json --prefix-k 3` |

설계 결정(레지스트리 순수성): 힌트-유래 해는 **등재하되 `hint` 키로 구분 표기** — 해 자체는
replay로 객관 검증 가능하므로 배제보다 정직한 provenance가 낫다. 산출물(rl*.json)은
`--no-save` 강제로 원천 차단(`no_hint: true` 계약 무모순).

## 7. 부록 — 근거 데이터 경로

- 스윕 이력: `tools/solver/rl/experiments/sweep_out/attempts.jsonl` (23항목, S3~15=로컬 PC
  fingerprint 5097…, S16~25=크로스 PC 098b…)
- 시도 로그: `tools/solver/rl/experiments/sweep_out/stageNN.attempt01.log`
- 등재 해 레지스트리: `data/solutions/found/stageNN.solutions.json`
  (미클리어 12개 중 등재 존재 = S6·S9·S17뿐)
- witness/heuristic 해: `data/solutions/stage23.witness.json`(5액션)·`stage24.witness.json`(4액션)·
  `stage14.solve.json`(8)·`stage15.solve.json`(7)·`stage20.solve.json`(7)
- 부분-진척: `data/solutions/found/stageNN_seedK.partial.json` (reward만 기록, saved/lost 미기록 —
  S16~25분은 크로스 PC 로컬에만 존재)
- 선행 분석: `codex-worklog/solver/2026-07-11-rl-sweep-solution-report.md`,
  `2026-07-05-rl-brain-experiments.md` §13~§17
