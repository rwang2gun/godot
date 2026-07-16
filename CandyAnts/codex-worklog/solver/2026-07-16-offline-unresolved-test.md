# 오프라인 미해결 스테이지 테스트 (2026-07-16) — S9 3/3 · S25 A/B 확증 · S23 witness 문법 표현불가 규명

> 선행: [2026-07-14-unresolved-stages-analysis.md](2026-07-14-unresolved-stages-analysis.md)(미해결 4종 심층분석 + total_ants 분모 수정 `fcc3996`).
> 이 세션 = 그 권장 액션 중 오프라인(무네트워크) 무인 실행 가능한 3개 arm을 detached 러너로 2h8m 실행.
> 러너 = `experiments/offline_unresolved_run.ps1`(자기완결 PS1 — PID/콘솔로그 sweep_out, Arm C는 경과<130분 조건부).
> 사전 게이트(분모 수정 후 첫 학습 실행 전 권장 이행): meta_defaults_probe **13/13** + try_solve selftest **19/19** PASS.
> 미해결(레지스트리 미등재) 현황 조회 = **S10·S18·S21·S23·S25**. S10/S18/S21은 witness 부재로 RL 재투입 금지
> (07-13 §3 원칙) — 이번 arm 대상 제외, 수동 witness probe가 다음 작업.

## 결과 요약

| Arm | 구성 | 결과 | wall |
|---|---|---|---|
| A: S23 | witness-prefix **k=4** 에스컬레이션(k=3 무진척 후속), seeds 0,1,2 | **0/3 FAIL** — 3-seed bestR 0.287 완전 동결 → **사후 진단으로 근본 원인 확정(§1)** | 22.5분 |
| B: S25 | 분모수정(`fcc3996`) 후 동일 레시피 재실행 = §4 해결안 4의 **B arm** | **0/3 FAIL**이나 **A/B 판정 성공(§2)** + seed2 상승 중 컷(연장 후보) | 71.5분 |
| C: S9 | attempt02 seeds 3,4,5(§6 순위 5 seed 복권) | **3/3 PASS** — 레지스트리 1해 → **3해**(신규 배치 2건) | 33.8분 |

## §1 S23 — witness가 r2.1 문법으로 표현 불가 (prefix curriculum 구조적 오염, 실증)

**증상**: k=4 3-seed 전부 bestR 0.287에서 escalate(knowledge=always 재시작) 포함 2400eps×2 동안 완전
동결. best plan = prefix 4액션 그대로(자유 슬롯 기여 0).

**진단(엔진 D4, 리플레이 2건)**:
1. 실행형 prefix 4 + witness 5번째(bridge) 접합 리플레이 → **no_more_ants f964, fired 2/5, saved 0**
   (순수 witness는 saved 7/7 f2375).
2. witness 전체 5액션을 `StageMDP(23, grammar="r2.1").encode_action→decode_plan` 왕복 후 리플레이 →
   **동일 실패**(no_more_ants f964, fired 2). 즉 k 값과 무관하게 **문법 표현 자체가 위증**.

**드리프트 지점**(원본 → 왕복):
- blocker: target `y∈[600, 99999]`(개방 밴드)·dir 0 → **`y∈[624,672]`(1셀)**, trigger x **40→24**
- bridge: target `y∈[100,400]` → **`y∈[240,288]`(1셀)**, x 790→792
- floater: `y∈[240,360]` → `[240,288]`(이건 무해했을 개연)

수작업 witness의 **넓은 y밴드가 r2.1의 1셀 해상도로 붕괴** — 개미가 트리거 x를 지나는 프레임에 밴드
밖이라 액션이 영영 미발화(fired 2/5 = 무조건 발화인 sand_mound at_frame 둘만 발화). **매 에피소드가
오염된 prefix로 시작 → 클리어 방향 기울기 원천 0** = 3-seed 동결의 전모. k=3(07-15 무진척)도 같은
원인으로 소급 설명된다.

**판독 정정(07-13 §3 / 07-14 §0 표)**: "S23 witness replay cleared = 표현 가능한데 못 찾음(순수 탐색
실패)"는 **틀렸다** — replay는 해의 *존재*만 증명하고 *문법 표현 가능성*은 별개 검증이 필요하다.
S14 성공(solve.json prefix k=3)은 solve.json이 솔버 산출물이라 이미 grid-정렬이었기 때문(무손실 인코딩).
S24 성공(witness k=2)은 앞 2액션이 우연히 의미론을 보존한 경우.

**후속 정공법 2건(미착수)**:
1. **train.py prefix 로드에 의미론 fail-closed 검증**(코드 수정 → 적대 리뷰 대상): encode→decode 왕복
   prefix + witness 잔여 접합 플랜을 엔진 리플레이 1회로 확인, cleared 아니면 rc=2 즉시 거부 — 이번
   같은 수 시간 낭비를 롤아웃 1회 비용으로 차단.
2. **S23 witness grid-정렬 재구성**: trace에서 발화 시점 개미 y를 읽어 1셀 밴드·격자 x로 재표현 후
   리플레이 재검증 → 그 파일로 prefix 재시도.

**재현 커맨드**: 왕복 스크립트는 임시(scratchpad, 세션 소멸)였으나 절차 = ① `StageMDP(23,
grammar="r2.1")`로 witness actions를 `encode_action` 후 `decode_plan` ② 결과 actions로 plan JSON 구성
③ `python scripts/run_plan.py <plan>` — cleared=False(no_more_ants f964)면 재현.

## §2 S25 — total_ants 분모 수정 A/B 판정 (수정 유효 확증)

- **bestR 스케일 정상화 확증**: 수정 전 2.280(blocker 파밍, §4.1 재구성) → 수정 후 **0.398~0.477**,
  07-14 예측치(~0.43)와 정합. 인과 사슬(분모 1→10) 실전 종결.
- **학습 신호 건강**: meanR 0.21→0.37 단조 상승(수정 전엔 blocker 항 파밍이 지배) — "2400eps가 파밍에
  소모" 가설(§4.1 미확정 ①) 방향 지지.
- **seed2 기울기 생존 + 컷**: batch 90→110에서 bestR 0.398→0.423→**0.477**(sand_mound 2개 조합 —
  (18,2)+(16,·) 밀폐실 탈출 진행), batch 150 컷 시점 si46. **S15 선례(배치 500 연장으로 해 발견)와
  동형** → 다음 수 = `--max-batches-overrides "25:400"` 연장(witness 선행 원칙과의 순서는 07-14 §4
  해결안 4 각주대로 저비용 병행 허용 범위).
- ⚠ **partial 잔재 주의**: `found/stage25_seed*.partial.json`은 이번에 미갱신 — 기존 파일의 bestR이
  버그-부풀림 스케일(구 2.28대)이라 오늘의 정직한 0.477보다 높아 최고-진척 비교에서 이김. 부풀림
  partial은 신뢰 불가 데이터로 간주할 것(정리 여부는 별도 결정).

## §3 S9 — 완전 클리어 (미해결급 이탈)

seeds 3,4,5 **3/3 클리어**(2026s). 레지스트리 `stage09.solutions.json` 1해 → **3해**(신규 배치 2건 등재,
bridge 구조 상이 해). 문턱(≥2/3) 충족 — 07-13 분류의 "부분(1/3)" 군에서 이탈.

## 아티팩트·이력 정정

- 로그: `sweep_out/stage23.attempt03.log`·`stage25.attempt02.log`·`stage09.attempt02.log` +
  attempts.jsonl 3엔트리 append.
- **attempt 번호 충돌 정정(S14/15 선례 재발)**: 이 PC state에 S9 기록이 없어 러너가 attempt 1로 시작,
  커밋된 크로스PC `stage09.attempt01.log`(07-12)를 덮어씀 → 오늘 로그를 **attempt02로 재번호**하고
  attempt01은 git에서 복원. attempts.jsonl·sweep_state.json의 해당 엔트리도 attempt02로 정정.
- 게이트/스모크 잔재 없음(스모크의 partial 기록은 최고-진척 비교에서 기각돼 레지스트리 무변경 확인).
- codex 적대 리뷰 = 코드 무변경(러너 PS1은 실험 스크립트)이라 비대상. §1 후속 1(train.py 수정) 착수 시
  plan/impl-review 정책 적용.

## 다음 세션 진입점

1. **S25 연장 런**: `sweep_stages.py --stages 25 --max-batches-overrides "25:400"`(약 1~1.5h, 오프라인 가능).
2. **S23 witness grid-정렬 재구성** → 재검증 → prefix 재시도(§1 후속 2).
3. **train.py prefix 의미론 검증**(§1 후속 1, 코드 수정 + 리뷰).
4. S10/S18/S21 수동 witness probe(07-14 §6 순위 3~4 그대로).
