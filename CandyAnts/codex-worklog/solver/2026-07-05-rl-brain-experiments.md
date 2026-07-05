# RL 공유-뇌(brain) 에이전트 실험 — 2026-07-05 세션 정리

> 다음 세션 재개용. main 브랜치. 목표가 "스테이지 자동풀이"에서 **"누적하며 똑똑해지는 RL 에이전트"**로 진화.
> 산출 코드는 커밋됨(아래), 뇌 런타임 산출물(brain.pt 등)은 `data/solutions/found/`(gitignore).

## 1. 이번 세션 커밋 (전부 main, **7커밋 전부 미push** — `git push` 필요)

| commit | 내용 |
|---|---|
| `709bf70` | RL 해 발견 즉시 기록 — `train.py`가 클리어 순간 `data/solutions/found/`(log.jsonl+sidecar)에 기록 |
| `1c51056` | 쉬운 실행 런처 `tools/solver/rl/rl.py` + `run_rl.bat` |
| `9323d14` | 공유-뇌 커리큘럼 트레이너 `tools/solver/rl/brain.py` (하나의 r2.1 정책이 1~10 담당) |
| `0f95030` | brain: 게이트-순차 → 전체 순회 + distinct 해 기록(`brain_solutions.jsonl`) |
| `debade8` | brain 안정화: lr 3e-3→1e-3 + grad clip + best-ckpt + 예산 재분배 + 보상 정규화 |
| `f70bd7c` | 예산 뺏기 → **잭팟 이월**(못 깬 스테이지가 미지급 클리어 보상 누적) |
| `6e00b71` | **reachability-확장 보상**(새 땅 도달) + 탐험 강화(엔트로피 0.08) + 달성률% 가시화 |

`.gitignore`에 `data/solutions/found/` 추가됨.

## 2. 풀이 현황 (실측 검증)

- **1~8 전부 해결**(saved==hp): 1~4=r1.1, 5·7·8=r2.1 단독, **6=이번 세션 r2.1 단독**(seed1, eps=1600, ckpt `data/solutions/rl_ckpt/stage06_seed1.r2.pt`).
- **9·10 미해결** — 다중 스킬 조합 스테이지(9=bridge+basher+blocker+sand_mound, 10=slideR+digger+cutter+leaf_jump+climber). 단독 r2.1 단일-seed로 실패.
- 해는 `found/*.found.json` + `stageNN.rl/rl2.json`.
- **stage 6 해 플랜**: digger×1 @(14,0) + climber×5 (도구 정상 사용).

## 3. 아키텍처 사실 (검증됨)

- **r2.1 문법** = 전역 어휘 + 스테이지-불변 정책(AdaptiveMaxPool CNN + 전역 스킬 head + per-stage 마스킹). **하나의 가중치가 1~10 전부에 로드**(정책 shape 동일 실측: max_len=6, flat_dim=816, heads 동일). 공유-뇌의 근거.
- **r1.1** = ant-target 전용, cell-target 스킬(digger/basher/sand_mound 등) 표현 불가 → 그런 스테이지는 r1.1로 못 풂.
- **단독**(`train.py --stage N`) = 스테이지 집중 / **뇌**(`brain.py`) = 누적 공유. **둘 다 같은 r2.1 아키텍처**, 학습 방식만 다름.

## 4. 핵심 RL 발견 (이번 세션의 실체)

1. **뇌 멀티태스크**: 한 네트워크가 **6개 동시 클리어**(1,2,4,7,8 + 3=4/5). 하지만 **5~6/10에서 정체**, 5·6·9·10을 뇌에선 못 풂(멀티태스크 희석). 진동(5↔6)·붕괴(cycle 43=0).
2. **전이·"똑똑해짐" 없음(반증)**: 뇌가 1~8+9를 40+ 사이클 동시학습해도 **9는 pickup 0 고정**. 오히려 **단독 < 뇌** (단독은 5·6·7·8 풀고 뇌는 5·6 못 풂). → 누적-지능 가설 **미입증, 스테이지별 암기**.
3. **병목 = pickup(1차)이지 복귀(2차) 아님**: 실측상 **전 스테이지 picked==saved**(복귀는 완전 학습). 하드(5·6·9·10)는 **pickup=0**(사탕 도달 실패), 3은 4/5(5번째 못 집음). 병목 = **길 여는 배치 발견**.
4. **보상은 이미 잘 설계됨**: 비율(saved/hp) + 단계(picked 0.3 + saved 1.0 + goal거리 shaping 0.5) + 100%보너스(cleared 2.0). candy-접근 shaping도 이미 있음(`best_goal_dist`: 픽업 전→candy, 후→home). 보상-쪼개기 아이디어는 이미 구현돼 있었음.
5. **학습 vs 운 (stage 6 곡선)**: meanR 0.33→0.60 **체계적 상승**(진짜 gradient 학습, 전 seed). 그 뒤 **고원→클리어 도약(0.6→2.68)은 1/3 seed만**(확률적 발견), 발견 후 학습이 각인. → **학습=shaping 고원 오르기(실력), 최종 해 발견=이산 점프(운)**. 9·10은 도약이 커서 실패.
6. **reward-seeking 확증 (교란 실험, stage 6)**: 교란 보상(왼쪽 깊이 파기 decoy) → 네트워크가 **학습(meanR 0.18→3.2)해 왼쪽 row 20 굴착, solving 포기(saved=0)**. 대조(정상 보상, 동일 셋업) → **사탕 추구(picked 0→5), 왼쪽 안 팜(deep_left=8)**. **같은 아키텍처, 보상이 행동을 결정** = 능동적 보상 추구(학습 과정의 성질; 얼어붙은 정책에 "욕구"는 없음). *stage 5 교란은 무효(decoy가 스폰+min-over-time 혼동)로 폐기.*
7. **retention 부분 긍정**: stage 6 해결망 로드 → stage 5(다른 도구) 60배치 학습 → **stage 6 전 구간 5/5 보존**(stage 5는 4/5 습득). 가벼운·다른-도구 간섭엔 휘발 없음. **단, 멀티태스크 뇌는 무거운 부하에서 휘발**. climber-스테이지 간섭(같은 도구 덮어쓰기) sharp 테스트는 **미실행**.

## 5. 사용자가 확정한 성공 기준

1. **비휘발(retention)**: 새 학습해도 이전 스테이지 지식 유지.
2. **전이(transfer)**: 이전 학습이 **다음 도전의 시도 횟수(eps)를 유의미하게 감소**.
3. **추론(inference)**: 해를 모르는 상태에서 스스로 찾아야 함 — **SIL 주입 거부**("암기지 지능 아님").

## 6. 다음 세션 후보 작업

1. **sharp retention 테스트**: stage 6 해결망 → **stage 1(climber) 간섭** → stage 6 climber 사용 보존/휘발 판정 ("climber 재학습=휘발" 가설 정면).
2. **전이 측정**: 사전학습망이 새 스테이지를 scratch보다 적은 eps에 푸는가. (함정: stage 6 digger는 고유 → 전이 제한적. 9·10 조합이 진짜 전이 타깃.)
3. **9·10 단독 해결**: 조합 스테이지, 더 많은 seed/budget 필요. 3 seed 병렬 30분 드라이버(`scratchpad/solve_stage.sh` 패턴)로 stage 6은 성공(1/3 seed).
4. **핵심 연구 질문**: 1~8 학습이 9·10 조합에 **전이·재사용**되게 하기. 현 표현은 per-stage 암기 경향 → 표현/구조 재설계가 필요할 수 있음.

## 7. 재사용 자산 (repo로 이관 완료: `tools/solver/rl/experiments/`, 미커밋)

- `solve_stage.sh <N>` — 단일 스테이지 3-seed 병렬 집중 공략(30분).
- `perturb_stage6.py` — 보상 교란 실험(유효판).
- `control_stage6.py` — 정상보상 대조.
- `retention_test.py` — 해결망 로드→간섭→보존 추적.
- `measure_partial.py` — brain.pt 로드→스테이지별 picked/saved 실측.

## 8. 유용한 명령

```powershell
python tools/solver/rl/brain.py --show          # 뇌 숙련/달성률 곡선
python tools/solver/rl/brain.py --cycles N       # 뇌 이어서 학습
python tools/solver/rl/rl.py --list              # 스테이지별 해/기록 현황
python tools/solver/rl/rl.py <N> --seeds 3       # 단독 스테이지 학습
bash scratchpad/solve_stage.sh <N>               # 단독 3-seed 병렬 집중
```
- godot 재임포트 필요 시(.godot 삭제 후): `& "D:\Godot_v4.6.2-stable_win64_console.exe" --headless --import --path .`
