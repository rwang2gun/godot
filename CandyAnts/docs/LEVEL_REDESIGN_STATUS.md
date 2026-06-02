# CandyAnts 레벨 재설계 — 작업 현황 / 다음 세션 핸드오프

작성: 2026-06-02 · 이 문서가 **남은 작업 / 진척의 1차 SoT**.

## 0. 한 줄 요약
캠페인 레벨을 처음부터 재설계 중. **스킬 정합성 "선행 정리"를 먼저** 하고 그 위에 9스테이지 캠페인을 저작하는 흐름.
이번 세션에 **builder 대각선화** 구현·검증 완료(아직 **미커밋**) + **S1 "첫 마실" 캠페인 초안** 저작·헤드리스 검증 완료(독립 폴더, 미통합·미커밋).

## 1. 관련 문서
- **설계 시안**: `docs/LEVEL_DESIGN_PLAN.html` (rev2, 9스테이지, 그리드 시안 포함).
  - ⚠ `.gitignore`의 `*.html`에 걸려 **git 비추적 — 로컬 디스크에만 존재**. 브라우저로 열어 확인(`start docs\LEVEL_DESIGN_PLAN.html`).
  - 필요 시 추적하려면 `!docs/LEVEL_DESIGN_PLAN.html` 예외 추가 or md로 변환.
- 본 문서 `docs/LEVEL_REDESIGN_STATUS.md` (추적됨) — 진척/TODO SoT.

## 2. 확정 결정 (rev2)
- **9스테이지** (12에서 축소): 폭신착지·교차로·민들레 **삭제**.
- 곡선: **트레잇 기초(S1·S2) → 건설 3종(S3 bridge평지 / S4 builder대각 / S5 사다리수직) → 파괴 3종(S6 digger / S7 basher / S8 cutter) → 종합(S9)**.
- **S1 첫마실**: 중앙 1칸 분지 + 짧은 경로 → climber를 최소 동작으로 학습.
- **S2 오르막**: 사탕 1칸↑ → climber 등반 + **5칸 낙하 → floater** 동시 학습.
- **기절(Stun) 규칙**: 5칸+ 자유낙하 → `lost`. floater = **기절 완전 무효**. (스펙 §4-A2)
- **builder = 대각 상승**(완료), **bridge = 평지 유지**.
- **보류 스킬**: `blocker`·`distributor` — 학습 스테이지 삭제로 미배치. 스테이지 추가 작업 시 재배치.
- **무스킬 0번 온보딩**: S1이 바로 climber 요구 → 맨 앞 무스킬 스테이지 삽입 여부 추후 검토.

## 3. 이번 세션 완료 — builder 대각선화
**변경(미커밋, branch=main, base=d6a7704):**
- `scripts/ant/states/WorkerState.gd` — `_place_one_tile`: 평지 → 대각 상승(`target=body+(dir,0)`, 이동 `+=(dir·cs, −cs)`, `dest_body=body+(dir,-1)` 점유 시 중단).
- `scripts/world/PlacementPreview.gd` — builder/bridge 분리, builder 대각 미리보기 + `_first_target_cell` 분기.
- 신규: `tests/BuilderDiagonalTest.{gd,tscn}`, `dev_stages/builder_diagonal/{BuilderDiagonalStage.tscn, builder_diagonal_test.tres, dev_builder_diagonal_layout.tres}`.

**검증 (`python scripts/run_test.py …`):**
- `tests/BuilderDiagonalTest.tscn` → PASS (`rise=128.0`=4칸, `tiles=4`). 평지였다면 rise≈0이라 식별력 확보.
- 회귀: `BridgeGapCrossTest` PASS(평지 무영향), `SandMoundClimbTest` PASS(공유파일 무영향).
- `Stage01.tscn` 헤드리스 부팅 → PlacementPreview 컴파일 에러 0.

## 3b. 이번 세션 완료 — S1 "첫 마실" 캠페인 초안 (독립 폴더, 미통합·미커밋)
사용자 결정에 따라 **독립 초안 폴더**로 작성(잠긴 메인 Stage01~03·SceneFlow·StageSelect **무변경**, 완전 가역).
- **위치**: `dev_stages/campaign_s1_first_outing/` — `CampaignS1Stage.tscn` + `campaign_s1.tres`(StageData, id=101) + `dev_campaign_s1_layout.tres`(StageLayoutData).
- **기하(cell_size=48)**: 좌 lip(row10 col0~6) → 분지(row10 col7~10 빈칸, 바닥 row11) → 우 lip(row10 col11~23). home=(2,9), candy=(18,9). 분지 진입=1칸 낙하(안전), 탈출=1칸 벽 등반(climber 필수). 양방향이라 왕복도 같은 climber로 자기완결.
- **파라미터**: total_ants=8 / candy_hp=5 / 90s / available=climber+blocker / inventory=climber×8 + blocker×1 / star=[1.0, 0.8, 0.6] / release_rate=30. (2026-06-02 조정: climber 6→8=마리수, blocker×1 추가. blocker는 빈손 개미 가장자리 이탈 방지용 *도구* — 클리어는 조각 기반 `hp0+in_transit0` 유지, 손실-강제 규칙은 미도입(사용자 "도구만 제공" 결정).)
- **검증(`run_test.py`, 둘 다 PASS)**:
  - `tests/CampaignS1ClearTest.tscn` → climber 6 부여 시 사탕 5개 전부 회수·귀가 → `stage_cleared saved=5/5`(frame 1633≈27s). 여유 1마리(6 부여 중 5 왕복).
  - `tests/CampaignS1NoClimberTest.tscn`(음성 대조) → 무스킬이면 picks=0인 채 `time_out`(frame 5400=90s) → 분지가 walker를 막고 climber가 *필수*임 입증.
- **무변경**: 기존 스크립트 0건 수정(파일 추가만). builder 대각선 변경(§3)과 독립.
- **다음 단계(별도 결정)**: 캠페인 통합 시 → `data/stages/stage01.tres`+`scenes/stages/Stage01.tscn`+layout으로 이전(현 '오르막'은 S2 슬롯으로 밀림) + `SceneFlow.STAGE_SCENES`/StageSelect 등록 + id 1로 재번호. 선행정리(A1/A2)·나머지 8스테이지와 함께 일괄 통합 권장.

## 4. 남은 작업 (권장 순서)

### A. 선행 정리 — 코드/에셋 (캠페인 저작 전 필수)
- [ ] **A1. builder/bridge 운반자 허용 통일**: `BridgeSkill.can_apply`가 현재 `has_candy` 거부 + Walker만 → builder처럼 **Walker/Carrying 허용**으로 변경(작업 후 Walker 복귀라 데드락 無). 파괴·정지·하강계는 현행 거부 유지.
- [ ] **A2. 기절(Stun) 메커니즘** (설계 1-C):
  - `FallerState.enter()`에서 낙하 시작 y 기록 → 착지(`is_on_floor`) 시 `(착지y − 시작y) >= 5 × cell_size` 이고 floater 미보유면 기절, 아니면 기존 `return_to_walking()`.
  - cell_size 접근 경로 필요(Ant에 노출 or terrain 조회). `Ant._kill_y` 계산이 이미 layout cell_size를 읽으니 그 경로 재사용 검토.
  - **`StunnedState` 신설**(미사용 `scripts/ant/states/DeadState.gd` 재활용 가능): 기절 스프라이트 ~1초 재생 → 운반 중이면 `EventBus.candy_piece_lost` emit → `queue_free`. 회계는 `LostState`와 동일(영역 밖 이탈과 같은 `lost` 정산).
  - floater 보유 시 **높이 무관 기절 안 함**(레밍즈 정통).
  - `sfx_request`에 기절 id 추가(P21 receiver 대기).
- [ ] **A3. 기절 스프라이트**: `assets/sprites/characters/ant_pajama_girl/stunned/` (별 도는 KO 포즈).
- [ ] **A4. (아트) stair 스프라이트 검토**: `cookie_stair_tile.png`가 대각 상승으로 잘 읽히는지. 충돌/로직은 정상.

### B. 에디터 / 데이터 (map-editor 트랙)
- [ ] **B1. 파괴 종류 브러시**: 레이아웃에 `earth`(digger·basher)/`plant`(cutter) 태그 저작. 현재 에디터는 solid/slope만.
- [ ] **B2. 해저드 배치 모드**: water(즉사)/sticky(감속) 셀.
- [ ] **B3. 흙 vs 쿠키(불괴) 시각 구분 확인**.

### C. 캠페인 저작
- [ ] **C1. 9개 `stageNN.tres` + `stageNN_layout.tres`** 저작 (HTML 시안 기반), 스테이지별 플레이테스트로 인벤토리·시간·기하 튜닝. 특히 S3/S7/S10류 **복귀 경로**(왕복 제약) 정밀화. — **S1 "첫 마실" 초안 완료**(`dev_stages/campaign_s1_first_outing/`, §3b), S2~S9 미착수.
- [ ] **C2. 진행 흐름 등록**: 스테이지 선택/언락에 9스테이지 등록 + 총 개수 확정.
- [ ] **C3. blocker·distributor 재배치** + 무스킬 0번 온보딩 결정.

### D. 하우스키핑
- [ ] **D1. 이번 builder 변경 커밋** (+ 설계안 1-A "완료" 표기). 예: `feat(skill): builder를 대각선 상승 계단으로 변경`.
- [ ] **D2. stale 통합테스트 정리**: `Stage02HeadlessTest`(+stage03?)가 16px 시절 좌표라 48px 3-tier 후 red. trigger 좌표 갱신 or 폐기. (builder 변경과 무관한 기존 문제)

## 5. 다음 세션 즉시 행동 (제안)
1. `python scripts/execute.py mvp validate` 1회(세션 시작 루틴).
2. **D1 커밋** 먼저(이번 builder 작업 박제) → 그다음 **A1(운반자 통일)** 또는 **A2(기절)** 착수.
3. A2 기절은 코어 상태머신 변경 → `doubt-driven-development` + 전용 헤드리스 테스트(5칸 낙하→lost, 4칸→안전, floater→안전) 권장.

## 6. Gotchas (다음 세션 주의)
- **검증은 `python scripts/run_test.py tests/Xxx.tscn`**(풀 프로젝트, autoload 활성). `godot --check-only --script`는 **autoload(EventBus) 부재로 의존 스크립트가 줄줄이 거짓 실패** → 단독 컴파일 체크 용도로 쓰지 말 것.
- Godot bin: `D:\Godot_v4.6.2-stable_win64_console.exe` (run_test.py가 자동 탐색).
- **stage02 통합테스트 red는 기존 stale** — builder 변경이 깬 게 아님.
- `docs/LEVEL_DESIGN_PLAN.html`은 **gitignore(*.html)** — 커밋해도 안 올라감. 로컬 보존.
- builder 변경 **미커밋** 상태로 세션 종료.
