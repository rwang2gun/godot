# CandyAnts 레벨 재설계 — 작업 현황 / 다음 세션 핸드오프

작성: 2026-06-02 · 이 문서가 **남은 작업 / 진척의 1차 SoT**.

## 0. 한 줄 요약
캠페인 레벨을 처음부터 재설계 중. **스킬 정합성 "선행 정리"를 먼저** 하고 그 위에 9스테이지 캠페인을 저작하는 흐름.
**2026-06-02 세션 2 완료**: 미커밋 5+ 스레드(builder 대각·Strings 중앙화·Home retire·blocker 배지·기절) **분리 커밋**(e0f9f02~6771bb2) → **A2 기절(Stun) 구현·검증**(commit 1f2a162) → **S1 "첫 마실"을 stage01 락 슬롯에 통합 완료**(dev 초안 폴더 삭제, promotion).
**2026-06-02 세션 3**: ① **S2 "오르막" stage02 저작 — 커밋 `c8611e6`** (§3c). distributor floater 분배(사용자 결정 — rev2 §2 distributor 보류 철회, S2=3개념). 저작 중 버그 2건 수정: 기절 경계값(정확히 5칸≈239.x<240 → **6칸 교정**) + star_thresholds **내림차순→오름차순 교정**(S1·S2, S1 선재버그). ② **A1 운반자 통일 완료**(§4 A1) + **S3 "사탕 호수" stage03 저작**(§3d) — **커밋 `2546212`**.
**2026-06-02 세션 4**: **A5 builder 계단 보행 등반(코어 gated step-up) + S4 "계단 공사" stage04 저작**(§3e). builder 정사각 계단을 walker가 못 오르던 코어 갭을 실증 발견 → 사용자 "코어 수정 후 S4 재개" 결정 → WalkerState gated step-up + Terrain `_stair_cells`. CampaignS4Clear/NoBuilder + GameFlow Scenario B(Stage04 last) 재작성. 전체 141 회귀 내 변경 0 회귀(선재 실패 5건은 §6). 다음: **S5 "막대과자 탑"(sand_mound 사다리)** → S6~S9.

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
- **보류 스킬**: `blocker`·`distributor` — 학습 스테이지 삭제로 미배치. ~~스테이지 추가 작업 시 재배치.~~ **개정(세션 3)**: `distributor`는 **S2 "오르막"에서 floater 분배 장치로 도입**(사용자 결정, §3c). `blocker`만 미배치 유지.
- **무스킬 0번 온보딩**: S1이 바로 climber 요구 → 맨 앞 무스킬 스테이지 삽입 여부 추후 검토.

## 3. 완료 — builder 대각선화 (커밋 e0f9f02)
**변경:**
- `scripts/ant/states/WorkerState.gd` — `_place_one_tile`: 평지 → 대각 상승(`target=body+(dir,0)`, 이동 `+=(dir·cs, −cs)`, `dest_body=body+(dir,-1)` 점유 시 중단).
- `scripts/world/PlacementPreview.gd` — builder/bridge 분리, builder 대각 미리보기 + `_first_target_cell` 분기.
- 신규: `tests/BuilderDiagonalTest.{gd,tscn}`, `dev_stages/builder_diagonal/{BuilderDiagonalStage.tscn, builder_diagonal_test.tres, dev_builder_diagonal_layout.tres}`.

**검증 (`python scripts/run_test.py …`):**
- `tests/BuilderDiagonalTest.tscn` → PASS (`rise=128.0`=4칸, `tiles=4`). 평지였다면 rise≈0이라 식별력 확보.
- 회귀: `BridgeGapCrossTest` PASS(평지 무영향), `SandMoundClimbTest` PASS(공유파일 무영향).
- `Stage01.tscn` 헤드리스 부팅 → PlacementPreview 컴파일 에러 0.

## 3b. 완료 — S1 "첫 마실" → stage01 락 슬롯 통합 (promotion 완결, 세션 2)
사용자 결정("락 슬롯 덮어쓰기+확장")에 따라 dev 초안을 **stage01 락 슬롯에 내용 이식**(파일 경로 유지). dev 초안 폴더 `dev_stages/campaign_s1_first_outing/`는 **삭제**(중복 제거, git 이력 보존).
- **이식 위치**: `data/stages/stage01.tres`(id=1, "첫 마실") + `data/stage_layouts/stage01_layout.tres`(S1 지형, 헤더 uid 유지) + `scenes/stages/Stage01.tscn`(Home(120,480)/Candy(888,480) hp5/Camera(576,300)/Spawner(120,472.5) total8 + PlacementPreview 유지). SceneFlow.STAGE_SCENES[1]·menu_layout slot1 기존 유지.
- **테스트 repoint**: `tests/CampaignS1{Clear,NoClimber}Test.tscn` → `scenes/stages/Stage01.tscn` instance. `GameFlowTest` 시나리오 A climber 좌표를 옛 U핏(y>900,x900~1040) → 새 분지(y490~560,x336~528)로 갱신.
- **검증(run_test.py, 전부 PASS)**: CampaignS1ClearTest(saved5/5) · NoClimberTest(time_out) · CarryFallStateTest(분지 carry+fall) · HudInitialCandyHp(=5) · test_StageLayoutBuilder · GameFlowTest · SceneFlow 2종 · PadRestart · Cursor · Esc 2종 · PauseMenu.
- **기하(cell_size=48)**: 좌 lip(row10 col0~6) → 분지(row10 col7~10 빈칸, 바닥 row11) → 우 lip(row10 col11~23). home=(2,9), candy=(18,9). 분지 진입=1칸 낙하(안전), 탈출=1칸 벽 등반(climber 필수). 양방향이라 왕복도 같은 climber로 자기완결.
- **파라미터**: total_ants=8 / candy_hp=5 / 90s / available=climber+blocker / inventory=climber×8 + blocker×1 / star=[1.0, 0.8, 0.6] / release_rate=30. (2026-06-02 조정: climber 6→8=마리수, blocker×1 추가. blocker는 빈손 개미 가장자리 이탈 방지용 *도구* — 클리어는 조각 기반 `hp0+in_transit0` 유지, 손실-강제 규칙은 미도입(사용자 "도구만 제공" 결정).)
- **⚠ 옛 stage01 "오르막" 내용은 덮어써짐** — git 이력(`6771bb2` 직전 stage01.tres/layout)에서 복구 가능. rev2 §2의 **S2 "오르막"**(사탕 1칸↑ climber + 5칸 낙하 floater)은 옛 stage01을 출발점으로 재저작 권장.
- **남은 통합 작업**: S2~S9를 같은 방식(stage02~09 슬롯 덮어쓰기/확장)으로. menu_layout는 이미 10슬롯(1~3 available, 4~10 "준비 중") + "/30" denominator 확보. SceneFlow.LAST_STAGE_ID(현 3)는 슬롯 확장 시 갱신.

## 3c. 완료 — S2 "오르막" → stage02 락 슬롯 저작 (세션 3, 커밋 `c8611e6`)
HTML rev2 S2 시안(메사 토폴로지)대로 stage02 슬롯에 저작. 핸드오프 §5의 "옛 stage01 valley 출발점"은 **파일 구조 템플릿** 의미였고, 설계 본문("사탕 1칸↑ 등반 + 5칸 낙하")은 메사(올라갔다 내려옴)와 일치 → valley 아닌 메사로 저작.
- **테마**: 한 마리를 분배자로 정착시켜 무리 전체에 낙하산(floater)을 나눠준다. (사용자 결정: "floater 여럿 불필요 = distributor 분배")
- **기하(cell 48)**: 좌측 평지(표면 row10) + cols16~20 위 **6칸 메사**(표면 row4). Home(2,9)·Candy(18,3)·Camera(576,336)·Spawner(120,472.5) total8 + col11 `SettlementMarker`(552,496). 등반 6칸(climber)·복귀 낙하 6칸=288px(기절 임계 240 ≫). ⚠ **원래 5칸 설계였으나 경계값 결함으로 6칸 교정**(§6 gotcha).
- **메커니즘**: `distributor`+`floater`를 한 개미에 부여 → col11서 정착(`SettledState`, `set_blocker_active(false)`라 통행 방해 無) → 이후 지나가는 모든 개미에 `SettledState.TRANSFER_WHITELIST=[floater]` 전이. 배달 개미는 개별 climber만 부여하면 분배자에게서 floater를 받아 안전 강하.
- **파라미터** (`stage02.tres`): id=2 "오르막" / total_ants=8 / candy_hp=5 / 100s / available=[climber,floater,distributor] / inventory={climber:6, **floater:1**, distributor:1} / ★=**[0.5, 0.75, 1.0]**(오름차순) / release_rate=30. floater:1 = "개별 부여로는 부족 → 분배자를 만들어라"를 인벤토리로 텔레그래프.
- **테스트**: stale `Stage02HeadlessTest`(sand-bridge 무효) **폐기**(git rm) → `CampaignS2ClearTest`(분배자 floater 분배 → saved 5/5 PASS) + `CampaignS2NoFloaterTest`(climber만 → picks5/lost5/saved0, floater 식별성 + 6칸 경계 검증 PASS). 둘 다 `Stage02.tscn` instance.
- **검증(run_test.py 전부 PASS)**: S2 Clear·NoFloater / 회귀 22종(S1 Clear·NoClimber·GameFlow·StunFall·Hud×2·LayoutBuilder×2·Scoring×2·SaveData×7·SceneFlow×5).
- **배선**: SceneFlow slot2=Stage02.tscn 그대로, LAST_STAGE_ID=3 유지(S3=옛 MVP stage03). menu_layout 10슬롯·SaveData 언락 기존 유지.
- **⚠ 옛 stage02 "모래 다리"(sand_mound/builder) 내용은 덮어써짐** — git 이력(`58b0fbb` 직전 stage02.tres/layout/tscn)에서 복구 가능.

## 3d. 완료 — A1 운반자 통일 + S3 "사탕 호수" → stage03 락 슬롯 저작 (세션 3, 커밋 `2546212`)
**A1 (선행 정리)**: `BridgeSkill.can_apply`를 builder처럼 **Walker/Carrying 허용** + `has_candy` 거부 제거. `WorkerState`는 has_candy 불변(주석 가드)이고 `return_to_walking()`이 has_candy면 CarryingState로 복원 → 운반 개미가 다리 놓고 운반 재개(데드락 無). `test_BridgeSkill.gd`는 빈 스텁이라 무영향. **검증**: bridge 8종(BridgeGapCross·OverWater·OverWaterStickyOverlap·RejectStageCell·FallAbort·FirstTickOffFloorAbort·GapTooLong·SandBridgeOverlap) 전부 PASS.

**S3 "사탕 호수" 저작** (HTML rev2 id:3 — bridge 평지 횡단 + water 즉사):
- **기하(cell 48)**: 좌 지면 cols0~8 + 우 지면 cols17~23 (표면 row10, body 11-13, bg 14-16). **갭 cols9~16**(8칸) 무지면 → 추락. Home(2,9)·Candy(21,9)·Camera(576,360)·Spawner(120,472.5) total6. **Water 8개**(row10, cols9~16) `(c*48+24, 504)` = (456~792, 504). Water 1개 = 1셀(48×48 shape).
- **메커니즘**: 첫 ant가 갭 직전 col8(x∈[384,432))서 bridge 적용 → `WorkerState("bridge")`가 8칸 수평 다리(cols9~16 row10) + 매 tile `deactivate_hazards_for_placement`로 그 셀 Water 비활성 → 다리 위 통행 안전. BRIDGE_MAX_LENGTH=8 = 갭 8칸 딱 맞음. 다리 영구 → 후속 ant 왕복.
- **water 저작 패턴**: `scenes/entities/hazards/Water.tscn` 인스턴스를 World 아래 셀별 배치. `HazardBase._ready`가 `await physics_frame` 후 `floor(global_position/cell_size)`로 셀 등록 → bridge가 그 셀 deactivate. layout tile_map엔 water 없음(Area2D 별물).
- **파라미터** (`stage03.tres`): id=3 "사탕 호수" / total_ants=6 / candy_hp=4 / 110s / available=[bridge] / inventory={bridge:5} / ★=[0.5,0.75,1.0](오름차순) / release_rate=30.
- **테스트**: stale `Stage03HeadlessTest`(옛 basher/blocker/alternate-spawn/cliff) **폐기**(git rm) → `CampaignS3ClearTest`(bridge→saved4/4 lost0 PASS) + `CampaignS3NoBridgeTest`(무스킬→picks0 no_more_ants, bridge 식별성 PASS). **`GameFlowTest` Scenario B 재작성**: 옛 basher@x528+blocker@x1248 클리어 → bridge@col8 클리어로 교체(테스트 핵심=마지막스테이지 Next-disabled+menu fallback 유지). PASS.
- **⚠ 폐기 부수효과**: Stage03HeadlessTest가 제공하던 **D-1(AntSpawner alternate spawn) / D-2(BlockerSkill carrying 거부) / D-3(blocker clear) 통합 커버리지 소멸**. 재설계 캠페인이 안 쓰는 기능(alternate spawn·blocker 보류)이라 deferred — blocker/alternate 재도입 시 standalone unit test 신설 권장(§4 D4).
- **⚠ 옛 stage03 "흙을 깎다"(basher) 내용 덮어써짐** — git 이력에서 복구 가능.

## 3e. 완료 — A5 builder 계단 보행 등반(코어) + S4 "계단 공사" stage04 저작 (세션 4)
**⚠ 저작 중 발견한 코어 갭(실증)**: builder 대각 계단은 `Terrain.add_tile`이 **풀 정사각(48×48 Rect) 블록**을 깔고, `WalkerState`엔 **스텝업 로직이 없어**(벽 닿으면 climber면 등반·아니면 flip), 일반 walker가 계단을 **위로 못 오른다**. 게다가 builder는 시전 개미를 단 표면보다 **항상 1칸 아래**에 남겨(target이 단 표면 타일에 막혀 abort) 시전 개미조차 단 진입 불가. candy 운반 귀가는 `SavedState`(=queue_free, 제거)라 hp N엔 N마리 등반 필요 → **현재 코어로 S4는 어떤 파라미터로도 클리어 불가**(CampaignS4ClearTest 초안: `saved=0 picks=0 time_out`로 실증). BuilderDiagonalTest가 *"라운드트립/사탕 도달은 검증 범위 밖 — 캠페인 저작 시 별도 검증"*으로 명시 연기한 의존성이 터진 것. (sand_mound S5 사다리도 "빌드 구조물 후속 개미 보행 통행" 미구현 = 유사 갭이나 별개 = S5에서 처리.)

**A5 해결 — gated step-up** (사용자 결정: "코어 수정 후 S4 재개"). 방법 후보 슬로프 타일(정적 `slope_*` 존재하나 45°=floor_max_angle 경계 epsilon 리스크+미검증) vs **게이트 스텝업** 비교 후 후자 채택(결정적·blast radius 좁음·정사각 계단 재사용).
- `Terrain.gd`: `_stair_cells` 집합(DYNAMIC_TILE_STAIR cell만 등록, add_tile/destroy 정합) + `is_stair_cell(cell)` 술어. bridge(평지)·sand_mound(rung)는 제외.
- `WalkerState.gd`: `is_on_wall` 시 climber 분기 다음에 `_try_stair_step_up`. **게이트**: 전방 벽 셀이 STAIR이거나 발밑이 STAIR일 때만 + 올라설 자리(전방+위) 비었을 때만 → `(dir*cs, -cs)` 텔레포트(builder와 동일 델타)로 1칸 등반. 정적 벽(S1 분지)은 게이트 불충족 → flip 유지(**climber 필수 퍼즐 보존**, CampaignS1NoClimber PASS로 실증). 하강은 계단 가장자리 1칸 낙하(기존 Faller)로 자연 처리.
- **한계(노트)**: step-up은 시각적 텔레포트(builder/bridge/sandmound 텔레포트와 일관). CarryingState 미적용(S4는 하강만 운반이라 불필요 — 운반 상승 stage 필요 시 추가).

**S4 "계단 공사" 저작** (HTML rev2 id:4 — builder ↗ 대각 상승, S3 bridge 평지와 대비):
- **기하(cell 48)**: 좌 지면 cols0~8(표면 row10, solid 10~13) + **갭 cols9~11**(바닥 없음→추락) + 우 **높은 단** cols12~23(표면 row6, solid 6~13). bg 14~16. Home(1,9)·Candy(20,5 단 위, pos 984,288)·Camera(576,384)·Spawner(72,472.5) total6.
- **메커니즘**: 첫 ant가 갭 직전 col8(x∈[384,432))서 builder → 계단 타일 `(9,9)(10,8)(11,7)` 3개(build-텔레포트로 시전 개미 body(11,6) 도달) → return walk → 발밑 stair 게이트로 단(col12 row6) 보행 진입. 계단 영구 → **후속 개미도 step-up으로 등반**(빌드 1회로 충분). 하강=1칸 낙하 왕복.
- **파라미터** (`stage04.tres`): id=4 "계단 공사" / total 6 / hp 4 / 110s / available=[builder] / inventory={builder:6} / ★=[0.5,0.75,1.0] / release 30.
- **테스트**: `CampaignS4ClearTest`(builder→**4마리** 계단 등반 회수 saved=4/4 lost=0 PASS) + `CampaignS4NoBuilderTest`(무빌더→전원 갭 추락 picks=0 no_more_ants PASS, builder 필수성). **`GameFlowTest` Scenario B를 Stage03 bridge→Stage04 builder로 재작성**(LAST_STAGE_ID=4라 S4가 새 마지막 스테이지 = Next-disabled+menu fallback 검증).
- **배선**: `SceneFlow.STAGE_SCENES[4]=Stage04.tscn` + `LAST_STAGE_ID=3→4`. **menu_layout는 미수정**(슬롯4 "준비 중" 유지) — S4는 S3 클리어→Next로 도달. menu_layout 슬롯명/가용성 동기화(슬롯1~3도 구 캠페인명 stale)는 별도 follow-up(§4 C2 note).

## 4. 남은 작업 (권장 순서)

### A. 선행 정리 — 코드/에셋 (캠페인 저작 전 필수)
- [x] **A1. builder/bridge 운반자 허용 통일** — **완료(세션 3, 커밋 `2546212`)**. `BridgeSkill.can_apply` Walker/Carrying 허용 + has_candy 거부 제거. 상세 §3d. bridge 8종 회귀 PASS.
- [x] **A2. 기절(Stun) 메커니즘** — **완료(commit 1f2a162)**. `FallerState.enter()` 낙하 시작 y 기록 → 착지 시 `(착지y−시작y) >= 5×cell_size` & floater 미보유 → `DeadState`(신설 대신 **DeadState 재활용**). DeadState가 stun 애니 ~1초 재생 후 queue_free + 운반 시 candy_piece_lost(LostState 동일 회계). `Ant._cell_size`는 `_resolve_kill_bounds`에서 캐시, `stun_fall_threshold()`. `ant_stun` sfx id(P21 대기). floater 높이 무관 무효. 검증: `tests/StunFallTest`(5칸→기절+lost / 4칸→생존 / floater→생존 PASS).
- [x] **A3. 기절 스프라이트** — **완료(commit 1f2a162)**. `assets/sprites/characters/ant_pajama_girl/stun/`(PNG4) + AntFrames `stun` 애니(loop, speed6).
- [ ] **A4. (아트) stair 스프라이트 검토**: `cookie_stair_tile.png`가 대각 상승으로 잘 읽히는지. 충돌/로직은 정상.
- [x] **A5. builder 계단 보행 등반(코어 gated step-up)** — **완료(세션 4)**. WalkerState `_try_stair_step_up`(전방/발밑 STAIR 게이트) + Terrain `_stair_cells`/`is_stair_cell`. 상세 §3e. S4 클리어 가능화의 전제. S1 분지(정적 벽) 보존 실증. **S5 sand_mound 사다리의 후속-개미 보행 통행은 별개 갭(수직)이라 미해결 — S5 저작 시 결정**(floater 하강 귀가는 설계됨, 등반은 시전 개미만 = candy_hp>1 다중 등반 필요 시 sand_mound도 통행 메커니즘 필요).

### B. 에디터 / 데이터 (map-editor 트랙)
- [ ] **B1. 파괴 종류 브러시**: 레이아웃에 `earth`(digger·basher)/`plant`(cutter) 태그 저작. 현재 에디터는 solid/slope만.
- [ ] **B2. 해저드 배치 모드**: water(즉사)/sticky(감속) 셀.
- [ ] **B3. 흙 vs 쿠키(불괴) 시각 구분 확인**.

### C. 캠페인 저작
- [~] **C1. 9개 `stageNN.tres` + `stageNN_layout.tres`** 저작 (HTML 시안 기반), 스테이지별 플레이테스트로 인벤토리·시간·기하 튜닝. 특히 S3/S7/S10류 **복귀 경로**(왕복 제약) 정밀화. — **S1 stage01**(§3b), **S2 "오르막" stage02**(§3c), **S3 "사탕 호수" stage03**(§3d), **S4 "계단 공사" stage04**(§3e) 완료. **S5~S9 미착수**.
- [~] **C2. 진행 흐름 등록**: menu_layout 10슬롯·SaveData 언락(N-1 클리어)·"/30" denominator는 **이미 확보**. SceneFlow.STAGE_SCENES[1~4]·**LAST_STAGE_ID=4**(세션 4 갱신) — 현재 캠페인 4스테이지(S1~S4) 완결 데모. **S5 저작 시 STAGE_SCENES[5] + LAST_STAGE_ID=5** 갱신 필요. **⚠ menu_layout follow-up**: 슬롯1~3 display_name이 **구 캠페인명**("햇살 정원/다리 공사/차단 미로")으로 stale(재설계 S1~S4 = "첫 마실/오르막/사탕 호수/계단 공사"), 슬롯4~10 "준비 중"(available=false). 캠페인 Next-flow는 정상 동작하나 stage-select 메뉴 직접 선택은 슬롯명/available 미동기. menu_layout 마이그레이션(슬롯명 교체 + 클리어된 stage available flip + `MenuLayoutResourceTest`의 `i<3` 갱신)은 별도 정리 항목.
- [ ] **C3. blocker·distributor 재배치** + 무스킬 0번 온보딩 결정.

### D. 하우스키핑
- [x] **D1. builder 변경 커밋** — 완료(commit e0f9f02). 세션 2에서 builder/Strings/Home/Ant(blocker+stun)/S1+docs/theme 6커밋으로 분리.
- [x] **D2. stale 통합테스트 정리**: `Stage02HeadlessTest`(sand-bridge) + `Stage03HeadlessTest`(basher/blocker/cliff) **둘 다 폐기**(세션 3, git rm) — S2·S3 재저작으로 무효화. 대체: `CampaignS2/S3 Clear+Negative` 테스트.
- [ ] **D3. FloaterTraitTest 기존 실패 조사**: dev_stages/trait 스테이지에서 floater-only 개미가 낙하 미도달 → deadline. 기절 변경 무관(FallerState revert해도 실패 확인). 별도 조사 필요.
- [ ] **D4. (세션 3 신설) blocker/alternate-spawn 커버리지 보강**: `Stage03HeadlessTest` 폐기로 **D-1(AntSpawner spawn_direction_alternate) / D-2(BlockerSkill carrying 거부) / D-3(blocker clear) 통합 커버리지 소멸**. 둘 다 재설계 캠페인 미사용(blocker 보류·alternate 미사용)이라 defer. blocker/alternate 재도입 시 standalone unit test 신설.

## 5. 다음 세션 즉시 행동 (제안)
1. `python scripts/execute.py mvp validate` 1회(세션 시작 루틴) + `git log --oneline -8`로 baseline 확인. **세션 4 종료: HEAD=`ef2551b`(A5 step-up + S4). 추적 파일 워킹트리 clean, 미push(로컬)**. ⚠ **단 `git status`에 climb 애니 아트(`AntFrames.tres` + `climb/climb_*.png` + `docs/climb_4pose_limb_color_reference.*`)가 미커밋으로 뜸 — 병렬 아트 트랙 산출물이라 정상이며 내 작업 아님. 스테이지 커밋에 섞지 말 것**(아트 트랙이 별도 커밋). S5부터 직진.
2. **S5 "막대과자 탑" 저작** (sand_mound 수직 사다리 + floater 귀가). HTML rev2 id:5 grid: 높은 외딴 단 위 candy → 좁은 수직 기둥(sand_mound)으로 등반, 귀가는 floater 안전 낙하(왕복 제약). stage05 슬롯 **신규** + **SceneFlow.STAGE_SCENES[5] + LAST_STAGE_ID=5**. §3d/§3e 마이그레이션 패턴 답습. **⚠ 선결정 필요**: sand_mound도 builder처럼 "시전 개미만 등반"(빌드-텔레포트) = candy_hp>1 다중 등반 시 후속-개미 사다리 보행 통행 미구현(§3e). S5는 **사다리 수직**이라 builder의 대각 step-up(A5)이 안 통함 → ① floater로 *내려오기*만 하고 *올라가기*는 각 개미가 sand_mound 시전(인벤토리 충분) 패턴인지, ② 사다리 climb 메커니즘 신설인지 결정. SandMoundClimbTest는 saved>=1(1마리)만 검증 = 다중 등반 미검증.
3. **S6~S9** 순차 (S6 digger / S7 basher / S8 cutter / S9 종합). S6+ 파괴계는 layout에 earth/plant 태그(B1) + water/sticky 해저드(B2) 저작 필요. **S7 basher·S8 cutter는 수평 통로라 등반 불필요 = 현 코어로 동작**.
4. **(선재 실패 정리)** §6의 pristine-HEAD 실패 4건(Climber/Digger/Distributor/Floater Trait류) — 내 변경과 무관하나 main이 full-suite green 아님. 조사·수정은 별도 항목.
5. (선택) **기절 5칸 경계 결함 근본수정 여부 결정**(§6 gotcha) — 현재는 스테이지를 6칸으로 우회.

## 6. Gotchas (다음 세션 주의)
- **⚠ 기절 5칸 경계 결함 (세션 3 발견)**: 기절 임계는 `fall_dist >= 5×cell_size`(=240px)인데, **기하학적 정확히 5칸 낙하는 기절을 발동 못 함**. 원인: `WalkerState.update`가 매 프레임 `velocity.y += gravity*delta` + `move_and_slide` 적용 → 개미가 ledge 이탈 후 같은 프레임에 off-floor가 되어 즉시 Faller 전이하는데, `FallerState.enter()`가 기록하는 `_fall_start_y`가 이미 중력 1프레임만큼 내려간 값 → 측정 fall_dist ≈ 239.x < 240 → 미발동. **실증**: 정확히 5칸 메사에서 floater 없는 개미 전원 생존(CampaignS2NoFloaterTest가 saved=5로 FAIL). **6칸(288px)으로 올리니 전원 기절(lost=5)**. → **레벨 저작 규칙: 기절을 의도한 낙하는 ≥6칸으로**. 디자인 "5칸=기절"을 살리려면 측정 로직 근본수정 필요(§5.4, 코어 변경이라 별도 작업).
- **⚠ star_thresholds는 오름차순 (세션 3 발견)**: 엔진 컨벤션은 `Scoring.STAR_THRESHOLDS=[0.50,0.80,0.95]` **오름차순**(`[1★최소비율, 2★, 3★]`, `compute_stars`는 `ratio>=threshold` 누적). HTML 시안 표기 `[1.0, 0.8, 0.6]`는 내림차순이라 **그대로 베끼면 `SaveData._is_clear_input_valid`가 거부**("malformed input" 경고 → 별점 미저장·attempts만 +1). **올바른 형식**: 3★=100/2★=80/1★=60이면 `[0.6, 0.8, 1.0]`. S1·S2 둘 다 내림차순 오저작이던 것을 세션 3에서 오름차순 교정(S1은 선재 버그).
- **검증은 `python scripts/run_test.py tests/Xxx.tscn`**(풀 프로젝트, autoload 활성). `godot --check-only --script`는 **autoload(EventBus) 부재로 의존 스크립트가 줄줄이 거짓 실패** → 단독 컴파일 체크 용도로 쓰지 말 것.
- Godot bin: `D:\Godot_v4.6.2-stable_win64_console.exe` (run_test.py가 자동 탐색).
- **water 해저드 저작(S3 이후)**: layout tile_map엔 water 없음 — `scenes/entities/hazards/Water.tscn`(Area2D, layer8/mask4, 48×48)를 **씬 World 아래 셀별 인스턴스**. `HazardBase._ready`가 `await physics_frame` 후 `floor(global_position/cell_size)`로 셀 등록. **표면행(예 row10) 1행이면 충분**(추락 개미 즉사 catch, dev 컨벤션). bridge tile이 `deactivate_hazards_for_placement(cell)`로 그 셀 water 끔 → 다리 위 안전. bridge 적용은 **갭 직전 마지막 지면 cell**(body_cell+(dir,+1)이 갭 첫 셀이어야 add_tile 성공)에서.
- `docs/LEVEL_DESIGN_PLAN.html`은 **gitignore(*.html)** — 커밋해도 안 올라감. 로컬 보존.
- **stage 슬롯 마이그레이션 패턴**(S2~S9 답습): ① `stageNN_layout.tres` 내용 이식(헤더 uid 유지) ② `stageNN.tres` 파라미터 ③ `StageNN.tscn` 엔티티 좌표(Home/Candy/Camera/Spawner)+hp+total ④ 지오메트리 하드코딩 테스트(GameFlowTest climber 좌표 등) 갱신 ⑤ 회귀(Hud/LayoutBuilder/GameFlow/SceneFlow). 경로 락이라 **파일명 유지·내용만 교체**.
- **세션 2 종료**: 8 커밋(`e0f9f02`~`58b0fbb`), HEAD=`58b0fbb`, 워킹트리 clean, 미push(로컬).
- **세션 3 종료**: ① S2 stage02 저작 + 버그2 → **커밋 `c8611e6`**. ② A1(BridgeSkill) + S3 stage03 저작(stage03.tres/layout/Stage03.tscn + Water8) + 신규 테스트(CampaignS3Clear/NoBridge) + Stage03HeadlessTest 폐기 + GameFlowTest Scenario B bridge 재작성 + 본 문서 → **커밋 `2546212`**. ③ 본 핸드오프 정정 docs 커밋. **HEAD 이후 추적 워킹트리 clean**. ⚠ climb 애니 2→8프레임 아트(AntFrames/climb_*.png/svg)는 **미커밋 병렬 트랙** — 스테이지 커밋에 섞지 말 것.
- **⚠ builder 계단 = 시각적 텔레포트 step-up (세션 4)**: walker가 builder STAIR(정사각)를 오를 때 `WalkerState._try_stair_step_up`이 `(dir*cs,-cs)`로 **순간 1칸 텔레포트**(builder/bridge/sandmound 텔레포트와 일관). 부드러운 보행 애니 아님. 게이트(전방/발밑 STAIR + 목적 셀 빈칸)라 **계단 없는 stage엔 미발동**(비계단 보행 바이트 동일). 정적 벽은 절대 step-up 안 함 = **climber 퍼즐 보존**(S1). CarryingState는 미적용(S4는 하강만 운반). 새 stair stage 저작 시 이 전제 활용 — builder는 단 표면보다 1칸 아래서 abort하지만 step-up이 마지막 1칸을 메운다.
- **⚠ full-suite 선재 실패 4건 (세션 4 발견, pristine HEAD `40cafc9`)**: `ClimberTraitTest`(mantle dx 37.93<38.00 0.07px 경계), `DiggerFallThroughUpperAntTest`, `DistributorSettleTest`, `FloaterTraitTest`(D3 기존)는 **내 변경 없이도 실패** = main이 141-full green 아님. 핸드오프의 "회귀 green"은 **큐레이트 세트**(S1~S3·GameFlow·Stun·Hud·Layout·Scoring·SaveData·SceneFlow) 기준이었음. + `SkillDropAssignTest`는 pristine HEAD엔 PASS·미커밋 아트(AntFrames) 존재 시 FAIL = **아트 트랙 회귀(또는 flaky)**. 모두 A5/S4 무관. 회귀 검증은 큐레이트 세트 + 변경 인접 테스트로 하되, full-suite 4건 선재 실패를 baseline으로 인지.
- **세션 4 종료**: A5 gated step-up(WalkerState+Terrain) + S4 stage04 저작(layout/tres/scene + CampaignS4Clear/NoBuilder) + SceneFlow(STAGE_SCENES[4]+LAST_STAGE_ID=4) + GameFlow Scenario B 재작성 + 본 문서 → **커밋 `ef2551b`**. 전체 141 회귀: 내 변경 0 회귀(선재 5건 제외 전부 PASS). ⚠ climb 아트는 여전히 미커밋 병렬 트랙 — 커밋에 섞지 말 것.
