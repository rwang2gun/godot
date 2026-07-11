# 2026-07-11 (오후) — 전 스테이지 RL 스윕 + '정리된 해' 레지스트리·비주얼 보고서

> 사용자 목적 재정의: 휴리스틱 해(=사용자 제안 기록)와의 비교 불요. **RL이 스스로 찾은 해 —
> 특히 예측 못한 새로운 해 — 를 중복 제거해 전부 보고**하고, 타임아웃 스테이지는 **가장 멀리
> 도달한 결과**를 보고. 사용자가 눈으로 확인할 비주얼라이즈(궤적) 필수. 보고 단위는 시드별/통합
> 재량 → 통합(시드 병합) 채택.
>
> 후속 계약(같은 세션): ① 시드별 해 유형을 분석해 중복 기준 확정 ② 중복 아니면 복수 해로 기록
> ③ **레벨 변경 시 기존 해 파기** ④ 레벨 불변이면 **정리된 해와 다른 경우만 시드가 기록**.

## 산출물

- **`tools/solver/solution_registry.py` 신설** — 스테이지별 '정리된 해' 레지스트리
  (`data/solutions/found/stageNN.solutions.json`, gitignore negation으로 추적 승격).
  - **중복 기준 = 실행-결과 동치**: greedy-클리어 롤아웃의 trace(+saved/frame) sha16.
    근거 = 시드별 유형 분석: 가짜 중복의 실체는 **트리거 표현 별칭**(S1: `xle17/any` vs
    `pick>=2/carrying` vs `xle18+y밴드` 3표현이 전부 frame 1587 동일 실행; S2 f=1758·S3 f=1714·
    S13 f=1669 동형). 배치가 실제로 다르면(S5 sand_mound (13,8)/(18,8)/(15,9), S17 3해) 복수 해로
    분리. trace 부재 런은 plan_key(셀 양자화+60f 버킷 정규화) 보수 폴백(과분할 허용).
  - **레벨 digest 바인딩**: stage .tres + layout .tres + .tscn 결합 sha. 기록 시 불일치 →
    기존 해 전부 파기 후 재등록(계약 ③). 뷰어는 파기-대기 스테이지를 보고서에서 제외+표기.
  - `--migrate`: 레거시 found 기록 이행 — **현재 레벨로 리플레이된 캐시가 cleared인 기록만**
    등재(정직성 게이트). 결과 신규 15 · 중복 흡수 54 · 스킵(캐시 부재/미클리어) 50.
- **`train.py`** (pinned r0/r1/r2×2 = 4/4 PASS 재확인, cfg/digest 무변경):
  - `_record_found` → **registry 경유**: dup=카운트만 갱신(사이드카/log 미기록, 계약 ④) /
    reset=파기 후 재등록 / new만 durable 기록. 게이트는 cfg 키가 아닌 **kwarg**(`record_partial`
    포함)로 — exec-digest/pin 불변.
  - **`_record_partial` 신설**: FAIL 시 최고-보상(base) 플랜을 `stageNN_seed{s}.partial.json`
    (+partials.jsonl)에 기록('가장 멀리 도달' 보고 원료). 정규 학습 front-door 한정
    (verify/accept 경로 오염 차단). 레벨 digest 스탬프 동승.
  - greedy 평가 payload에 `trace:true` — 실행-동치 키 원료(가산적·판정 불변, Phase 2 실증).
- **`found_viewer.py` 전면 확장**: 레지스트리-우선 로딩(레거시 사이드카는 미등재 스테이지 한정)
  + 클리어 없는 스테이지는 partial 카드("미클리어 · 최고 진척" 배지+bestR/픽업) + `--replay`
  (결정론 리플레이로 궤적·지표 캐시, `found/replay_cache/`) + `--stages` 필터 + 파기-대기 표기.
- **`level_render.py`**: 궤적 오버레이 — 개미별 폴리라인(파랑=빈손/빨강=운반, stage17 진단
  컨벤션), 시작 ○·낙오 ✕(dead/lost), viewBox 궤적 포함 확장.
- **`experiments/sweep_stages.py` 신설**: 1~25 × seeds 스윕 러너(중단-재개 state, 스테이지별
  로그, 집계줄 회수).

## 1차 스윕 (레시피 결함) — 결과와 교훈

- 레시피에 **`--shaping trace --train-deadline 4500` 누락** → 다단 스테이지 전멸: bestR가 batch
  0~140 내내 **-0.020 평탄**(전 seed) = §R1 박제 "terminal-only 보상 기울기 0" 정확 재현.
  §16이 어제 같은 머신에서 S12/S17을 클리어했으므로 모순 → 세션 로그 §11 원형 커맨드 대조로 규명.
  **§14~16 실전 레시피 = shaping trace + train-deadline 4500 + sil + blocker 1.0 + knowledge 1.0
  stall** (trap_v2_test도 shaping="trace"+sil). RECIPE 수정 완료.
- 1차 결과(17/25 진행, 잘못된 레시피): CLEAR = S1~5·7·8·11(3/3)·S13(2/3) / FAIL = S6·9·10·12·14~17.
  쉬운(1~2수) 스테이지는 terminal 보상만으로도 풀림. **S5(sand_mound)·S7(basher)·S8(cutter/
  leaf_jump) = 휴리스틱 routing 부재로 못 풀던 스테이지의 순수 RL 신규 발견**(r2.1 cell-target
  vocab 실전 입증). FAIL 스테이지의 partial 기록은 결함 레시피 산물이라 **파기**(커밋 제외).
- 2차 스윕(수정 레시피): S1·S2 3/3 재클리어 확인 후 **사용자 지시로 중단**(다음 세션 재개).
  S11 스모크에서 재클리어가 "중복 해 → 카운트만 갱신"으로 처리됨(계약 ④ 라이브 검증).

## 현재 레지스트리 (15해 / 12 스테이지)

S01·02·03·04·05·06·07·08·11·13 각 1해 / **S12 2해**(f=2625 seeds0,1 · f=4509 seed2) /
**S17 3해**(f=3920·2403·3857 — §16 stall acceptance 산출 3계열). S6은 07-05 digger 해(캐시 검증
통과) 승계. S9·10·14~16·18~25 미등재(다음 세션 스윕 대상).

## 검증

- pinned: verify-r0·r1@12·r2@11·r2@19 = **4/4 PASS** (train.py 2회 편집 후 각각 재확인).
  **verify-r3 FAIL = 선재**(train.py 편집 stash 격리로 무관 확정) — 워킹트리 `project.godot`
  개행 변경(그림-레벨 편집 세션의 Godot 재저장)이 r3 exec-digest 계약에 걸림. 그림 레벨 커밋
  시점에 정리 필요(r3 산출물 재생성 or 개행 원복).
- 스모크: ① 초소예산 FAIL 런 → partial 사이드카 기록 확인 ② S11 라이브 런 → dup 경로 확인.
- 뷰어: 오프라인 빌드 + `--replay` 빌드(30 플랜 리플레이·궤적 캐시) + 궤적 SVG 구조 검사
  (S11: 파랑 스폰→사탕, 빨강 사탕→집 — 기대 왕복 정확).

## 다음 세션

1. **스윕 재개**: `PYTHONIOENCODING=utf-8 python tools/solver/rl/experiments/sweep_stages.py
   --stages 3-25` (state 리셋됨; S1·S2 재실행해도 dup 처리라 무해. 예산: 스테이지당 ~10~40분).
2. 완료 후 `python tools/solver/found_viewer.py --replay --stages 1-25` → 최종 보고서(부분해
   카드 실데이터 검증 포함) 사용자 전달.
3. **codex 적대 리뷰 미실행 — 이월**(사용자 즉시-마무리 지시). 사후 리뷰 정책 적용: 다음 세션
   시작 시 `/codex:adversarial-review`부터, HIGH 발견 시 hot-fix 커밋 후 진행.
4. gotcha: found/는 gitignore `found/*` + `!stage*.solutions.json` negation(디렉터리-ignore면
   자식 재포함 불가). sweep_out/·replay_cache/·사이드카·index.html은 비추적 유지(재생 가능).
