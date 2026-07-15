# unresolved-stages-analysis 문서 리뷰 트레일

## Round 1 (2026-07-14, codex gpt-5.6-sol effort high) — verdict: needs-attention

## Findings

### CRITICAL

없음.

### HIGH

1. **S18 해결안이 이미 반증된 “cap 부족” 가설을 재사용합니다.**

보고서는 saved 4/5가 37/40롤에서 상승 중이었다며 cap 60~80 재실행을 우선순위 3으로 둡니다([보고서:87](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:87), [보고서:98](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:98), [보고서:223](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:223)).

그러나 보고서가 인용한 `STATUS.md`의 후속 기록은 이미 `--max-rollouts 80`을 실행했고 후보가 40롤에서 포화되어 “cap 문제 아님”, “model.py 휴리스틱 손질 필요”로 결론 냈습니다([STATUS.md:671](/D:/claude/godot/CandyAnts/codex-worklog/solver/STATUS.md:671), [STATUS.md:674](/D:/claude/godot/CandyAnts/codex-worklog/solver/STATUS.md:674)). 현 코드에서 후보 공간이 달라졌다는 증거 없이 동일 cap만 재실행하면 같은 조기 소진을 반복할 가능성이 높습니다.

권장 액션은 “cap 상향”이 아니라 휴리스틱 변경 여부 확인 → 변경됐다면 재실행, 아니면 blocker/climber carry-chain 휴리스틱 보강으로 수정해야 합니다.

2. **`solve.py` 수정의 스윕 파급이 S24/25로 제한된다는 주장이 틀렸습니다.**

명시된 S1~23은 실제로 `total_ants` 값을 가지므로 파싱 결과와 보상 의미론은 그대로입니다. 하지만 스윕의 캠페인 지문은 `solve.py` 원시 바이트를 전역 매니페스트에 포함합니다([sweep_stages.py:68](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:68), [sweep_stages.py:85](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:85)). 이 지문은 기본적으로 모든 스테이지에 공통 적용되고([sweep_stages.py:210](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:210), [sweep_stages.py:218](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:218)), 불일치 시 완료 기록이 스킵되지 않습니다([sweep_stages.py:113](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:113), [sweep_stages.py:122](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:122)).

게다가 `runtime_digest`도 `solve.py`를 포함해 모든 replay cache를 전역 무효화합니다([solution_registry.py:165](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:165), [solution_registry.py:177](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:177), [solution_registry.py:212](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:212)).

따라서 [보고서:188-191](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:188)의 “명시 스테이지 byte-identical, S24/25만 자동 재시도”는 다음처럼 제한해야 합니다.

- 보상/롤아웃 의미론: S1~23 불변
- 스윕 완료 지문·replay cache: 전 스테이지 무효화
- 의도한 실행: 반드시 `--stages 24,25`처럼 범위 제한

3. **S25 수식은 맞지만, 그 한 건으로 학습 실패의 인과까지 확정한 것은 과대주장입니다.**

실제 코드 체인은 정확합니다.

- 누락 기본값 0: [solve.py:186](/D:/claude/godot/CandyAnts/tools/solver/solve.py:186), [solve.py:190](/D:/claude/godot/CandyAnts/tools/solver/solve.py:190)
- `max(1, 0)`: [mdp.py:305](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:305), [mdp.py:308](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:308)
- 엔진 기본 10과 실제 소비: [StageData.gd:7](/D:/claude/godot/CandyAnts/scripts/core/StageData.gd:7), [StageRunner.gd:92](/D:/claude/godot/CandyAnts/scripts/core/StageRunner.gd:92)
- S24/25 필드 부재: [stage24.tres:6](/D:/claude/godot/CandyAnts/data/stages/stage24.tres:6), [stage25.tres:6](/D:/claude/godot/CandyAnts/data/stages/stage25.tres:6)
- 보상 상수와 공식: [mdp.py:157](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:157), [mdp.py:847](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:847), [mdp.py:860](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:860), [mdp.py:882](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:882)
- redirect 계산: [model.py:318](/D:/claude/godot/CandyAnts/tools/solver/model.py:318), [model.py:349](/D:/claude/godot/CandyAnts/tools/solver/model.py:349)

보고된 trace 입력값 `goal_dist=6`, `redirect_value=101`, retired=0을 전제로 하면:

`-0.22 + 0.5×(1−6/49) + 101/49 = 2.280000…`

이며 분모 10에서는 `0.424898… ≈ 0.43`입니다. 산술은 정확합니다.

하지만 저장소에 남은 로그에는 bestR와 plan만 있고 해당 trace 집계값은 없습니다([stage25.attempt01.log:34](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage25.attempt01.log:34), [stage25.attempt01.log:36](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage25.attempt01.log:36)). 또한 학습 로그는 aggregate `meanR`와 `meanShape`만 기록하고 blocker 항이나 task outcome을 분해하지 않습니다([train.py:1405](/D:/claude/godot/CandyAnts/tools/solver/rl/train.py:1405), [train.py:1432](/D:/claude/godot/CandyAnts/tools/solver/rl/train.py:1432)).

따라서 [보고서:168-170](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:168), [보고서:203](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:203)의 다음 결론은 아직 확정할 수 없습니다.

- 2400eps×3 전체가 blocker 파밍에 소비됨
- 분모 결함이 미클리어의 원인임
- “학습이 약해서” 같은 대안 가설이 배제됨

확정 가능한 것은 “기존 reward와 유형⑤ 판독이 심하게 오염되어 resume 근거로 쓸 수 없다”까지입니다. 철회 자체는 타당하지만, 실패 인과 확정에는 수정 전후 동일 seed A/B 또는 episode별 blocker/task 항 분해가 필요합니다.

### MEDIUM

4. **S21의 “무거운 에피소드 때문에 실질 탐색량 최소”와 “단조 상승 중”이 로그와 맞지 않습니다.**

세 seed 모두 정확히 batch 150, 2400eps를 완료했습니다. wall time이 길었던 것은 비용 증가이지 샘플 수 감소가 아닙니다([stage21.attempt01.log:17](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage21.attempt01.log:17), [stage21.attempt01.log:35](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage21.attempt01.log:35), [stage21.attempt01.log:53](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage21.attempt01.log:53)).

또한 seed1 bestR은 batch110 이후 0.531로 정체했고, seed2도 batch140 이후 개선되지 않았습니다. meanR 역시 문자 그대로 단조 증가하지 않습니다. [보고서:121-128](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:121)의 “예산 내 미수렴”은 seed0에는 개연성이 있지만 세 seed 공통 원인으로 확정하기엔 약합니다.

5. **S10의 강제 경로와 액션 수 하한은 증거보다 강하게 표현됐습니다.**

보고서는 witness가 전무하고 solvability도 미검증이라고 인정하면서([보고서:47](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:47)), 곧바로 `leaf_jump×2 → cutter → digger → climber×N` 외 대안이 없고 ≥7액션이라고 주장합니다([보고서:49](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:49), [보고서:59](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:59)).

레이아웃과 인벤토리는 이 경로를 시사하지만, cutter/digger 필수성·climber 필요 수·slideR을 이용한 우회 부재를 입증하지는 않습니다. 정확한 순서와 `max_len>6`은 “probe할 주가설”로 내려야 합니다.

6. **`--stall-any-batches 60`의 비용을 “0(플래그)”로 적은 것은 실행·통합 비용을 숨깁니다.**

현재 `sweep_stages.py`의 `RECIPE`에는 해당 플래그가 없고([sweep_stages.py:46](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:46)), 러너 CLI도 stage/max-len만 받습니다([sweep_stages.py:187](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:187)). “스윕 레시피 편입”에는 코드 수정, 지문 변경, 그리고 실제 재스윕 시간이 필요합니다.

따라서 [보고서:226](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:226)의 비용은 “구현 소 / 실행 대”처럼 분리해야 합니다.

7. **“S24/25 RL 데이터 전부 오염”은 범위가 과합니다.**

S24에서 현재 r2.1 reward가 달라지는 것은 retired가 0이 아닌 episode의 shaping 항과, blocker redirect가 발생한 episode입니다([mdp.py:863](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:863), [mdp.py:887](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:887)). 두 값이 0인 episode의 reward는 동일합니다. [보고서:221](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:221)은 “두 스테이지의 정규화 관련 reward/관측은 신뢰 불가” 정도가 정확합니다.

### LOW

8. **수정안에 영구 회귀 테스트가 없습니다.**

제안된 임시 `.tres` 동치 probe([보고서:192](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:192))는 이번 수정은 확인하지만, `StageData.gd` 기본값과 Python 기본값이 다시 어긋나는 것을 막지 못합니다. “필드 누락→10”, “명시값→그 값”을 고정하는 단위 테스트가 필요합니다.

## 확인된 주장

- §4.1의 코드 결함 체인과 2.280 산술은 정확합니다. 단 `goal_dist=6`과 `redirect_value=101`은 저장된 trace가 없어 독립 재측정이 필요합니다.
- 부록 A는 정확합니다. `level_digest`는 세 파일의 raw bytes를 순서대로 해시합니다([solution_registry.py:250](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:250), [solution_registry.py:260](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:260)). S17·20·21·23·24·25 모두 HEAD 세 파일을 CRLF로 변환한 digest가 `attempts.jsonl` 값과 정확히 일치했습니다.
- EOL 정규화 시 기존 레지스트리 digest가 달라져 해가 reset될 수 있다는 호환 위험 서술도 맞습니다([solution_registry.py:439](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:439), [solution_registry.py:441](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:441)).
- 07-13의 S25 유형⑤ 철회는 타당합니다. 다만 새 보고서는 “판독 무효”를 넘어 “실패 인과 확정”까지 나간 부분을 낮춰야 합니다.

현재 Godot 4.6.2 헤드리스는 알려진 S24 witness에서도 signal 11로 충돌하여 새 trace 리플레이는 완료하지 못했습니다. fresh-context/cross-model 리뷰도 작업 정책과 외부 CLI 승인 부재로 수행하지 않았습니다.

**최종 verdict: needs-attention**


## Round 2 (2026-07-14, codex gpt-5.6-sol effort high) — verdict: needs-attention (HIGH 0, MEDIUM 4, LOW 2)

## CRITICAL / HIGH

없음.

## MEDIUM

1. **S25의 “파밍”이 미확정이라고 정정했지만, 제목과 재실험 설명은 여전히 확정적으로 표현합니다.**

   본문은 “2400eps×3seed가 파밍에 소모됨”과 미클리어 인과를 미확정으로 둡니다([분석:186](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:186)). 그러나 절 제목은 여전히 “밀폐실 왕복 파밍”을 확정 원인처럼 열거하고([분석:158](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:158)), A/B 설명도 수정 후 “파밍 소실”을 전제합니다([분석:229](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:229)).

   분모 수정 후 blocker bonus는 0이 아니라 약 0.206으로 축소될 뿐입니다([mdp.py:882](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:882)). 따라서 “파밍 소실”이 아니라 “과대 정규화 제거 후 파밍성 행동·학습 궤적 변화 측정”이어야 합니다. Round 1 H3는 대부분 해소됐지만 이 표현 잔여로 완전 폐쇄되지는 않았습니다.

2. **오염 범위가 아직 넓습니다: 실제 r2.1 관측은 영향받지 않았고, S24 bestR도 판독 가능합니다.**

   보고서는 S24/25의 정규화 관련 “reward/관측”과 `bestR/meanR`를 모두 판독 불능으로 묶습니다([분석:195](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:195)). 하지만 `total_ants`로 정규화되는 trace 관측은 `obs_flat_r3` 경로입니다([mdp.py:898](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:898), [mdp.py:908](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:908)); 문제의 스윕은 r2.1이므로 실제 학습 관측 오염으로 서술하면 안 됩니다.

   또한 S24의 세 best plan에는 blocker가 없고([stage24 로그:18](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage24.attempt01.log:18), [stage24 로그:36](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage24.attempt01.log:36), [stage24 로그:54](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage24.attempt01.log:54)), `bestR=0.398`은 1액션 패널티 −0.02와 shaping 0.418의 합입니다. retired가 1 이상이면 최대 goal shaping 0.5에서 이미 0.1 이상 차감되므로 이 값이 나올 수 없습니다([mdp.py:860](/D:/claude/godot/CandyAnts/tools/solver/rl/mdp.py:860)). 즉 S24 `bestR`은 이 결함의 영향을 받지 않았습니다. 정확한 범위는 “S25 bestR/meanR, S24 meanR 일부와 관련 reward 채널”입니다. Round 1 MEDIUM 7은 부분 해소입니다.

3. **제안된 “동일 seed A/B”는 현재 설명대로면 엄격한 A/B가 아닙니다.**

   판정 실험은 수정 후 S24/25를 다시 돌려 기존 로그와 비교하는 형태입니다([분석:229](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:229)). 그런데 기존 S24/25 attempts는 크로스PC 자료라고 문서가 직접 밝힙니다([분석:280](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:280)). EOL 동일성은 레벨 콘텐츠만 입증하며 엔진 바이너리·Python/PyTorch 환경까지 통제하지 않습니다.

   인과 판정용이라면 같은 머신·런타임에서 수정 전/후 arm을 모두 실행하거나, 기존 로그 비교를 “역사적 동일-seed 대조”로 낮춰야 합니다. 그렇지 않으면 차이를 분모 수정 하나에 귀속할 수 없습니다.

4. **S21은 탐색량 서술은 고쳤지만, 정답 경로의 필수성은 여전히 증거보다 강합니다.**

   문서는 `sand_mound` cap-onto-ledge와 bridge/slideL 결합을 “필수”, “인벤토리가 강제”한다고 단정합니다([분석:127](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:127), [분석:141](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:141)). 그러나 동시에 witness 전무·solvability 미검증을 인정합니다([분석:135](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:135)). 로그가 입증하는 것은 세 best plan이 mound를 인근에 시도했다는 것뿐입니다([stage21 로그:18](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage21.attempt01.log:18), [stage21 로그:36](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage21.attempt01.log:36), [stage21 로그:54](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_out/stage21.attempt01.log:54)). S10처럼 “probe할 주가설”로 낮추는 것이 정직합니다.

## LOW

1. **S18 probe가 사용할 수 없는 “추가 blocker”를 제안합니다.**

   인벤토리는 blocker 2개이고([분석:83](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:83)), 출발점인 니어-해가 이미 blocker×2를 모두 사용합니다([분석:91](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:91)). 따라서 “추가 blocker/climber 슬롯” 중 추가 blocker는 불가능합니다([분석:105](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:105)). “남은 climber 1개 추가 또는 기존 blocker 재배치·발화 조정”으로 고쳐야 합니다.

2. **S25 독립 재측정은 방법론은 타당하지만 결과 증거가 보존되지 않았습니다.**

   4500f 로컬 결정론 replay로 `goal_dist=6`, `redirect=101`을 다시 측정하는 방식과 산술은 타당합니다([분석:172](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:172)). 다만 저장소에는 해당 trace 출력이나 정확한 4500f 재현 커맨드가 없고, 부록에는 일반적인 7000f replay 형식만 있습니다([분석:281](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:281)). 핵심 수치가 문서 자기보고에만 남으므로 trace 요약이나 재현 커맨드를 근거 데이터로 보존하는 편이 안전합니다.

## 확인 결과

- S18 cap 반증과 STATUS 5d① 인용은 정확하며 cap 상향 권고도 제거됐습니다([STATUS:671](/D:/claude/godot/CandyAnts/codex-worklog/solver/STATUS.md:671)).
- `solve.py` 수정의 캠페인 지문·`runtime_digest` 전역 무효화 설명과 `--stages 24,25` 제한 권고는 실제 코드와 맞습니다([sweep_stages.py:68](/D:/claude/godot/CandyAnts/tools/solver/rl/experiments/sweep_stages.py:68), [solution_registry.py:165](/D:/claude/godot/CandyAnts/tools/solver/solution_registry.py:165)).
- S21의 3 seed 완주, seed0만 마지막 갱신, seed1/2 후반 정체 서술은 로그와 일치합니다.
- §6의 2번 실행 순서와 6번 “구현 소/실행 대” 분리는 타당합니다.
- S10 확정투, stall-any 비용 은폐, 회귀 테스트 부재는 해소됐습니다.

**최종 verdict: needs-attention**

교차 모델은 외부 CLI 승인 부재로 수행하지 않았습니다.


## Round 3 (2026-07-14, codex gpt-5.6-sol effort medium, R2 수정 6건 한정 검증) — 6/6 해소 + 신규 MEDIUM 1(§6 표↔§4.1 오염범위 문구 충돌)

- M1 — **해소**: §4 제목에서 ‘파밍’ 확정투가 제거됐고, A/B는 blocker 항의 `~0.206` 축소와 행동·학습 궤적 측정으로 수정됨([문서:164](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:164), [문서:239](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:239)).
- M2 — **해소**: r2.1 학습 관측 비오염이 명시됐고, S24 bestR `0.398 = −0.02 + 0.418`, `retired=0`, blocker 없음이라는 무영향 근거가 반영됨([문서:197](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:197), [문서:204](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:204)).
- M3 — **해소**: 같은 머신·런타임에서 양 arm을 실행하도록 했고, 기존 크로스PC 로그는 역사적 참고 대조로 격하됨([문서:239](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:239)).
- M4 — **해소**: S21 경로 필수성이 ①에서 `[주가설 — probe 대상]`으로 명시됐으며, 근거도 가설·조건부 정황으로 제한됨([문서:128](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:128), [문서:142](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:142)).
- L1 — **해소**: 추가 blocker 제안이 사라지고 잔여 climber 1 조정 또는 기존 blocker 재배치·발화 조건 조정으로 변경됨([문서:104](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:104)).
- L2 — **해소**: 부록 B에 S25 bestR `2.280`의 로그 추출→리플레이→항별 계산→실측값 대조 절차가 보존됨([문서:300](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:300)).

신규 finding:

- **MEDIUM**: §6 우선순위 표가 “S24/25의 정규화 관련 reward·관측은 신뢰 불가”라고 포괄적으로 요약해, §4.1의 “r2.1 학습 관측은 비오염” 및 “S24 bestR은 무영향”과 충돌함([문서:274](/D:/claude/godot/CandyAnts/codex-worklog/solver/2026-07-14-unresolved-stages-analysis.md:274)). §6 문구를 §4.1에 정의된 정확한 오염 범위로 좁혀야 함.

최종 verdict: **needs-attention**.


### Round 3 후속 처리
- 신규 MEDIUM 1건 = §6 표 1번 근거 문구를 §4.1의 정밀 범위(S25 bestR/meanR 전반 + S24 meanR retired>0·blocker 에피소드 부분, r2.1 관측·S24 bestR 무영향)로 좁혀 즉시 수정. HIGH 0 · 잔여 finding 0 → plan-stage 정책(M/L은 문서 내 처리로 종결)에 따라 **리뷰 종결**.
