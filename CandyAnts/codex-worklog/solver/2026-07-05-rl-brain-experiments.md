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

---

## 9. 후속 세션 (2026-07-06) — §6.2 전이 측정 착수 → **스킬-배치 보상 부재**로 중단

전이 측정(성공기준 #2: 이전 학습이 다음 도전의 eps를 유의미 감소시키는가)을 시작했다가, **보상 설계 결함**을 확인하고 사용자 지시로 중단. 다음 세션에 보상부터 개선.

### 9.1 이번에 한 것
- **`tools/solver/rl/experiments/transfer_test.py` 신설**(미커밋 실험자산). `train.py:train_seed` 무수정 재사용 — 이미 `(result{episodes,batches,cleared}, state)` 반환 + `ckpt_mode="transfer"`(cross-stage 가중치 이월, 스테이지-파생 상태 리셋) 네이티브 지원. `--calibrate`(scratch batches-to-clear 실측) / `--source-ckpt "…stage11_seed{seed}.r2.pt"`(기존 해결 ckpt 무료 재사용, source 재학습 생략) 지원. 양 조건에 **동일 레시피**(R2_PIN: trace+SIL+train_deadline 4500) 적용, 유일 차이=source 사전학습 유무.
- **캘리브레이션 실측**: stage11(blocker×1)=**CLEAR @15 batch**(자명, 완벽한 source) / stage12(blocker×3)·stage17(blocker×4)=**DNF @cap120, bestR 0.447 정체**(메모리 기록된 그 정체점 — trace shaping만으론 다-blocker 배치 탐험장벽 못 넘음).
- **S12 해결 예산 확인**(stage12.rl2.json): 문서화된 transfer 사슬 [11→12]로도 **seed 0/1 DNF(280·305 batch, 30분 wall 도달), seed 2만 CLEAR @150 batch**. → S12는 무겁고 확률적(1/3).
- **설계 근거**: 1~10 커리큘럼 내 공유 스킬(climber 1·6, floater 2·5)은 모두 병목이 **아님**(6=digger 고유, 5=sand_mound 고유) → 전이 원천 제한. **blocker 계열(11/12/17)만이 공유 스킬=주 동작(병목) 스킬** → 전이의 진짜 기회. 그래서 target=12, source=11 선정.

### 9.2 핵심 결함 (사용자가 표면화) — **스킬 보상 미구현**
검증(mdp.py:587·600): 보상은 **전적으로 결과/상태 기반**, 스킬을 스킬로 인정하는 항이 **전무**.
- `reward()`(터미널): cleared 2.0 / saved·picked·lost /hp / **len_penalty −0.02×plan_len(스킬 많이 쓰면 감점)** / timeout −0.1.
- `shaped_bonus()`(trace): goal 0.5×(1−목표거리/D0) + retired −0.1×갇힌비율.
- brain `_reach_bonus`(brain.py 한정, **train_seed 전이 경로엔 없음**): 새 도달셀 수 — 스킬-무관.
- → 정책이 배우는 것 = **"이 레이아웃에서 이 배치 = 구조 성공"** 레이아웃-국소 입력→출력 매핑. "blocker 쓰는 법"이라는 재사용 스킬 표현이 gradient에 없음 → **per-stage 암기는 필연**.

### 9.3 사용자 방향 (내일 짚을 것)
- **stage 12의 코어 = blocker를 좋은 위치에 놓기.** blocker가 **새로운 방해 요소(obstacle)** 로 동작하는 스테이지. 현 보상은 좋은/나쁜 blocker 배치를 **구별 못 함** → 전이 실험이 무의미.
- **다음 세션 = 보상 개선 먼저**: 스킬-배치/스킬-사용 품질에 gradient를 주는 보상(특히 S12의 blocker-as-obstacle) 설계 → §6.4(표현/구조 재설계)의 구체적 첫 수. 개선 후 전이 재측정.
- 전이 실험은 이 보상 개선 **전까지 보류**(현 상태에서 돌려봐야 "무전이"만 재확인).

### 9.4 상태
- 전이 실험은 실행 중 **사용자 지시로 중단**(결과 미기록, orphan godot 없음 확인). `transfer_test.py`는 보존(재개 시 그대로 사용).
- 커밋 상태 불변: 8커밋 이미 push됨(HEAD=origin/main=`0a81255`). `transfer_test.py`만 신규 untracked.

---

## 10. 후속 세션 (2026-07-06 오후) — §6.4 첫 수: 생산적 blocker 활용도 보상 (구현·검증 완료, 학습 실험 대기)

목표(§9.3): S12 blocker-as-obstacle 배치 품질에 gradient를 주는 보상. **미커밋** (tool 파일만 변경).

### 10.1 실증으로 뒤집힌 가설 (정직 반증)
사용자 최초 아이디어 = "blocker uid별 충돌 횟수 > 남은개미×3이면 나쁜 배치". **엔진 계측(임시)로 실측 → 반증**:
| 플랜 | per-blocker bumps | total | saved | 결과 |
|---|---|---|---|---|
| GOOD(알려진 해) | 12,6,5 | **23** | 5/5 | ✅ |
| BAD(동선밖) | 1,1,5 | 7 | 0/5 | ❌ |
| BAD(트랩시도) | 7 | 7 | 0/5 | ❌ |
- **좋은 해가 bumps 최다**(23, 임계 3×8=24 바로 아래). blocker0=12는 왼쪽 물가 가드레일이 개미 행렬을 반복 반전=제 역할.
- **메커니즘**: `bumped_blocker`에 per-pair+per-frame 가드([Ant.gd:809-821])가 있어 **트랩이 bump 폭발을 못 만든다**(갇힌 개미도 7회). bump=갇힘강도 아니라 **리다이렉트 이벤트 수 = 생산적 라우팅**에 가까움.
- → 사용자 결정: **생산적 활용도(bump×진척)로 선회**.

### 10.2 구현 (opt-in — pinned 게이트 보존이 핵심 제약)
- `model.blocker_redirect_value(trace, layout, blocker_cells)` (신규, 순수): blocker 셀 인접(Chebyshev≤1) 수평 반전을 겪은 개미의 (시작−최소) goal_dist 진척 합. blocker-귀속 게이트=스킬 의미론=전이 가능.
- `StageMDP.blocker_bonus(res, coef)` + `blocker_cells_from_res(res)` (신규): `+coef·redirect_value/(D0·ants)`. 셀 출처 = **기존** `fired_actions.target_pos`(report_fired) — 엔진/드라이버 무변경.
- `train.py`: `--blocker-coef`(default 0.0=완전 no-op). >0이면 롤아웃에 `report_fired` 부착 + non-refine reward에 가산. cfg에 `blocker_coef` 키(verify는 subset-대조라 무시 → **R1/R2 pin byte-identical 보존** 실측 확인). refine 경로는 미배선(가드 raise).
- `solve.run_plan(..., report_fired=False)` 인자 추가(측정용).
- **드라이버(Ant.gd/PlanRunner.gd)는 최종 무변경** — 초기 bump-카운터 계측을 넣었다가 `_exec_config_digest`가 PlanRunner.gd 파일해시를 S13 R3 pin에 바인딩함을 발견 → 되돌림(보상은 bump 불필요, target_pos+trace로 충분).

### 10.3 격리 검증 (Godot 실측, coef=1.0)
- **구별**: GOOD bonus=+0.276(redirect_value 108) vs BAD=+0.0(0). 깨끗이 분리.
- **고원 gradient 증폭(핵심)**: 현 보상은 생산적 good[:1](blocker1개, saved=0)을 useless BAD_A보다 **+0.015**만 선호(=배치분산에 묻힘=고원). 새 항이 그 마진을 **+0.247로 ~16배 증폭**. good[:1]이 saved=0인데 bonus 0.232 = **첫 save 전 dense 신호**(고원 탈출).
- 상한: shaped(0.49)+redirect(0.28)=0.77 < cleared(2.0) 유지.

### 10.4 상태·다음
- **학습 실험 대기**: `python tools/solver/rl/train.py --stage 12 --grammar r2.1 --seeds 1 --envs 4 --shaping trace --train-deadline 4500 --sil --blocker-coef 1.0 --no-save`(⚠ `--no-save` 필수 — 없으면 config 불일치로 pinned stage12.rl2.json 덮어씀, 이번에 1회 clobber→git 복원함). 진짜 테스트 = 이 신호로 S12 고원(0.447)을 넘어 클리어하는가.
- 측정 스크립트: scratchpad `measure_bumps.py`(GOOD/BAD/부분플랜 redirect_value 비교).
- 커밋 상태 불변(HEAD=`0a81255`). 변경=tool 3파일(model/mdp/train)+solve.py, 미커밋.

## 11. 후속 세션 (2026-07-07) — §10 학습 실험 실행 → **S12 고원 돌파 확정** (0/3 FAIL → 2/3 CLEAR)

§10.4의 학습 실험을 실제로 돌림. `--blocker-coef 1.0`(+`--shaping trace --sil`) 가설 = **입증**. 여전히 **미커밋**(--no-save).

### 11.1 결과 (S12, r2.1, envs=4, train-deadline=4500, max-wall=1800)
| seed | 판정 | 돌파 | bestR | best plan 요지 |
|---|---|---|---|---|
| 0 | ✅ CLEAR saved=5/5 | batch 60 / eps 960 / wall 400s | 3.993 | blocker×3, y-band 3층(기본/432–480/288–336), 전부 at_frame 300 |
| 1 | ❌ FAIL (collapse) | — (eps 4480 완주) | 0.463 | **blocker×1만** (인벤 3 중 1 사용 후 정체) |
| 2 | ✅ CLEAR saved=5/5 | batch 70 / eps 1200 / wall 426s | 0.905 | blocker×3, y-band 3층(기본/432–480/576–624), frame+ant_reaches_x 혼합 |

**종합: S12 무힌트 2/3 seed 클리어** (train.py 기준 ≥1 → PASS). 메모리·§10의 "S12 stretch 0/3 FAIL"(terminal-only reward)을 **정면으로 뒤집은 첫 학습 클리어**.

### 11.2 핵심 발견
- **가설 확정**: blocker-coef dense 신호가 "blocker 3개를 각 계단 층(y-band)에 배치"하는 다단 전략 발견을 유도 → 고원(0.447/0.463) 돌파. §10.3 격리검증의 gradient 증폭(+0.015→+0.247)이 실제 학습 클리어로 전환됨.
- **seed 1 = collapse attractor 변종**: bestR=0.463 / meanShape 0.351 조기 포화(batch 30, wall 186s) = **blocker 1개 배치 후 local optimum에 갇힘**. 나머지 2개를 못 씀. shaping이 첫 blocker까지는 즉시 dense 보상하나, "2·3개째로 확장"하는 문턱을 seed 1만 못 넘음. seed 0은 batch 30에서 meanR 0.3→1.24 급등하며 즉시 탈출.
- 클리어 해 = `data/solutions/found/stage12_seed{0,2}.found.json` (found/는 git 추적 밖, --no-save여도 기록).

### 11.3 상태·다음 (안정화 착수)
- **안정화(3/3) 목표**: seed 1 collapse 방지. 원인이 "미사용 blocker"로 명확 → CLI 무편집 수단은 `--blocker-coef` 상향(미사용 blocker 탈출 dense 신호 강화). 엔트로피 계수는 CLI 미노출(코드 내부) → 코드 편집은 R3 digest 바인딩 위험이라 사용자 상의 필요.
- 커밋 상태 불변(HEAD=`0a81255`).

### 11.4 안정화 실험 결과 (2026-07-07~08)
- **coef 상향 = 역효과 실증**: seed1 coef=1.0→bestR0.463 / coef=1.5→bestR0.579, **둘 다 blocker 1개에서 collapse**. coef를 올리자 "blocker 1개 배치 즉시보상"만 커져 그 local optimum을 더 매력적으로 만듦(meanR batch100~4000 완전 락). CLI 무편집 탐험 수단 소진.
- **reseed 구현**(사용자 아이디어 "일정 실패 시 seed 교체"): `--reseed-on-fail K`(opt-in, train.py argparse+run_training seed 루프만; `train_seed` 무편집=R0~R3 pin byte-identical, ckpt 모드 배타 가드). FAIL seed→대체 seed(base+1000·attempt) 최대 K회 재시도, `eff_seeds`로 실 seed 재바인딩. `--max-wall` 짧게 줘 collapse seed 조기 포기. **한계(사용자 표면화)**: 대체 seed도 `torch.manual_seed`로 **백지 초기화** → 지식 이월 0 → 재시도 안 빨라짐. reseed=collapse **회피**지 지식 **누적** 아님.
- **reseed 실험 결과(seed1 coef=1.0, --max-wall 700, reseed 2)**: 코드 정상 작동(전환 로그 slot1→1001→2001, 조기종료). **BUT seed 1/1001/2001 3개 전부 bestR=0.463 동일값 collapse(전부 blocker 1개)**. → **§11 "2/3=가설 입증" 결론 정정**: 세 독립 seed의 동일값 수렴 = collapse는 seed outlier 아니라 **강한 구조적 attractor**("blocker 1개 saved=0" 넓은 basin). 원래 seed0/2 성공=**확률적 행운**(coef가 1-blocker basin 강화하기 前 초기탐험으로 3-blocker 우연발견). **blocker-coef=양날의 검**(3-blocker 발견 시 밀어주나 1-blocker 선점 시 dense보상으로 강화→고착; coef1.5 악화와 일관).
- **이번 결과가 사용자 2통찰 실증**: ① 백지 reseed 3회=같은 함정 3회=지식 안 남으면 재시도 무의미(전이 필요 실증); ② 3실패 전부 "blocker 1개" 동일패턴=실패-활용(미사용 blocker 압력)이 회피(reseed)·강화(coef↑)보다 우월. **collapse는 실패-활용 신호로 풀 것.**

## 12. 지식 전이 SOP — "실험할 때 항상 전이 동작하도록" (2026-07-08, 사용자 지침)

**정직한 범위**: "항상 전이가 **동작**"의 최대치 = 메커니즘(저장+로드)을 항상 켜고 scratch 대비 **측정**. cross-stage 전이 **성공은 미보장**(실측 S13 0/3·S11→S12 1/3 확률적; 원인=레이아웃-국소 암기, §9.2). same-stage는 자명(해 각인=암기 재생). 지침은 "항상 시도+측정"이지 "성공 보장"이 아니다.

### 12.1 항상 저장 (`--save-ckpt`)
- 모든 실험에 부착 → `data/solutions/rl_ckpt/stageNN_seedS.r2.pt`(r3=`.r3.pt`, 분리라 미덮어쓰기). 클리어 여부 무관 저장.
- **`--no-save`와 공존**(핵심): `--save-ckpt --no-save` = 가중치 누적 + gated artifact(rlN.json) 미저장 = **pin 보호하며 지식 누적**. 지금까지 실험이 --no-save라 ckpt 미축적이었음 → 앞으로 `--save-ckpt` 상시 부착.
- ⚠덮어쓰기: `ckpt_path`=stage/seed 결정. 같은 stage/seed 재실행 시 덮어씀(§R3 R1 실버그). 중요 성공 ckpt는 백업/seed 분리. reseed는 `eff_seeds`(base+1000·k)로 저장 → 실 성공 seed 확인.

### 12.2 같은 스테이지 이어서 (`--resume-ckpt <path>`)
- fail-closed: stage/layout/mask/seed **전부 일치**(exact). 용도=예산 이어달리기·재개 등가성. 한계=해 각인 자명(지능 아님, "빨라짐" 데모용).

### 12.3 다른 스테이지로 (`--transfer-ckpt <path>`) ← 진짜 지식 전이
- fail-closed: vocab/grammar/model shape 일치, layout/mask 면제. **소스=클리어한 ckpt만**(미클리어/collapse 소스 코드가 거부, line 345-347). 동일 스테이지 거부(resume 쓰라). seed 1개 커맨드 전용.
- 커리큘럼 사슬: `--transfer-ckpt <이전 성공 ckpt> --save-ckpt`(S11→S12→S13…). 예:
  ```
  python tools/solver/rl/train.py --grammar r2.1 --stage 12 --seeds S --sil <예산> \
      --transfer-ckpt data/solutions/rl_ckpt/stage11_seedS.r2.pt --save-ckpt --no-save
  ```

### 12.4 예외·규율 (CRITICAL)
- **pinned 검증 커맨드(R0/R1/R2/R3 acceptance·verify)엔 전이 금지** — 전이 플래그 없이 scratch. byte-identical 보존. 전이는 실험 경로 전용.
- **측정 필수**: 전이 실험은 항상 **scratch 대조군**(동일 seed/budget) 병행 → batch-to-clear 비교로 "빨라짐" 정량 입증. 대조 없는 전이 주장 = 자기기만.
- 커밋 상태 불변(HEAD=`0a81255`). 미커밋 변경=tool 4파일(model/mdp/train/solve) + `--reseed-on-fail`.

## 13. 후속 세션 (2026-07-09) — warm-start 전이 실험 실행 → **S12→S13 전이 성립** (첫 cross-stage 전이 성공)

§12 SOP의 첫 실전 적용. S12 성공 ckpt를 만들고(§13.1) S13으로 전이 vs scratch 대조 측정(§13.2). **결과 = 전이 성립(유의미 감소)** — S11→S12 1/3 확률적·S13 0/3(§R2)을 뒤집은 첫 재현성 있는 전이.

### 13.1 준비 — S12 클리어 ckpt 확보 (§11 재현 + `--save-ckpt`)
- §11 실험이 `--save-ckpt` 없이 돌아 성공 가중치 미보존 → §11 커맨드에 `--save-ckpt`만 부착해 재실행.
- ⚠커맨드 gotcha: `train.py --seeds`는 **콤마 목록**(기본 "0,1,2")이지 개수가 아님. `--seeds 3`으로 오실행 → seed 3이 bestR=0.463 1-blocker collapse로 FAIL. **부수 데이터**: seed 1/1001/2001(§11.4)에 이어 4번째 독립 seed가 동일값 collapse — 구조적 attractor 재확인.
- `--seeds 0,2` 재실행: **seed 0 CLEAR @batch 60/eps 960, seed 2 CLEAR @eps 1200 — §11.1과 batch/eps 일치(결정론 재현 확인)**. `rl_ckpt/stage12_seed{0,2}.r2.pt`(cleared_seg=True) 저장.

### 13.2 본 측정 (transfer_test.py, target=13, seed 0·2, cap 120 batch, 양 조건 blocker-coef 1.0 동일)
| seed | SCRATCH (S13 직접) | TRANSFER (S12 ckpt 이월→S13) |
|---|---|---|
| 0 | CLEAR @batch **120**(=cap 턱걸이, 1075s) | CLEAR @batch **5** (80 eps, 39s) |
| 2 | DNF (cap 120, bestR 0.847 고원) | CLEAR @batch **55** (880 eps, 479s) |

- **판정(드라이버 출력)**: median batch SCRATCH 120 → TRANSFER 30 (+75% 감소) + 클리어율 1/2→2/2 → **전이 성립(유의미 감소)**.
- **전이 매개 특성화**(found/stage13_seed{0,2}.found.json): S13 인벤=blocker×1+climber×5, 두 해 모두 전 인벤 사용·동일 frame 1669 클리어. seed 0 전이 해의 첫 수 = `blocker @ y[288,336] @ at_frame 300` — **S12 seed 0 해의 3층 y-band 중 하나와 동일한 토큰 조합**. 즉 전이 실체 = "blocker+y-band+frame300" 사전(prior)의 재사용(전역 vocab 공유 덕). 5 batch 클리어 = 사실상 즉답.
- **S13 scratch 신규 관측**: blocker-coef 1.0이면 scratch도 고원이 0.660(§R2)→0.847로 오르고 seed 0은 cap 직전 자력 돌파 — blocker-coef가 S13에도 유효. 단 seed 2는 0.847 고원 고착(best plan=blocker 1수만) = S12와 같은 "스킬 1개 사용 후 정체" 패턴.

### 13.3 정직한 한계
- n=2 seed(소스 클리어된 seed만 짝지음), seed 0 scratch는 cap=120 턱걸이 클리어라 median 차이는 cap 민감.
- 전이 매개가 "추상적 blocker 스킬"이라기보다 **좌표-vocab 공유 prior**(y[288,336]이 두 레이아웃 모두에서 유효한 우연 포함)일 수 있음 — 레이아웃이 크게 다른 스테이지(예: S17 blocker×4)로의 사슬 연장이 다음 검증.
- 스테이지-파생 상태는 transfer 시 리셋되므로 이월된 것은 순수 정책 가중치뿐(train.py `ckpt_mode="transfer"` 계약).

### 13.4 자산·상태
- transfer_test.py 보강(미커밋 실험자산): `--blocker-coef`(양 조건 동일 적용)·`--seed-list`(소스 없는 seed 스킵)·소스 ckpt 부재 graceful skip·**SOP §12.1 반영 태그 분리 ckpt 저장**(`stageNN_seedS.r2.{scratch,xfer,calib}.pt` — 본 ckpt 미덮어쓰기).
- 신규 ckpt: stage12_seed{0,2}.r2.pt(cleared) / stage12_seed3.r2.pt(FAIL, resume 전용) / stage13_seed{0,2}.r2.{scratch,xfer}.pt. 신규 해: found/stage13_seed{0,2}.found.json.
- 커밋 상태 불변(HEAD=`0a81255`).

### 13.5 사슬 연장 S13(xfer ckpt)→S17 — **무전이(혼합 ±)** → 좌표-우연 가설 지지
§13.3 한계 검증차 즉시 실행(target=17=blocker×4, source=stage13_seed{0,2}.r2.xfer.pt, 동일 레시피·cap 120).
| seed | SCRATCH (S17 직접) | TRANSFER (S13 xfer ckpt 이월) |
|---|---|---|
| 0 | **CLEAR @batch 70** (bestR 3.977) | DNF (bestR 3.779, meanR 3.77 포화) |
| 2 | DNF (bestR 3.782, meanR 3.76 포화) | **CLEAR @batch 85** |

- **판정(드라이버)**: median 70→85(−21%) + 클리어율 1/2→1/2 → **미미/무전이**. seed 0은 전이가 오히려 해(scratch가 이김), seed 2는 반대 — n=2 혼합 = 노이즈 수준, 계통적 이득 없음.
- **해석**: S12→S13 성공(§13.2)과 정면 대비 — S13 해와 S17 해는 필요한 y-band 구성이 다름(S17 DNF best plan=144–192/288–336/576–624 4수 조합). 전이 prior(y[288,336]+frame300)가 해 토큰과 직접 겹칠 때만 즉답이 나오고, 겹치지 않으면 무전이. → **§13.3의 "좌표-vocab 우연 공유" 해석 지지, "추상적 blocker 스킬 습득" 해석 기각에 가까움**(§9.2 레이아웃-국소 암기 진단과 일관).
- **부수 발견(중요)**: blocker-coef 1.0이면 **S17 scratch도 1/2 CLEAR** — §9.1 캘리브(DNF@cap120, bestR 0.447 정체)를 크게 갱신(bestR 0.447→3.78+, 4-blocker 다단 plan 자력 발견). blocker-coef의 효과가 S12·S13·S17 3개 스테이지에서 일관 확인. 단 양 seed 공히 meanR≈3.77 포화·greedy 미클리어 구간이 김 = near-clear 고원(새 attractor 후보).
- 신규 ckpt: stage17_seed{0,2}.r2.{scratch,xfer}.pt / 해: found/stage17_seed{0,2}.found.json.

### 13.6 종합·다음
- **이번 세션 결론**: ① 전이 메커니즘(SOP §12)은 동작하고 측정도 정직하게 됨. ② **전이 성공은 해-토큰 중첩 조건부**(S12→S13 ○ / S13→S17 ×) — "재도전이 빨라지는 똑똑함"은 인접 레이아웃에서만. ③ blocker-coef는 3개 스테이지 일관 유효(무힌트 클리어 S12 2/3·S13 1/2+전이 2/2·S17 1/2).
- **다음 후보**: ① §11.4 사용자 노선=**실패-활용 신호**(미사용 blocker 압력 — 1-blocker/near-clear 고원 공통 해법 후보, 미착수 → **§14에서 함정-도구 전제와 충돌 판명, 노선 수정**) ② 추상 전이를 살리려면 좌표-불변 표현(상대좌표/구조 피처) 재설계 필요(§6.4 연장) ③ seed 확대로 §13.2/13.5 통계 보강.

## 14. 설계 노트 (2026-07-09, 사용자 지시) — 함정 도구 전제 + 보상 정교화 (미구현)

**사용자 지시**: 향후 스테이지에 **함정 목적의 불필요한 도구**를 지급할 수 있음. 그때는 **도구를 안 쓰는 것이 정답**일 수 있음. 보상 지급 방식을 더 정교하게 설계할 것.

### 14.1 현 보상 구조의 함정-도구 진단 (mdp.py 실측 기준)
- **터미널 보상 = 이미 함정-안전**: `reward()`는 도구-중립(결과항만) + `len_penalty −0.02×plan_len`이 오히려 **불사용을 미세하게 선호**. 불사용 클리어 해가 사용 클리어 해보다 항상 높은 R. 기반은 건강함.
- **`blocker_bonus` = 함정에서 정확히 역방향 gradient**: bump×진척이라 완전 무용 배치는 0이지만, **국소 진척을 만드는 함정 배치**(일부 개미 전진시키되 전역 해 차단)에는 양의 dense 보상 → 함정 사용을 유혹. PBRS가 아니라 최적 정책을 바꿀 수 있는 항(그게 목적이자 위험). §11.4 양날검(1-blocker basin 강화) 실증과 같은 뿌리.
- **§11.4 예정 노선 "미사용 blocker 압력"과 정면 충돌**: 미사용 인벤에 보상-측 페널티를 주면 함정 스테이지에서 **정답(불사용)을 처벌**. 이 노선은 보상 항으로는 폐기하고 탐험 신호로 이전해야 함(↓14.2).

### 14.2 설계 원칙 + 제안 (구현 전 사용자 정렬용)
- **원칙 A — 심판은 터미널 보상만**: 도구-사용 항이 수렴점(최적 정책)을 바꾸면 안 됨. 사용 유도 항은 감쇠하거나(asymptotically 0) advantage-상대화.
- **원칙 B — 사용/불사용 대칭 탐험**: "안 써봤으면 써보기"와 "써봤으면 안 써보기"를 같은 원리로. 편향은 탐험에만, 평가는 결과로.
- **제안 1 (추천) — usage-profile novelty**: 에피소드의 스킬-사용 프로필(스킬별 사용 수 벡터, 예: blocker1+climber5)에 count-based novelty 보너스(방문수^−½류, 감쇠 내장). §11.4 실패-활용의 함정-안전 버전 — **1-blocker collapse(같은 프로필 반복)·S17 near-clear 고원(프로필 포화)·함정 고착(전량사용 반복)을 단일 신호로 공격**하고, 0-사용 프로필도 미방문이면 탐험됨. 방문수 증가→보너스→0이라 원칙 A 자동 만족.
- **제안 2 — blocker-coef 자동 소등(anneal)**: greedy clear 발견(또는 meanR 포화) 시 coef→0. 발견 부트스트랩 전용으로 격하, 심판에서 제외. 함정 스테이지에서 novelty가 불사용 프로필을 방문시키면 터미널 보상이 그쪽을 채택.
- **제안 3 — 함정 fixture + baseline 실측 먼저**(prove-it, §10 반증 선례): dev_stages/에 "blocker 인벤 지급되나 어떤 배치도 해를 악화, 정답=불사용" 레이아웃 저작 → **현 레시피(blocker-coef 1.0)가 실제로 함정에 빠지는지 정량 baseline** → novelty 버전과 대조. 반증 가능해야 설계 채택.
- 구현 제약 동일: opt-in coef(R0~R3 pin byte-identical)·드라이버(Ant/PlanRunner) 무편집·model/mdp/train shaping-항 패턴 재사용.
- **제안 순서**: ① 함정 fixture+baseline → ② usage-profile novelty(opt-in `--novelty-coef`류) → ③ 3종 시험(S12 seed1 collapse / S17 near-clear / 함정 fixture)으로 단일 신호 유효성 측정. ~~사용자 go 대기~~ → §14.3에서 사용자 재설계로 대체.

### 14.3 v3 — 지식-축적 보상 (2026-07-09 사용자 재설계, 채택 방향)
- **사용자 지적 2건이 v2를 수정**: ① (직전 v2 결함) 즉시 사용-페널티는 **도구 사용을 주저하게 만듦** → ② 새 원리 = **"지식으로 쌓이는 모든 행위(시행착오 포함)에 보상, 잘 찾아 쓰면 더 큰 보상, 단 같은 시행착오의 반복엔 누진 페널티"**.
- **병리 3종 단일 커버**: 1-blocker collapse(동일 실패 plan 4000 eps 반복 — 누진 페널티가 락을 깸)·S17 near-clear 고원(동일)·함정 도구(첫 시도=+지식/반복=누진−/불사용=중립 유지). + **ledger ckpt 영속화=재도전 가속**(reseed 백지초기화 문제의 원리적 해법, "누적하며 똑똑해지는" 직접 구현).
- **스트레스 테스트 패치 2건**: ① novelty 세례 방지 — 신규-보상은 **유한 토큰 vocab 단위만**(소진=자연 감쇠), plan 단위 신규-보상 금지(조합공간 무한=파밍 가능). 반복-페널티만 plan 단위. ② 성공 반복 면제 — 페널티는 **"개선 없는 반복"**(bestR 미갱신·미클리어 에피소드)에만. 아니면 수렴·SIL 재모방까지 처벌해 해 파괴.
- **식**: `R_total = R_terminal + utility_bonus(기존 blocker-coef 계열) + knowledge_bonus[ 토큰 첫사용 +c_new (per token) − 개선없는 동일 plan 반복 c_rep·min(n,cap) ]`. ledger(토큰 카운트+plan 방문수·bestR)=ckpt 저장, resume 이월·transfer 리셋(스테이지-국소 토큰). 입도=plan 정확일치로 시작(관측된 collapse가 문자 그대로 동일 plan 반복), 회피 징후 시 거친 버킷 확장.
- **규율**: opt-in coef(0=byte-identical, pinned 무영향)·드라이버 무편집(순수 학습-측 항)·비정상성(누진 페널티=non-stationary reward)은 baseline EMA가 흡수하나 문서화.
- **검증 순서**: ① 격리검증(신규/반복/개선 부호·크기) → ② S12 seed1(최청정 시험대, 기준=0.463 락 탈출·이상적 3/3) → ③ S17 고원 → ④ 함정 fixture(불사용-정답 최종검증). ~~미확인 가정: 시행착오=bestR 미갱신~~ → **사용자가 프런티어 정의로 대체(§14.4 — 더 우월: 비순환·물리 접지)**.

### 14.4 v3 구현 + 첫 실전 결과 (2026-07-10) — **S12 seed 1 collapse 락 최초 돌파 → 무힌트 3/3 완성**
- **"시행착오" 최종 정의(사용자, 2026-07-10)**: 미클리어 & **두 프런티어 모두 미갱신** — ①가장 멀리 도달한 빈손(Walker)↔candy 최소거리 ②가장 멀리 도달한 운반(Carry)↔home 최소거리. bestR 기반(내 안)보다 우월: shaping 순환 없음·pickup(1차)/복귀(2차) 병목 구조와 동형.
- **구현**(미커밋, opt-in `--knowledge-coef`, 0=pinned byte-identical): `model.frontier_dists`(순수, `_goal_dist_at` 재사용) + `train.KnowledgeLedger`(KNOWLEDGE={new_token:0.05, repeat:0.02, repeat_cap:50}) + train_seed 배선. 설계 세부:
  - 신규-보상 토큰=**필드 값 단위**(skill=3, y_row=6 …) — 구현 중 자가 발견: 액션-조합 단위는 공간 수만+로 novelty 파밍 부활 → 필드 단위로 강등(진짜 유한·소진). 조합 신규성은 "반복 페널티 부재"가 암묵 보상.
  - **SIL 사용-시점 재평가**: buffer엔 base 보상 저장+매 batch 현재 `repeat_term`으로 재평가. 수집-시점 박제 시 baseline 하락과 함께 collapse plan 모방이 되레 강화되는 역효과(자가 발견).
  - bestR/best_episode/로그=base 보상 기준(시간-가변 항 섞이면 비교 불능). PG loss·baseline·SIL 게이트만 지식 항 반영.
  - 원장 ckpt 동승(`knowledge_ledger` 키, coef>0에서만): resume=이월(같은 실패 재학습 방지=재도전 가속), transfer=리셋.
- **격리검증**: `experiments/knowledge_probe.py` 8/8 PASS(신규보상/첫 시행착오 0/누진+cap/개선 면제+카운트 미증가/클리어 면제/신규 필드만/repeat_term 관측전용/ckpt 왕복).
- **pinned 게이트**: verify-r0·r1(S12)·r2(S11)·r2(S19)·accept-resume-equiv **5/5 PASS** — coef=0 무회귀 확인.
- **실전 ② S12 seed 1** (`--blocker-coef 1.0 --knowledge-coef 1.0` + §11 레시피, 나머지 동일=쌍대조: §11.1/§11.4의 동일 커맨드−knowledge가 eps4480 완주 FAIL 대조군):
  - batch 10~80: bestR **0.463 락**(기존과 동일 구간) → **batch 90: 0.743 탈출**(이 seed 계열 최초) → batch 110: 3.993 → **batch 120/eps 1920 GREEDY CLEAR 5/5**. 궤적이 메커니즘과 정합(락 구간에서 누진 페널티 축적→basin 탈출→3-blocker 발견).
  - **S12 무힌트 3/3 완성**(seed0/2=§11 + seed1=v3). 4개 독립 seed(1/1001/2001/3)가 전부 갇혔던 구조적 attractor를 보상-측 신호로 돌파한 첫 사례.
  - seed1 해=blocker×3 y-band 3층(288-336/576-624/432-480) — seed0과 **다른 plan, 같은 전략족**(독립 재발견, 복사 아님). ckpt=stage12_seed1.r2.pt(cleared).
- **실전 ③ S17 seed 2 (near-clear 고원)**: §13.5 scratch(동일 seed·레시피−knowledge)가 cap 120 batch 내내 bestR 3.78 고원 DNF였던 케이스 → knowledge 1.0 추가로 **batch ~75/eps 1200 GREEDY CLEAR**(bestR 0.857→3.234@40→3.977@60→클리어, wall 490s). **두 종류 attractor(collapse 락 + 거의-성공 반복)가 같은 신호로 해소** — §14.3의 "단일 신호로 3병리" 주장 중 2개 실측 입증. ckpt=stage17_seed2.r2.pt(cleared).
- **실전 ④ 함정 fixture (2026-07-10)**: `dev_stages/trap_blocker/` 신설(복도+양끝 벽, blocker×2 지급되나 불필요; 씬 74줄 런타임 빌드) + `StageMDP(scene=,stage_tres=,layout_tres=)`·`solve.stage_meta(tres_path=)` 경로 주입(기본값=기존 경로 불변) + `experiments/trap_test.py`.
  - 엔진 함정성 검증: 무발화 plan CLEAR 4/4 @1189f / 복도 한복판 blocker 픽업0 timeout FAIL. r2는 스텝0 SUBMIT 마스킹이라 빈 plan 불가 → "불사용"의 실체=무발화 트리거/무해 배치.
  - 실험(BASELINE=blocker 1.0 vs KNOWLEDGE=+1.0, seed 0·1, cap 40): **4/4 arm 전부 batch 5(첫 greedy 평가)/eps 80 CLEAR** — 발견 해=`blocker @ at_frame 4500`(deadline 3000 밖=무발화). **규칙 ③(불사용 중립) 실증**: 어떤 항도 불사용을 처벌하지 않아 정답 즉시 채택, knowledge 항 무회귀.
  - **정직한 한계(비변별)**: BASELINE도 즉시 클리어 → blocker-coef "함정 유혹" 가설(§14.1)은 이 난이도에서 **검증 불가**(dense bonus gradient가 축적되기 전에 클리어). 유혹 변별에는 더 어려운 함정(클리어까지 학습이 필요해 dense 신호가 지배할 시간이 있는 레이아웃)이 필요 — 후속 후보.
- **§14 종합**: v3 지식-축적 보상 검증 4/4 완료 — ①probe 8/8 ②S12 seed1 collapse 돌파(3/3 완성) ③S17 고원 돌파 ④함정 무회귀(단 유혹 가설은 비변별). 병리 2종 실측 해소+함정 안전성 확인. 미커밋: model/mdp/solve/train 4파일+transfer_test/knowledge_probe/trap_test+fixture 3파일.

## 15. 후속 세션 (2026-07-11 밤) — 어려운 함정 v2: "학습이 필요한 함정"으로 유혹 가설 변별 시도

> §R4 종결 후 사용자 결정 = **r2.1 주력 복귀** → §14 잔여 2건(어려운 함정 v2 / knowledge 상시화) 착수.
> 함정 v2가 상시화 판단의 직접 근거가 되므로 v2 먼저. 엔진/train.py/mdp.py **무변경**(fixture+실험
> 스크립트만) → pinned 게이트 원천 무영향. TileMetadataDriftTest는 dev_stages 전수 스캔 대상이라
> 신규 레이아웃 포함 재실행 **PASS(82 layouts)**.

### 15.1 왜 "불사용=정답 + 학습 필요"는 구조적으로 불가능한가 (v2 설계 전제)
- 이 MDP에서 무도구 클리어가 존재하면 **무발화 트리거 플랜(널려 있음)이 전부 클리어** → 첫 greedy
  평가(batch 5)에 즉시 발견(§14.4 ④ v1 실측 그대로). "불사용이 정답"과 "클리어까지 학습 필요"는 양립
  불가. → 실행 가능한 변별 설계 = **정답이 도구 일부 사용 + 유혹 배치(국소 진척·전역 차단)와 잉여
  인벤(함정 도구)이 공존**하는 지형. §14.1 유혹 가설("blocker_bonus가 함정 배치에 양의 dense 보상")을
  직접 겨냥한다.

### 15.2 fixture 반복 1 (1-blocker) — **여전히 비변별 (정직 박제)**
- 설계: 복도(스폰) → 낙하 → 낙하층 우측 물 전멸이 기본 경로. 정답 = 낙하층 col 12~13 blocker 1개
  (지급 2 중 1), 유혹 = 복도 blocker(candy 상공 셔틀, redirect 양수·터미널 0).
- 손플랜 probe: noop FAIL(water 5/5)/correct CLEAR 4/4 @1340f(bonus 0.150)/honey FAIL(bonus 0.075 양수) ✓.
  (부수 규명: **물 hazard는 씬 배치 Area2D**(`Water_col_row` 노드, 표면행+deep) — layout `hazard_map`은
  솔버/에디터 메타일 뿐 StageLayoutBuilder가 소비하지 않음. 첫 판은 물 미배치로 개미가 물을 관통 낙사
  → retired water=0 이상신호로 발견·수정.)
- **3-arm(NOBONUS/BASELINE/KNOWLEDGE × seed 0,1,2, cap 120) 결과: 9/9 전부 batch 5~15 클리어** —
  1-액션 정답 basin(밴드 y[480,528] × x≥~576·ge)이 초기 정책 분포에서 그냥 뽑힘. v1과 동류의 비변별.
  교훈: **함정 변별의 관건은 유혹의 세기가 아니라 정답의 발견 비용** — 1-액션 해는 어떤 함정을 붙여도
  학습 창이 생기지 않는다.

### 15.3 fixture 반복 2 (v2.1, 2-blocker 지그재그) — 함정성 + 커리큘럼 gradient 확립
- 경화 원리: 정답을 **순차 의존 2-액션**으로(랜덤 히트 ~p²). 복도(스폰, floor row7) → 낙하 →
  **중간 선반**(row11, 우측 col14~16 물 — blocker#1 col12~13권 필요) → 좌측 가장자리 낙하 →
  **바닥층**(row15, 좌측 col1~2 물 — blocker#2 col3~5권 필요) → 우향 반등 → candy(10,14) 픽업
  자동반전 → #2에 재반등 → home(14,14). **#2의 트리거 밴드(y≈715)는 #1 발화 전엔 개미가 도달
  불가** = 자연 커리큘럼. 인벤 blocker×3(2 필요+1 잉여=함정 도구), total 6/hp 3. 낙하 전부 4칸(기절
  5칸 미만). 유혹면: 복도 blocker = 하강 전면 차단(다른 정답 액션과 공존해도 치명) + 잉여 오발화.
- 손플랜 probe 4/4 (결정론 det=OK, `trap_v2_probe.py`):
  | 플랜 | verdict | retired | redirect | bonus |
  |---|---|---|---|---|
  | noop | FAIL(no_more_ants @874f) | water 6/6 | 0 | 0 |
  | partial(#1만) | FAIL(deadline) | water 5/5 | 55.0 | 0.2546 |
  | correct(#1+#2) | **CLEAR 3/3 @1621f** | 0 | 68.0 | 0.3148 |
  | honey(복도) | FAIL(deadline, 셔틀) | 0 | 20.0 | 0.0926 |
- **dense 신호 서열 correct > partial > honey > noop** — 정답으로 향하는 gradient 계단(partial이
  두터운 디딤돌)과 얕은 유혹 분지가 공존. §14.1 가설을 검정할 지형 성립.

### 15.4 v2.1 3-arm 학습 실험 (NOBONUS/BASELINE/KNOWLEDGE × seeds, cap 150) — 완료
- ① BASELINE vs NOBONUS = blocker-coef dense 신호가 함정 지형에서 순이득/순해인가(§14.1).
- ② KNOWLEDGE vs BASELINE = 미개선 반복 누진 페널티가 honey/잉여 고착을 깎는가(= **상시화 근거**).
- 실행: `trap_v2_test.py --seeds 0,1,2` + `--seeds 3,4,5`, cap 150, §14 레시피(trace+sil, train-deadline
  3000), envs 4. 총 18런.

### 15.5 결과 (n=6/arm, batch-to-clear, DNF=cap 150)
| arm | s0 | s1 | s2 | s3 | s4 | s5 | 클리어 | median |
|---|---|---|---|---|---|---|---|---|
| NOBONUS (0/0) | 60 | 110 | DNF | DNF | DNF | 90 | **3/6** | ~130 |
| BASELINE (blocker 1.0) | 30 | 40 | 45 | 35 | 125 | 130 | **6/6** | 42.5 |
| KNOWLEDGE (blocker 1.0 + knowledge 1.0) | 125 | 40 | 40 | 40 | 20 | 50 | **6/6** | 40 |

- **① §14.1 유혹 가설 = 반증(2차, 이번엔 학습 창 있는 지형에서)**: 유혹 basin이 실재(honey bonus
  0.093 양수·복도=고확률 샘플 영역)함에도 BASELINE이 NOBONUS를 압도(6/6 vs 3/6, median 42.5 vs
  ~130; paired 5/6 seed 우세, 예외 s5 130>90 정직 표기). NOBONUS DNF 3건의 고원 bestR 0.324 =
  하강(#1) 자체를 못 찾음 — **honey에 붙잡힌 게 아니라 가이드 부재로 정체**(coef 0이면 honey 인력도
  0인 대조 설계). coef arm 12런 중 honey-고착 DNF **0건**. 구조 해석: redirect×진척 메트릭이
  진짜 진척(partial 0.2546)을 유혹(0.0926)보다 크게 보상해 gradient 계단이 유혹 분지를 지배 —
  §10 설계(bump 카운트가 아닌 진척 게이트)가 함정-안전의 원인. blocker-coef는 이 함정 지형에서
  **순이득**(특히 NOBONUS-DNF seed 2·3·4 전부 구출).
- **② KNOWLEDGE = median 동률 + 꼬리 개선 + 간헐 지연**: paired로 s4 125→20, s5 130→50, s2 45→40
  (개선 3) / s1 40=40 (동률) / s3 35→40, **s0 30→125(4배 지연)** (악화 2). 합계 batch 405→315.
  - s0 지연의 실체: 클리어 에피소드는 batch 20에 발견(bestR 4.075)됐으나 greedy 고착이 batch 125까지
    지연 — 미개선 근방-변형 반복 페널티가 해 분지 강화를 교란한 것으로 추정(BASELINE s0은 같은
    발견을 batch 30에 고착). **knowledge의 비용면 = 건강한 수렴의 간헐 교란**.
  - s4·s5 구출의 실체: BASELINE의 heavy tail(125/130)이 정확히 §14.4가 겨냥한 "미개선 반복 정체"이고
    knowledge가 그걸 깎음 — S12 seed1 collapse·S17 고원 구출과 동일 메커니즘의 3번째 재현.
- **정직 한계**: ⓐ 잉여-불사용 압력은 설계보다 느슨 — total 6/hp 3이 스페어 1을 남겨 3번째 blocker
  사용도 클리어 가능(발견 해 다수가 3-액션 전량 사용). "잉여 사용=치명" 축은 이 fixture에서 미변별,
  변별된 축은 honey 배치 + 2-스텝 의존 난이도. ⓑ n=6/arm, 단일 fixture — 기하 일반화는 미검증.
  ⓒ honey-고착 0건은 "이 지형에서 유혹이 약했다"와 "메트릭이 본질적으로 함정-안전"을 완전히
  구별하진 못함(유혹 credit을 인위적으로 키운 기하가 남은 반례 공간).

### 15.6 §15 종합 — knowledge 상시화 판단 재료 (사용자 결정 대상)
- **blocker-coef**: 함정 지형 포함 순이득 재확인 → 현 레시피(1.0) 유지 근거 강화.
- **knowledge-coef 상시화**: v2.1만 보면 순편익 우세(합계 −22%, 꼬리 구출)였으나 **§15.7의 건강-런
  쌍대조가 그림을 바꿈** — 아래 §15.7 종합 참조.
- 산출물: fixture `dev_stages/trap_blocker_v2/`(2-blocker 지그재그 최종형) + `experiments/
  trap_v2_probe.py`(함정성 4-플랜 probe) + `experiments/trap_v2_test.py`(3-arm 러너). 로그:
  scratchpad trap_v2_run/trap_v21_run/trap_v21_seeds345.log(비보존). 게이트: TileMetadataDriftTest
  PASS(82 layouts) + try_solve selftest 19/19 PASS — 엔진/솔버 코드 무변경이라 pinned 원천 무영향.

### 15.7 건강-런 지연 쌍대조 (S12 표준 스테이지) — 승/패 완벽 분리 발견
- 동기: §14.4는 knowledge를 **병리 케이스에서만** 검증(S12 seed1 락·S17 고원). v2.1 s0의 4배 지연이
  fixture 특이인지 확인 위해 **건강하게 수렴하는 §11 S12 seed 0·2**에 동일 커맨드+knowledge 1.0 쌍대조.
- 결과: seed 0 = **batch 60 동일**(baseline 60) / seed 2 = **batch 145/eps 2320 (baseline 70/1200 —
  2배 지연)**. bestR 궤적: baseline이 batch 70에 찾던 3-blocker 해를 knowledge run은 batch 140에야
  발견(0.743 고원 장기 체류) — 탐험 편향이 유효 basin 진입 자체를 늦춘 케이스.
- **전 쌍대조 10건 종합 = 승/패가 런-건강도로 완벽 분리**:
  | 결과 | 케이스 | baseline→knowledge |
  |---|---|---|
  | 구출(5) | S12 s1 / S17 s2 / v2.1 s4·s5·s2 | FAIL→120 / DNF→75 / 125→20 / 130→50 / 45→40 |
  | 중립(2) | v2.1 s1 / S12 s0 | 40=40 / 60=60 |
  | 지연(3) | v2.1 s0 / v2.1 s3 / S12 s2 | 30→125(4배) / 35→40 / 70→145(2배) |
  **승리 5건 전부 = 정체·병리 런, 패배 3건 전부 = 건강 런.** knowledge = "정체면 돕고, 건강하면
  1/3꼴로 2~4배 늦춘다" — 무조건 상시화의 논거(집계 우월)가 건강-런 표본 추가로 약화됨.
- ~~수정 권고: (b) 정체-격발 우월~~ → **§15.8이 이 분리를 깸 — 최종 종합은 §15.8 참조.**

### 15.8 S17 실스테이지 쌍대조 — "완벽 분리" 붕괴 (정직 수정) + cross-PC 학습 결정론 실증
- 실행: S17 r2.1 scratch ±knowledge(§R4 ⓐ 레시피: blocker 1.0·max_len 8·cap 240·wall 7200), seeds
  0,1,2 양 arm 로컬(torch 2.12.1+cpu). −knowledge baseline은 이번이 첫 측정(§13.5는 max_len 6이라
  비교 불가), +knowledge는 §R4 ⓐ(RogallyX·torch 2.13.0)와 동일 커맨드.
- **보너스 발견 — cross-PC 학습 궤적 결정론**: 로컬 +knowledge arm이 §R4 ⓐ와 **batch-동일**
  (s0 FAIL bestR 0.942 / s1 CLEAR @85 / s2 CLEAR @95 — 세 값 전부 일치). torch 마이너 버전 차이
  (2.12.1 vs 2.13.0)와 PC 차이에도 같은 seed·config → 같은 궤적. 이후 cross-PC 실험 데이터의
  직접 비교 가능성을 뒷받침(단 n=3 런, 보편 보장은 아님).
- **페어링**: s0 **195→DNF(0.942) 악화 — 클리어→DNF flip 첫 케이스** / s1 130→85 개선 /
  s2 DNF(3.768 near-clear)→95 구출(§14.4 cap120 구출의 cap240 재현).
- **§15.7 "승/패=런-건강도 완벽 분리" 수정**: S17 s0 baseline은 건강 런이 아니라 **저고원(0.89~
  0.94, 1~2-blocker권) 장기 분쇄 끝 batch 195 턱걸이 클리어** — 정체성 런인데 knowledge가 구출은
  커녕 DNF로 밀었다. 재특성화: knowledge는 **near-clear 고원(bestR 3.7+: S17 s2·v2.1 꼬리)과
  collapse 락(S12 s1 0.463)은 구출**하지만, **저고원 점진-확장 구간(blocker 1→2→3→4 축차 발견)**
  에선 반복-페널티의 탐험 편향이 점진 확장을 방해할 수 있음(S17 s0). "정체면 돕는다"가 아니라
  "**정체의 종류에 따라 갈린다**"가 정확.
- **최종 집계 (고유 쌍 12 + 재현 1)**: 개선/구출 6 (S12 s1·S17 s2[×2]·v2.1 s2/s4/s5·S17 s1) /
  중립 2 (v2.1 s1·S12 s0) / 악화 4 (v2.1 s0 4배·v2.1 s3 소폭·S12 s2 2배·**S17 s0 flip**).
  클리어율 순증 +1 (구출 +2, flip −1). 집계 소폭 우세하나 **양방향 꼬리 리스크**.
- **최종 판단 재료 (사용자 결정, 3안)**:
  - (a) 상시화 — 집계 +. 비용 = 건강 런 간헐 지연 + S17 s0류 flip 리스크(실측 1/13).
  - (b) 정체-격발 — §15.7 시점의 "패배 전건 회피" 논거는 **붕괴**(S17 s0는 정체 감지 시 격발돼도
    악화 방향). near-clear(고 bestR) 감지 한정 격발이면 살릴 수 있으나 설계 복잡도↑.
  - (c) **현행 opt-in 유지** — 스테이지/상황별 수동 선택(§14.4·§15 데이터가 사용 가이드).
    추가 구현 0. 단순성 원칙에 부합.
  - 어느 레시피도 지배하지 못함이 실측 결론. 레시피 확정은 사용자 몫.
