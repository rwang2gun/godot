# auto-solver Phase 3b — Plan Stage Review + 실측 반증 → DEFERRED

> 정책: CLAUDE.md plan stage(plan-as-SoT). 대상 = `phases/solver/auto-solver-plan.md` §3b
> (max-margin 대안 해 탐색, 사용자 Option A 정렬 후 작성).
> 결론: codex plan-review R1(needs-attention) 후 **구현 전 실측 probe가 설계 핵심 전제를 반증** →
> 사용자 Option C(3b 보류, 실제 레벨 먼저) 채택. **3b 보류**(증거 보존).

## 배경 — 범위 정렬 (사용자 Option A)
3a 측정 결과 S11~S14가 전부 `comfortable` 동일 티어(stage_min 1.35~2.28s, provisional_machine_only 0)라
**difficulty spread 0**. 4개 동일-티어 점으로 T_human 3-티어 보정은 무의미 → 사용자 Option A: 3b를
**max-margin 대안 해 탐색**만으로 좁히고(R1-H4 해소), T_human 보정·절대 난이도 점수는 spread 확보까지 defer.

## 설계 (확정 초안) — placement coordinate-ascent
- 초기 초안: "binding 액션(blocker)의 x-landmark를 직접 스윕". **자체 발견 결함**: S14 binding=climber#3
  (`picked_ge`, 공간축 없음)이라 미적용 → codex R1 호출 전 취소하고 **coordinate-ascent**로 재설계:
  placement-variable knob(position-triggered blocker)을 변형해 **전 필수 액션 min-window(binding)를 최대화**;
  binding이 non-knob(S14 climber)이면 blocker 재배치로 **간접 완화** 기대. analyze.py 기계 재사용·엔진 무변경.

## Round 1 — codex `task --effort high` (read-only, 2026-06-20) — verdict: needs-attention
- **HIGH-1** placement 격자 도메인이 `model.parse_layout`(occupied/kinds/candy/home만)에 정의 안 됨 →
  baseline 발화 개미 trace traversed x-범위를 권위로, 셀-중심 양자화+clip+cmp/y 보존. **(plan 수정 반영)**
- **HIGH-2** `maxmargin.py --verify` fail-open(per_action coverage·min 재계산·전액션 경계 리플레이 누락) →
  analyze `_coverage_check` 동형 fail-closed로 확장. **(plan 수정 반영)**
- **HIGH-3** 변형마다 candidate-local `report_fired` 재발화 누락(knob 이동이 downstream 재타이밍) →
  클리어 변형은 반드시 report_fired+trace 재실행해 그 변형 자신의 f*·spawn_index로 측정. **(plan 수정 반영)**
- **HIGH-4** 빈 탐색이 통과 가능(variants_cleared≥1=seed 허용인데 acceptance는 resolved 주장) →
  `variants_cleared_excluding_seed≥1` 강제 or `no_alternative_cleared` 강등. **(plan 수정 반영; 그리고 실측이 이걸 현실로 확정)**
- **MEDIUM-1** "권위 난이도" 과대주장(3a 윈도우 전부 sampled@stride) → binding dense 검증 or sampled 정직표기. **(보류로 무효)**
- **MEDIUM-2** cross-doc 모순(옛 Phase 3 텍스트가 3b=T_human 보정·절대난이도) → Option A로 갱신. **(plan 수정 반영)**
- **LOW** S14 간접완화가 추측 → 가설로 표기 + `indirect_improved` 필드. **(실측이 가설을 거짓으로 판정)**

HIGH-1/2/3, MEDIUM-2는 plan에 수정 반영. HIGH-4·MEDIUM-1·LOW는 "**blocker 재배치가 binding을 실제로
넓히는가?**"라는 실증 질문에 의존 → 가정 대신 엔진으로 직접 측정.

## 실측 probe (엔진 D4, 2026-06-20) — 설계 전제 반증
`tools/solver/analyze.py` 기계(Rollouter+measure_time_window) 그대로 재사용, 각 knob의 x를 ±1~3셀 변형 →
클리어 여부 + (클리어 시) binding 액션 윈도우 재측정. admissible proxy: min-window ≤ 임의 단일 액션 윈도우라
binding 액션 폭이 found 이하면 개선 불가.

| 스테이지 | binding | found 윈도우 | 변형(3 knob ×6Δ) | 클리어 | **binding 넓어짐** |
|---|---|---|---|---|---|
| S12 | blocker#2 | 81f (1.35s) | 18 | 9 | **0** (다른 knob·자기 knob 전부 81f 불변) |
| S14 | climber#3 | 86f (1.43s) | 18 | 9 | **0** (blocker 간접완화 가설 거짓) |

- **결론**: placement 변형은 binding 윈도우를 **전혀 못 움직임**. 3a binding이 이미 placement-local max-margin.
  심지어 binding blocker 자신을 옮겨도(S12 self-reparam) 윈도우 동일 = single-knob placement 변형은 3a 시간
  윈도우의 재매개변수화일 뿐(새 정보 0).
- **근본 원인**: 난이도(binding 윈도우)는 *placement가 아니라 구조/메커닉*이 결정. carrying 개미 climb 가능
  구간·blocker 반전 타이밍은 개미 물리가 정하고 클리어 placement 범위(±1~3셀) 안에서 robust.
- 즉 codex R1-H4("빈 탐색이 통과")가 가설이 아니라 **현실**. placement-only coordinate-ascent = S11~S14 vacuous.

## 결정 — Option C (사용자, 2026-06-20)
3b 보류. **미검증 실제 레벨을 `try_solve search`로 풀어** difficulty spread + 새 해 구조 코퍼스를 먼저 생성.
- 근거: 3b 두 축(max-margin·T_human 보정) 모두 "4개 동일·유사 스테이지" 제약에 막힘. max-margin/보정에 의미가
  생기려면 *다른 구조의 레벨들*이 먼저 필요. 솔버 일반성(현 휴리스틱 S11~S14 튜닝)·북극성 커버리지도 동시 전진.
- **3b 재진입 시 우선 = cross-structure 대안**(placement 아닌 다른 스킬 multiset) — placement는 실측상 무효라
  진짜 headroom은 그쪽. dense 권위 binding(MEDIUM-1)도 그때 함께.

## 산출물 상태
- plan §3b = DEFERRED 배너 + 실측 표 + 보존 설계(참고용). Phase 3 헤더 갱신.
- **코드 무변경**(maxmargin.py 미구현). verify 프론트매터 무변경(여전히 3a까지). 회귀 0(엔진·툴 무수정).
- probe 스크립트는 throwaway(/tmp); 수치는 본 문서·STATUS에 박제.
