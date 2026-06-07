# CandyAnts 레벨 재설계 — 작업 현황 / 다음 세션 핸드오프

작성: 2026-06-02 · 이 문서가 **남은 작업 / 진척의 1차 SoT**.

## 0. 한 줄 요약
캠페인 레벨을 처음부터 재설계 중. **스킬 정합성 "선행 정리"를 먼저** 하고 그 위에 9스테이지 캠페인을 저작하는 흐름.
**2026-06-02 세션 2 완료**: 미커밋 5+ 스레드(builder 대각·Strings 중앙화·Home retire·blocker 배지·기절) **분리 커밋**(e0f9f02~6771bb2) → **A2 기절(Stun) 구현·검증**(commit 1f2a162) → **S1 "첫 마실"을 stage01 락 슬롯에 통합 완료**(dev 초안 폴더 삭제, promotion).
**2026-06-02 세션 3**: ① **S2 "오르막" stage02 저작 — 커밋 `c8611e6`** (§3c). distributor floater 분배(사용자 결정 — rev2 §2 distributor 보류 철회, S2=3개념). 저작 중 버그 2건 수정: 기절 경계값(정확히 5칸≈239.x<240 → **6칸 교정**) + star_thresholds **내림차순→오름차순 교정**(S1·S2, S1 선재버그). ② **A1 운반자 통일 완료**(§4 A1) + **S3 "사탕 호수" stage03 저작**(§3d) — **커밋 `2546212`**.
**2026-06-02 세션 4**: **A5 builder 계단 보행 등반(코어 gated step-up) + S4 "계단 공사" stage04 저작**(§3e). builder 정사각 계단을 walker가 못 오르던 코어 갭을 실증 발견 → 사용자 "코어 수정 후 S4 재개" 결정 → WalkerState gated step-up + Terrain `_stair_cells`. CampaignS4Clear/NoBuilder + GameFlow Scenario B(Stage04 last) 재작성. 전체 141 회귀 내 변경 0 회귀(선재 실패 5건은 §6). 다음: **S5 "막대과자 탑"(sand_mound 사다리)** → S6~S9.
**2026-06-02 세션 5 (진행 중·미커밋)**: **S3 소다 워터 개편 + 다리 무장(armed)→낭떠러지 자동 건설**(§3d 델타).
① **소다 워터**(사용자 결정): 물 표면을 지면(row10)보다 **한 칸 낮은 row11**로 내리고(갭 row10은 공중=다리 자리), 새 `usable_square/soda_water_{surface,inner}_square.png` 2종 적용. `WaterHazard.deep` export(시각만 분기, 즉사 동일) + Water.tscn 기본 텍스처 surface. Stage03 물 8셀(row10) → 24셀(row11 surface + row12~13 inner). 다리(row10)가 물 위 1칸 위를 가로질러 안전(기존 per-tile deactivate 의존 → 1칸 간격으로 대체).
② **다리 규칙**(사용자 지시): 다리 스킬을 부여하면 즉시 건설하지 않고 개미가 **무장(`Ant.bridge_armed`)한 채 보행 → 낭떠러지(전방 바닥 없음) 도달 시 그 자리 지표면 높이(row10)에서 자동 건설**. **하이브리드** — 이미 낭떠러지에서 부여하면 `apply`가 즉시 건설(기존 동작=낭떠러지 시전 테스트 무변경), 평지 부여면 무장. `Ant.bridge_cliff_ahead()`(전방 셀 비었고 전방-아래 셀 바닥 없음) 단일 술어를 apply(즉시 분기)+Walker/Carrying(`try_build_armed_bridge`)이 공용. 인벤토리는 부여 시점 차감(소비, 환불 없음). #2(지표면 높이)는 기존 `_place_bridge_tile`(target=body_cell+(dir,+1)=발 디딘 행)이 발판 위 트리거로 자동 충족 — 별도 높이 코드 없음. **무장 시각 표식**: climber/floater처럼 꼬리에 다리 아이콘 배지(`Ant.tscn` TailBadges/BridgeBadge + `_update_trait_badges`가 `bridge_armed` 토글) — `CampaignS3ArmedBridge`가 무장 중 visible 단언으로 검증. 무장 취소 UI는 범위 외(후속). 변경: `Ant.gd`(bridge_armed+bridge_cliff_ahead+try_build_armed_bridge+_find_terrain) / `BridgeSkill.gd`(apply 하이브리드+can_apply 재무장 가드) / `WalkerState.gd`·`CarryingState.gd`(트리거 1줄). **③ 다리 타일 텍스처**: thin_cookie(32×16) → `biscuit_bridge_middle_horizontal_concept_01.png`(48×48 whole-tile, `_apply_tex_to_sprite`), 시각만.
**회귀(19 PASS, 0 회귀)**: 신규 CampaignS3ArmedBridge(평지 x151 무장→tile0→낭떠러지 자동건설→saved4/4) + bridge 8종(GapCross/OverWater/GapTooLong/FallAbort/FirstTickOffFloor/RejectStageCell/SandBridgeOverlap/OverWaterStickyOverlap, 전부 낭떠러지 시전=즉시건설 분기) + S3 Clear(saved4/4 frame1628 불변)/NoBridge + Water 3종 + 비-bridge(S1climber/S2distributor/S4 builder step-up/CarryFall/StickyCarry). **미커밋(로컬).**
**2026-06-03 세션 6 (진행 중·미커밋)**: **계단(builder) 스킬 개편 — 무장 건설 + 새 비스킷 타일 + 45° 부드러운 등반**(§3e 델타). 사용자 요청 3건. ① **무장 메커니즘**(다리 패턴 복제): `BuilderSkill.apply`가 낭떠러지가 아니면 즉시 건설 대신 `Ant.builder_armed` 무장 → 보행 중 Walker/Carrying이 `try_build_armed_builder()`로 낭떠러지 도달 시 자동 대각 건설(하이브리드 — 낭떠러지 즉시 시전은 기존대로 즉시). `bridge_cliff_ahead()`를 중립명 **`cliff_ahead()`로 리네임**해 다리/계단 공용(코드 3곳: BridgeSkill·try_build_armed_bridge·try_build_armed_builder). 꼬리 BuilderBadge(`builder.png`, TailBadges, `builder_armed` 토글) 신설. ② **새 타일**: `cookie_stair_tile.png`(단일 다단 계단) → `biscuit_stair_45_01`(우하단 절반)+`_02`(좌상단 절반) **끊김 없는 대각 비스킷 막대**. 두 76px 절반의 알파 중심(01=(16.5,16.5)/02=(-17.5,-17.9))을 -centroid로 보정해 셀 중앙에서 겹쳐 하나의 연속 "/" 막대로, `STAIR_OVERLAP=1.22`로 조인트 틈 메움. 충돌(48×48 사각)·`_stair_cells`·cell_kind 불변=시각만. ③ **45° 부드러운 등반**(구 순간이동 step-up 폐기): 신규 **`StairClimbState`** — WalkerState `_stair_climb_ahead` 게이트(구 `_try_stair_step_up`, 위치 무변경) 통과 시 전이 → 매 프레임 대각(전방+위) `global_position.lerp` 글라이드 + `_sprite.rotation=-45°*_dir`. 중력/move_and_slide/is_on_floor 미사용(글라이드 중 Faller 무전이), 스텝 완료 스냅 후 게이트 재검사로 연속 등반, 꼭대기 도달 시 `return_to_walking`(`exit()`서 회전 0 복원). 게이트 불변→**정적 벽은 여전히 flip**(S1 climber 퍼즐 보존, CampaignS1NoClimber PASS 실증). **범위**: WalkerState 한정(CarryingState는 무장 트리거만, 등반 미적용 — S4 하강 운반). 변경: `Ant.gd`(builder_armed+cliff_ahead 리네임+try_build_armed_builder+BuilderBadge+_update_sprite StairClimb→walk) / `BuilderSkill.gd`(하이브리드+재무장 가드) / `WalkerState.gd`·`CarryingState.gd`(트리거+게이트) / `StairClimbState.gd`(신규) / `Terrain.gd`(2-절반 렌더) / `Ant.tscn`(BuilderBadge). **회귀**: 신규 CampaignS4ArmedBuilder(평지 x151 무장→tile0+배지→낭떠러지 자동건설→4마리 등반 saved4/4) + BuilderDiagonal(dev layout에 cols13~16 갭 추가=무장→낭떠러지 건설, rise128) + DynamicStairTileVisual(2-절반 렌더 단언) 갱신 + S4 Clear/NoBuilder + GameFlow + bridge 6종(cliff_ahead 리네임 안전) + S1~S3 Clear/Neg + Stun/Carry/Layout/Scoring/SceneFlow/Toolbar/SandMound 전부 PASS. **시각 검증**: `tests/StairClimbVisualCapture`(verify-only, 비헤드리스)로 연속 비스킷 막대 + 등반 -45° 회전 스크린샷 확인. **미커밋(로컬).** 미해결: dir=-1(좌향) 계단 시각은 수학적 미러만(스테이지 미사용) / `cookie_stair_tile.png` 데드 에셋 잔존 / 부드러운 *하강*은 범위 외(현행 1칸 낙하).
**2026-06-03 세션 9 (커밋 대기·로컬, base `c67281d`)**: **S7 "옆파기" stage07 저작 — 코어 무변경, 순수 데이터 저작**(§3h가 SoT). basher는 Phase 18에서 완비된 수평 굴착 코어가 그대로 동작 — S4 step-up·S5 ladder 같은 코어 추가 불요(예상 적중). 흙 벽(cols9-12 rows5-9)을 공기로 둘러싸 basher가 벽 끝에서 자연 종료 → **cookie 불필요**(§3g cookie는 "설계 가능" 옵션이었고 HTML 정본 시안은 미사용). stage07 신규 슬롯(layout/tres/scene) + SceneFlow STAGE_SCENES[7]+LAST_STAGE_ID 6→7 + menu slot7 해금. 테스트: CampaignS7Clear(basher 1회→영구 통로→saved4/4 lost0)/NoBasher(picks0 time_out) 신규 + MenuLayout(i<7)·StageSelectUnlock(slot7 LOCKED·priority retarget slot7→slot8)·GameFlow ScenB(Stage06→Stage07 basher last-stage) 갱신. **큐레이트 회귀 전부 green, 0 회귀**. 다음=S8 "박하 덤불"(cutter 식물 절단 + sticky 감속 — plant 태그·water/sticky 해저드 B2 일부 선행).

**2026-06-03 세션 8 (커밋 `e4a3f61`+`c67281d`, base `34269ac`)**: **불괴 cookie 타일 타입(코어) + S6 "땅굴" stage06 저작**(§3g가 SoT). digger 코어는 Phase 18 완비라 **데이터 저작 + 작은 코어 1건**. ⚠ 핵심: digger "안전 하강"은 굴착(WorkerState) 낙하라 깊이 무관·기절 미검사 → **개척자는 무-floater 자력 하강**, *공유 갱도 후속*만 floater 필수. 사용자 결정="깊은 하강+낙하산+개별 굴착 가능" → inventory digger6+floater6. `StageLayoutBuilder.TILE_COOKIE_SOLID`(kind="cookie", `destroy_tile_at` 거부=벽·챔버 불괴, 임시 색조, Terrain 무변경, earth backward-compat) + stage06(흙 캡 지붕→공동 7칸 floater 강하→쿠키 챔버 candy). 테스트: CookieTileGuard·CampaignS6 Clear/NoDigger/NoFloater 신규 + EarthBackwardCompat/StageSelectUnlock/MenuLayout/GameFlow ScenB 갱신. **큐레이트 18 + S6 8 전부 green, 회귀 0**. SceneFlow STAGE_SCENES[6]+LAST_STAGE_ID6, menu slot6 해금. 다음=S7 "옆파기"(basher, 현 코어 동작 예상).

## 0.6. 현재 라이브 파라미터 스냅샷 (SoT 테이블 — 2026-06-07 실측)

> ⚠ **이 표가 권위.** 아래 §3b~§3j의 세션별 서술은 *해당 커밋 시점*의 기록이며, 이후 밸런스 패치로 수치가 바뀌었다. **인라인 서술과 본 표가 충돌하면 본 표(`data/stages/stage0*.tres` 실측)를 따른다.** 레벨 재개정 시 이 표를 갱신할 것.

| Stage | 이름 | available_skills (인벤토리) | 마리 | hp | 제한 | ★ 임계 |
|---|---|---|---|---|---|---|
| S1 | 첫 마실 | climber(5) | 5 | 5 | 90s | 0.6 / 0.8 / 1.0 |
| S2 | 오르막 | climber(6), floater(1), blocker(1) | 7 | 5 | 100s | 0.5 / 0.75 / 1.0 |
| S3 | 사탕 호수 | bridge(2) | 5 | 5 | 110s | 0.5 / 0.75 / 1.0 |
| S4 | 계단 공사 | builder(1) | 5 | 5 | 110s | 0.5 / 0.75 / 1.0 |
| S5 | 막대과자 탑 | sand_mound(1), floater(1) | 6 | 5 | 120s | 0.5 / 0.75 / 1.0 |
| S6 | 땅굴 | digger(1), climber(5) | 5 | 5 | 120s | 0.5 / 0.75 / 1.0 |
| S7 | 옆파기 | basher(2) | 5 | 5 | 120s(기본값) | 0.5 / 0.75 / 1.0 |
| S8 | 박하 덤불 | cutter(1), leaf_jump(3) | 5 | 5 | 60s | 0.5 / 0.75 / 1.0 |
| S9 | 종합 과자점 | bridge(1), basher(1), blocker(1), sand_mound(1) | 6 | 5 | 150s | 0.6 / 0.8 / 1.0 |

**서술 → 라이브 주요 드리프트 (역사 서술이 stale한 지점)**:
- **S1**: 서술 `total=8 / climber=8` → 라이브 `total=5 / climber=5`. (blocker는 2026-06-07 onboarding 트랙에서 제거 — exact-fit 소프트락 해소, climber 단일 튜토리얼. 첫 blocker 등장=S2.)
- **S2**: 서술 `total=8 / climber6+floater1+distributor1` → 라이브 `total=7 / climber6+floater1+blocker1`. **distributor 제거**(F-3 은퇴 정합). floater 단독 분배.
- **S3/S4/S7**: 인벤토리 수량 하향 — `bridge 5→2`, `builder 6→1`, `basher 4→2`.
- **S5**: `floater 6→1`.
- **S6**: 서술 `digger6+floater6` → 라이브 `digger1+climber5`. **동반 스킬이 floater가 아니라 climber**(F-14 보정과 교차 — 깊은 강하 안전 처리 방식이 floater 분배가 아닌 climber 경로로 바뀐 것으로 보임. 메커니즘 실기 확인 권장).
- **S8**: 서술 `cutter4 + sticky 해저드` → 라이브 `cutter1 + leaf_jump3`. **leaf_jump(장치 설치형) 스킬 추가.** sticky는 해저드(스킬 아님)로 잔존.
- **S9**: 서술 `hp5/8마리` → 라이브 `6마리`.
- 전반: 인벤토리 수량이 **희소(scarce)** 방향으로 일괄 하향 = Lemmings "skill scarcity" 패턴(정밀 배치 강요). ★ 임계는 S1·S9만 `0.6/0.8/1.0`, 나머지는 `0.5/0.75/1.0`.

**해저드(Water/Sticky) 실측**:
- **Water(소다물, 즉사) Area2D 인스턴스가 9개 스테이지 전부에 존재** — 주로 가장자리(col −1 등)·바닥(rows 12~14, y≥600)에 깔린 **보편 경계 해저드**(떨어지면 lost). S1~S9 공통 안전망. `collision_layer=8`.
- **S3 "사탕 호수"** 만 물을 **플레이 경로 중앙**(갭)에 배치해 bridge 학습의 핵심으로 삼음.
- **S8 "박하 덤불"**: Sticky(`StickyHazard`, 3초 정지·잃지는 않음) 인스턴스 + Water. plant 벽(cutter 전용).
- → "물은 S3 전용"이라는 서술은 부정확. **물은 보편 경계이고, S3가 그것을 퍼즐화**한 것.

**입력 모델 매핑**(`docs/DOMAIN_MAP.md` §2.1 기준): ③무장=climber·bridge·builder / ②정착·이탈=blocker·floater / ①푯말=sand_mound·digger·basher·cutter / ④장치=leaf_jump. 캠페인이 4종 모두 도입(④는 S8 leaf_jump가 유일).

---

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
- **▶ 세션 5 델타 (소다 워터 + 다리 무장 개편, 미커밋)**: 위 "기하" 줄의 *Water 8개(row10, 504)* 와 "메커니즘" 줄의 *per-tile deactivate로 안전*·*col8 즉시 시전* 은 더 이상 현재 상태가 아니다.
  - **소다 워터**: 물 표면 = **row11**(지면 row10보다 한 칸 아래), 심부 = row12~13. 갭 row10은 공중으로 비워 다리(row10 평지)가 물 위 1칸 위를 가로지른다 → 개미가 물에 안 닿아 안전(deactivate는 row10에 물이 없어 no-op). 시각: `WaterHazard.deep` export(false=`soda_water_surface_square`, true=`soda_water_inner_square`; 즉사 동작 동일) + `Water.tscn` 기본 텍스처 surface. Stage03 물 인스턴스 8 → 24(row11 surface ×8 + row12~13 inner ×16). **새 PNG는 `--import` 부트스트랩 필요**(.import gitignore).
  - **다리 무장(armed)→낭떠러지 자동 건설**: 다리 부여 = 즉시 건설 아님. 평지 부여 시 `Ant.bridge_armed` 무장 후 보행 → 낭떠러지(`bridge_cliff_ahead`: 전방 셀 빔 + 전방-아래 셀 바닥 없음) 도달 시 Walker/Carrying이 자동으로 WorkerState("bridge") 진입(지표면 높이). 낭떠러지 즉시 부여는 하이브리드로 즉시 건설(기존 테스트 무변경). 빌드 로직(`_place_bridge_tile`)·길이(8)·종료(far-side) 불변.
  - **다리 타일 텍스처**: `thin_cookie_bridge_tile`(32×16, y-offset hack) → `biscuit_bridge_middle_horizontal_concept_01.png`(48×48). `Terrain._configure_dynamic_tile_sprite`가 사다리/basher/rung과 동일한 `_apply_tex_to_sprite`(region 없이 셀 중앙 + cell_size 비례 scale)로 렌더 후 **`position.y -= cell_size/4`** 보정 — 비스킷 불투명 윗면(프레임 12행)을 셀 상단(지표면 보행선)에 맞춰 양옆 지면과 단차 제거(사용자 스크린샷 피드백). **시각만** — 콜리전(48×48 별도)·게임플레이 불변.
  - 회귀 19종 PASS(§0 세션5 상세). 신규 `CampaignS3ArmedBridgeTest`(지연 입증).

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

## 3f. 완료 — 후속 개미 사다리 수직 통행(코어) + S5 "막대과자 탑" stage05 저작 (세션 7)
**전제 — 세션 5·6 커밋 반영**: §0의 "세션 5(소다 워터+다리 무장)"는 `544df23`, "세션 6(계단 개편)"은 `a962a9f`로 **커밋 완료**(문서의 "미커밋" 표기는 stale). 세션 7 base = `a962a9f`(S1~S4 + biscuit ladder `9c48f88` 포함).

**⚠ §5.2 선결정 해소(사용자 결정 = "코어 추가: 사다리 통행")**: biscuit ladder(`9c48f88`)는 **시전 개미만** rung을 깔며 등반하고, WalkerState는 수직 rung을 등반 전이에서 제외(climber·STAIR만) → 후속 개미는 rung 벽에 flip, 재시전도 "위 칸 solid→종료"라 안 통함. S5(HP4 → ≥4마리 등반)는 현 코어로 클리어 불가(S4 step-up 전과 동형). → **수직 사다리 통행 코어 신설**.

**코어 — `LadderClimbState`(신규) + 게이트 + 술어 + WalkerState 전이**:
- `Terrain.is_ladder_cell(cell)` = `_sand_mound_sprites.has(cell)`(기존 rung 레지스트리 재사용, add_tile/destroy 정합). 정적 벽은 ladder 셀 아님 → S1 분지 climber 퍼즐 보존(CampaignS1NoClimber PASS 실증).
- `Ant.ladder_climb_ahead(dir)` = 전방 셀이 ladder rung 셀. `WalkerState`가 is_on_wall 시 climber→stair_climb 다음에 이 게이트로 `LadderClimbState` 전이(아니면 flip).
- `LadderClimbState`: StairClimbState처럼 move_and_slide 우회, **rung 기둥(_col)을 rung 셀만 수직 글라이드 관통**. 꼭대기는 **즉시 cap/open 착지**(비-rung 레지 칸을 글라이드 통과 안 함). 진입은 **같은 행 수평 진입**(대각 코너 관통 방지) 후 수직. CarryingState 미적용(S5는 빈손 등반·floater 하강).
- **지지(support) 불변**: 매 frame `is_ladder_cell(_col, 현재행)` **단일 셀** — rung 파괴/소멸 시 즉시 FallerState(충돌 우회 글라이드로 무관 지형 관통·부분 파괴 통과 차단). blocked-top은 flip.

**S5 "막대과자 탑" stage05 저작** (HTML rev2 id:5 — 수직 사다리 ↑ + floater 귀가):
- **기하(cell 48)**: 바닥 표면 row11(solid 11~13, cols0~23) + 좌/우 벽(col0·col23 rows8~10) + **고립 오버행 플랫폼 row5 cols13~19**. Home(1,10 pos72,528)·Candy(16,4 pos792,240 플랫폼 위)·Camera(576,384)·Spawner(72,520.5).
- **메커니즘**: 첫 ant가 플랫폼 아래(cols14~17)서 sand_mound → rung 기둥 4개 + 레지 cap으로 플랫폼 등반. **후속 ant는 LadderClimbState로 자동 등반**(시전 1회로 충분). candy 회수 후 플랫폼 가장자리(6칸 낙하)를 **floater로 안전 하강**(무 floater=기절). 
- **파라미터** (`stage05.tres`): id=5 "막대과자 탑" / total 6 / hp 4 / 120s / available=[sand_mound, floater] / inventory={sand_mound:2, floater:6} / ★=[0.5,0.75,1.0] / release 30.
- **테스트**: CampaignS5Clear(시전1+후속자동등반 saved4/4 lost0)/NoSandMound(picks0 time_out) + **코어 회귀 4종**: LadderFollowerClimb(시전 안 한 개미도 레지 도달=≥2마리) / LadderDestroyMidClimb(등반 중 전체 rung 파괴→FallerState) / LadderPartialDestroyClimb(상단 rung만 제거·하단 잔존→FallerState=단일셀 지지) / LadderEntryHorizontal(기둥 도달 전 상승 금지=수평 진입 불변).
- **배선**: `SceneFlow.STAGE_SCENES[5]=Stage05.tscn` + `LAST_STAGE_ID 4→5`. `menu_layout` slot5 해금("막대과자 탑", available=true) + `MenuLayoutResourceTest` i<4→i<5. **`GameFlowTest` Scenario B를 Stage04 builder→Stage05 sand_mound+floater last-stage 재작성**(`_apply_stage5_skills_if_ready` _process 드라이버).
- **codex 적대적 리뷰 5라운드(R1~R4 HIGH 해소 → R5 approve)**: R1 지지 미재검증 → R2 검사 too late → R3 윈도우 too lax(아래 rung 통과) → R4 진입 대각 코너 관통 → R5 approve. 각 라운드 회귀 추가. 교훈: 충돌 우회 글라이드(StairClimb류) 상태는 **매 frame 단일-셀 지지 재검증 + 비-rung 칸 글라이드 회피(즉시 착지) + 진입 대각 제거**까지 가야 terrain 동적 변형/코너 관통에 안전.

## 3g. 완료 — 불괴 cookie 타일 타입(코어) + S6 "땅굴" stage06 저작 (세션 8)
**전제**: 세션 7 base `34269ac`(S1~S5 + biscuit ladder). digger 코어는 Phase 18에서 이미 완비 — S6는 **데이터 저작 + 작은 코어 1건(cookie 타일)**.

**⚠ 핵심 발견 — digger의 "안전 하강"은 굴착 상태(WorkerState) 낙하라 깊이 무관**: digger는 흙 캡을 다 판 뒤 그 아래 공기(cavern)에서 `_digger_below_has_earth`=false → abort. 굴착 개미는 캡을 판 후 공동을 **WorkerState 중력으로** 낙하(FallerState 아님)하므로 **기절 검사를 거치지 않아 깊이와 무관하게 안전**. 그러나 그 개미가 남긴 수직 갱도로 **떨어지는 후속 개미는 FallerState 자유낙하 → ≥6칸이면 기절(lost)**. → **"개척자가 판 갱도를 무리가 공유"하려면 floater 필수**(개별 굴착하면 각자 WorkerState 안전 하강이라 floater 불요 = inventory가 둘 다 지원).

**사용자 결정(AskUserQuestion)**: "깊어지는 레벨엔 낙하산 배치 → 개별 굴착 가능". 즉 깊은 하강 + digger·floater 둘 다 available. 시각 구분은 "기능만, 아트 후속".

**코어 — `TILE_COOKIE_SOLID`(불괴, `StageLayoutBuilder`)**:
- `StageLayoutBuilder`: `const TILE_COOKIE_SOLID := "cookie"` + build() kind 매핑(plant/cookie/earth 분기) + `_add_cookie_visual`(solid 텍스처 + 차가운 색조 `Color(0.60,0.70,0.95)` 임시 구분) + `_is_collision_tile`에 추가. register_static_body(kind="cookie") → `Terrain._cell_kind="cookie"` → `destroy_tile_at(["earth"])`·`(["plant"])` 모두 거부 = 벽·챔버 구조 무결성(파괴 불가). **Terrain 무변경**(기존 kind 시스템 재사용). earth(기존 solid→earth) backward-compat 완전.
- 정식 흙/쿠키 텍스처 스왑은 아트 트랙 후속(설계 B3). 현재는 색조만.

**S6 "땅굴" stage06 저작**(HTML rev2 id:6 — 안전 수직 하강):
- **기하(cell 48, 박스 구조)**: 흙 캡(diggable "solid", cols1-22 rows2-5, 4칸 지붕) + 공동(air, rows6-12, 7칸) + 쿠키 챔버 바닥(cols1-22 rows13-14) + 쿠키 좌우 벽(col0·col23 rows2-14, enclose). Home(2,13 pos120,624)·Candy(18,13 pos888,624 hp4)·Camera(576,384)·Spawner(120,88.5) total6. 개미는 캡 위(row2)에서 보행 → digger로 지붕 굴착 → 공동 7칸 floater 강하 → 챔버 바닥 candy 회수·귀가.
- **메커니즘**: 첫 ant가 메사 top에서 digger → 흙 캡 수직 굴착 → 공동 abort → (개척자는 WorkerState 낙하라 무-floater 안전) → 챔버. 캡 구멍 영구 → 후속 ant는 그 구멍으로 **floater 강하**(무-floater면 ≥6칸 기절). candy_hp4 → 4마리 회수.
- **파라미터** (`stage06.tres`): id=6 "땅굴" / total6 / hp4 / 120s / available=[digger, floater] / inventory={digger:6, floater:6}(개별 굴착 지원) / ★[0.5,0.75,1.0] / release30.
- **테스트(전부 PASS)**: **CookieTileGuard**(earth 굴착O/cookie 굴착X 직접 단언 — 신규 코어 검증) + CampaignS6Clear(digger1+floater무리 saved4/4 lost0)/NoDigger(floater만→picks0 time_out, digger 필수)/NoFloater(digger만→개척자 saved1/4, 공유 갱도엔 floater 필수). 코어 회귀 갱신: **StageLayoutBuilderEarthBackwardCompat**(cookie kind 허용 + 충돌 카운트 포함, "earth/cookie" 불변식) + **StageSelectUnlock**(slots1~6 available 반영 — slot4·5는 세션6/7 선재 드리프트 동반 교정, priority 케이스 slot4→slot7 retarget) + **MenuLayoutResource**(i<5→i<6).
- **배선**: `SceneFlow.STAGE_SCENES[6]=Stage06.tscn` + `LAST_STAGE_ID 5→6`. `menu_layout` slot6 해금("땅굴", available=true). **`GameFlowTest` Scenario B를 Stage05→Stage06**(digger 흙 캡+floater last-stage) 재작성.
- **회귀**: 큐레이트 18종(S1~S5 clear/neg·SceneFlow×2·Hud·Scoring·Digger/Basher/Cutter·LayoutBuilder×2) + S6 신규/수정 8종 = 내 변경 0 회귀.
- **교훈**: ① digger 안전 하강 = 굴착 상태 낙하(기절 미검사)라 **개척자는 무-floater 자력 하강** — "floater 필수성"은 *공유 갱도 후속*에 한정(테스트 단언을 saved<orig로 재구성). ② cookie는 별도 굴착 abort가 아니라 **공기 cavern이 이미 digger를 멈춤** — cookie의 진짜 역할은 *벽·챔버를 플레이어가 못 부수게* 하는 구조 무결성. ③ 캠페인 슬롯 해금 시 `StageSelectUnlock` 같은 슬롯-상태 테스트도 동반 갱신 필요(세션4·6 미갱신 드리프트 교훈).
- **codex 적대적 리뷰 (working-tree R1 → 커밋 `e4a3f61` → branch R2)**: R1 **HIGH 1**(stage06 파일 untracked인데 SceneFlow/menu가 S6 노출 → 부분 커밋 시 `load()`=null 크래시) → **원자적 커밋으로 해소** + `SceneFlow.load_stage` null 가드 추가. R2(커밋 diff) **HIGH 0, MEDIUM 2**: **M1**(digger6라 개별 굴착으로 floater 우회 가능 = "floater 필수" 미강제) → **defer(의도된 이중 해법, 사용자 결정 "개별 굴착 가능". 접근 가능 해법=공유 갱도+floater, 숙련 해법=개별 굴착. NoFloater 테스트는 *공유 갱도* 계약만 단언하고 주석에 명시).** **M2**(null 가드가 `_unload_current_screen()` 후라 실패 시 현재 화면 파괴) → **수정**(load+검증을 unload 전으로 이동, unknown-stage 가드와 동일하게 화면 보존, 후속 커밋). MEDIUM은 정책상 수정 의무 없으나 M2는 cheap·correct라 수정, M1은 설계 의도라 defer.

> **⚠ 보정 (2026-06-06, Design B — `BUGFIX_POLISH_LOG.md` F-14가 권위)**: 위 §3g의 "개척자는 WorkerState 낙하라 무-floater 안전 자력 하강"(메커니즘·교훈①·M1 defer 포함)은 **폐기됨**. digger 자유낙하 기절 수정으로 digger의 굴착-낙하 면역이 제거되어, **digger는 흙 캡(천장)을 뚫는 역할일 뿐 공동 7칸 강하는 개척자 포함 전원이 floater를 필요**로 한다(누구든 공동 진입 시 자유낙하 → 기절). "개별 굴착으로 floater 우회"(M1) 해법도 함께 폐기 — 개별 굴착해도 자기 갱도의 공동 낙하에서 기절한다. 지오메트리(공동 air)는 무변경. `CampaignS6NoFloater`는 saved 0(전원 기절), `CampaignS6Clear`는 digger+분배자 floater로 saved 4/4. 상세·검증은 F-14 참조.

## 3h. 완료 — S7 "옆파기" → stage07 락 슬롯 저작 (세션 9, 커밋 대기)
**전제**: 세션 8 base `c67281d`(S1~S6). basher 수평 굴착 코어는 Phase 18에서 완비 — S7은 **순수 데이터 저작**(코어 0 변경). §5.3 예상("basher는 수평 통로라 등반 불필요 = 현 코어로 동작") 적중.

**HTML rev2 id:7 시안**: `fills:[["sol",0,10,23,12],["E",9,5,12,9]]`, home:[1,9], candy:[20,9], path:[1,9]→[8,9]→[12,9]→[20,9]. intent="Home과 사탕 사이 흙 벽 → basher 2칸 높이 통로. 통로 영구라 귀가도 같은 통로". note="파괴계 첫 등장, 왕복 친화적".

**기하(cell 48, w24 h13)**:
- 바닥 solid cols0-23 rows10-12(3행) — 표면 row10 top(y=480) = 보행선. Home(1,9)→Candy(20,9) flat.
- 흙 벽 solid cols9-12 rows5-9(kind=earth) — 표면 row10 위에 5행 높이로 서서 row9(보행 body cell)를 막음.
- Home Area2D (72,480) / Candy (984,480) hp4 / Camera (576,384) / Spawner (72,472.5) total6.

**메커니즘**: 첫 ant가 col8(x≈384, body_cell forward=col9 earth)서 basher 시전 → `WorkerState("basher")`가 body row(row9)+위 row(row8) 2칸 통로를 cols9-12 굴착 → col13(공기, get_cell_kind≠earth)서 `_basher_forward_has_earth`=false → 자연 종료 → walker 복귀 → candy 진행. 흙 rows5-7(cols9-12)은 통로 위 overhang으로 잔존. 통로 영구 → 후속/귀가 ant가 같은 통로로 통행(forward-earth 게이트라 재시전 없음 — 실측 bashes=1). **cookie 미사용**: 벽이 공기로 둘러싸여 자연 종료하므로 §3g cookie 막이 불요(정본 시안 준수).

**파라미터** (`stage07.tres`): id=7 "옆파기" / total6 / hp4 / 120s / available=[basher] / inventory={basher:4} / ★=[0.5,0.75,1.0](오름차순, HTML 시안 [1.0,0.75,0.5] 내림차순을 §6 교정 규칙대로 반전) / release30.

**테스트(전부 PASS)**: **CampaignS7Clear**(forward-earth 게이트 basher→saved4/4 lost0 bashes1 frame1628) + **CampaignS7NoBasher**(무시전→흙 벽 flip 왕복→picks0 time_out, basher 필수성). 갱신: **MenuLayoutResource**(i<6→i<7) + **StageSelectUnlock**(case_initial slot7 COMING_SOON→LOCKED, priority case clear[1..7]+검증 slot7→slot8 retarget) + **GameFlow Scenario B**(Stage06 digger → Stage07 basher last-stage 재작성 — `_apply_stage7_skills_if_ready` _process 드라이버, forward-earth 게이트).

**배선**: `SceneFlow.STAGE_SCENES[7]=Stage07.tscn` + `LAST_STAGE_ID 6→7`. `menu_layout` slot7 해금("옆파기", available=true). 슬롯8~10 "준비 중" 유지.

**회귀(0 회귀)**: 큐레이트 — S1~S6 Clear / SceneFlow×3(LastStagePredicate 포함=LAST_STAGE_ID 변경 직접 영향) / LayoutBuilder×2 / BasherTunnel/EdgeStop. 내 변경(SceneFlow·menu·menu 테스트·GameFlow) 전부 green.

**교훈**: ① basher처럼 수평 파괴 스킬은 등반 코어 의존이 없어 **데이터 저작만으로 완결**(S4/S5의 코어 갭과 대조) — 핸드오프 예측이 정확했다. ② 흙 벽을 공기로 둘러싸면 basher가 forward-earth false로 자연 종료 → cookie 막이는 *옵션*이지 필수 아님. ③ LAST_STAGE_ID 증가 시 `SceneFlowLastStagePredicateTest`·`GameFlow Scenario B`(last-stage Next-disabled)·`StageSelectUnlock`(priority retarget)·`MenuLayout`(i<N)가 동반 갱신 대상(세션4·6 드리프트 교훈 답습).

## 3i. 완료 — S8 "박하 덤불" → stage08 락 슬롯 저작 (세션 10, 커밋 `d2632d5`)
**전제**: 세션 9 base `eb0e15c`(S1~S7). cutter 수평 절단 코어는 Phase 19에서, sticky 해저드는 Phase 17에서, plant 정적 타일(`TILE_PLANT_SOLID`)은 Phase 19에서 이미 완비 — S8은 **순수 데이터 저작**(코어 0 변경). S7과 동형(예측 적중: cutter=basher 구조).

**HTML rev2 id:8 시안**: `fills:[["sol",0,10,23,12],["P",12,5,14,9]]`, sticky:[[5,9],[6,9],[7,9]], home:[1,9], candy:[20,9], cutter×4, total6, hp4, 130s. intent="식물 벽 = cutter 전용(basher 무효). 끈끈이로 감속 학습."

**⚠ cutter는 basher와 절단 프로파일이 다르다**: basher는 `_destroy_basher_cell`이 body row(필수)+위 row(best-effort)=**2칸 통로**를 굴착하지만, cutter `_destroy_cutter_cell`은 **body row 1칸만** 절단(위 row 미절단). 식물 벽 rows5-9 중 cutter는 row9(body)만 열고 rows5-8 plant가 통로 위 overhang으로 잔존 → 개미 충돌(18×15px)이 1칸(48px)에 충분히 들어가 통과(CampaignS8Clear 4마리 횡단 실증).

**Sticky 선결정 해소**: Water.tscn류 **씬 인스턴스** 패턴 확정(layout 태그 X). Sticky.tscn(Area2D layer8/mask4 48×48, StickyHazard `duration=3.0`)이 이미 존재하고 `HazardBase._ready`가 `await physics_frame` 후 `floor(global_position/cs)`로 셀 자동등록(S3 Water·dev sticky 동일). layout 태그 방식은 sticky가 타일이 아닌 Area2D라 신규 인프라(B2 에디터) 필요 = 범위 밖. **sticky는 감속이 아니라 3초 완전 정지**(`Ant.is_stuck()`=`_sticky_remaining>0`이면 Walker/Carrying `update`가 좌우 정지). 셀당 1회(body_entered frame-dedup) → 3셀=누적 ~9초 지연이나 치명 무관(lost 불변).

**기하(cell 48, w24 h13)**:
- 바닥 solid cols0-23 rows10-12(3행) — 표면 row10 top(y=480)=보행선. Home(1,9)→Candy(20,9) flat(S7과 동일 좌표).
- 식물 벽 plant cols12-14 rows5-9(kind=plant) — 표면 row10 위 5행 높이, row9(보행 body cell)를 막음.
- Sticky 3개 cells (5,9)(6,9)(7,9) → 씬 인스턴스 pos (264,456)(312,456)(360,456)(=col*48+24, row9*48+24=456). 보행 body row라 통과 개미가 overlap.
- Home Area2D (72,480) / Candy (984,480) hp4 / Camera (576,384) / Spawner (72,472.5) total6.

**메커니즘**: 첫 ant가 sticky 통과(3초×3 정지) 후 col11(forward=col12 plant)서 cutter 시전 → `WorkerState("cutter")`가 body row(row9) cols12-14 절단 → col15(공기, kind≠plant)서 `_cutter_forward_has_plant`=false → 자연 종료 → walker 복귀 → candy 진행. plant rows5-8(cols12-14)은 overhang 잔존. 통로 영구 → 후속/귀가 통행(forward-plant 게이트라 재시전 없음, 실측 cuts=1). **cookie 미사용**(S7과 동일 — 공기 둘러쌈으로 자연 종료).

**파라미터** (`stage08.tres`): id=8 "박하 덤불" / total6 / hp4 / 130s / available=[cutter] / inventory={cutter:4} / ★=[0.5,0.75,1.0](오름차순) / release30.

**테스트(전부 PASS)**: **CampaignS8Clear**(forward-plant 게이트 cutter→saved4/4 lost0 cuts1 frame2708 — sticky 통과해도 lost0) + **CampaignS8NoCutter**(무시전→식물 벽 flip 왕복→picks0, cutter 필수성). 갱신: **MenuLayoutResource**(i<7→i<8) + **StageSelectUnlock**(case_initial slot8 COMING_SOON→LOCKED, priority case clear[1..8]+검증 slot8→slot9 retarget) + **GameFlow Scenario B**(Stage07 basher → Stage08 cutter last-stage 재작성 — `_apply_stage8_skills_if_ready` _process 드라이버, forward-plant 게이트) + **StageLayoutBuilderEarthBackwardCompat**(plant를 **stage08_layout.tres만** 허용하는 path-gate — S1~S7은 earth/cookie 제한 유지).

**배선**: `SceneFlow.STAGE_SCENES[8]=Stage08.tscn` + `LAST_STAGE_ID 7→8`. `menu_layout` slot8 해금("박하 덤불", available=true). 슬롯9~10 "준비 중" 유지.

**codex 적대적 리뷰 2R**: R1 **MEDIUM 1**(backward-compat 테스트가 plant를 *전역* 허용 → S1~S7 plant 드리프트 못 잡음) → **path-gate fix**(plant=stage08만 허용, 나머지 earth/cookie) → R2 **approve 무findings**. MEDIUM이나 cheap·correct·자체 self-review 우려와 일치라 수정. **회귀(0 회귀)**: S1~S8 Clear / S8 NoCutter·S7 NoBasher / GameFlow A·B·C / SceneFlow×5 / LayoutBuilder×2 / Cutter·Sticky·Basher 스킬 스위트 / Hud·StunFall 전부 green. (`test_CutterSkill`/`test_StickyHazard`/`test_BasherSkill`은 `.tscn` 없는 stub `.gd` = 선재, 무관.)

**교훈**: ① cutter/basher는 같은 WorkerState 파생이나 **절단 칸 수가 다르다**(cutter 1칸 / basher 2칸) — 식물 벽 통과는 개미 15px가 1칸에 들어가 OK지만 새 파괴 스킬 stage 저작 시 절단 프로파일을 확인할 것. ② sticky는 "감속"이 아니라 **3초 정지**(셀당) — HTML "감속" 표기와 구현이 다르니 셀 수로 체감 지연 조절. ③ backward-compat 테스트에 새 kind 도입 시 **path-gate로 정본 stage만 허용**(전역 허용은 다른 stage 드리프트 가드 무력화 — codex MEDIUM 교훈). ④ Godot headless stdout 버퍼링으로 종료 시 PASS print가 잘릴 수 있음 — **exit code가 권위**(음성 테스트는 exit0=클리어 안 됨, 클리어 시 `_fail`→exit1이라 견고).

## 3j. 완료 — S9 "종합 과자점" → stage09 신규 슬롯 저작 (세션 11, 커밋 `cf7ecff`)
**전제**: 세션 10 base `2da0f0d`(S1~S8). **마지막 스테이지**. bridge(Phase 16/세션5 무장)·basher(Phase 18)·builder(Phase 16/세션4·6 무장+gated step-up) 코어 전부 완비 — S9는 **순수 데이터 저작 + 테스트 드라이버**(코어 0 변경). S1~S8과 달리 **복수 스킬 게이트**라 §5.4 선결정을 사용자와 정렬: **HP5/8마리/150s(HTML 시안)** + **선두 1마리가 3구조물 모두 건설**.

**핵심 코어 사실(저작 전 확인)**:
- **bridge/builder 무장은 상호 배타**(`can_apply`이 `bridge_armed or builder_armed` 둘 다 차단, 2026-06-03 codex MEDIUM). → 동시 무장 불가 → 각 cliff(게이트1 물·게이트3 단)에서 **즉시 건설**로 적용(bridge 소비 후 builder 적용 = 위반 없음). basher는 비-무장(forward-earth)이라 독립 시전.
- **`StageLayoutBuilder.build()`가 모든 비-plant/cookie 타일을 kind="earth"로 매핑** → 흙 벽은 그냥 `"solid"` 타일이면 basher 대상. S9는 plant/cookie/water-tag 불필요, 순수 `solid`+`background`+water 씬 인스턴스.

**기하(cell 48, w24 h14, 보행면 row10/body row9)**:
- 좌 지면 cols0-8(rows10-13) · Home(1,9).
- **게이트1 소다 호수** cols9-12(4칸 갭, water surface row11 + inner rows12-13 씬 인스턴스 12셀). col8(x∈[384,432))서 bridge cliff_ahead → row10 평지 다리 4칸(BRIDGE_MAX_LENGTH=8 여유) → col13 착지. S3 소다 워터 패턴.
- 중앙 지면 cols13-17(rows10-13) + **게이트2 흙 벽** cols15-16(rows5-9, solid=earth). col14서 basher(forward-earth) → rows8-9 2칸 통로 → col17 자연 종료(실측 bashes=1).
- **게이트3 갭** cols18-20(무지면) + **높은 단** cols21-23(rows6-13, surface row6). col17(x∈[816,864))서 builder cliff_ahead → up-first 대각 계단 (17,9)(18,8)(19,7)(20,6) → 단 등반. Candy(22,5 pos 1080,288 hp5). S4 builder 패턴.

**파라미터** (`stage09.tres`): id=9 "종합 과자점" / total8 / hp5 / 150s / available=[bridge,builder,basher,floater] / inventory={bridge:2,builder:2,basher:2,floater:3}(×2는 여유분, floater는 실수 보험) / ★=[0.6,0.8,1.0](오름차순) / release30.

**⚠ 저작 중 발견·해결한 버그(basher가 builder 계단 오인 파괴)**: 동적 STAIR 타일이 **kind="earth"**라, builder 첫 계단 (17,9)(=보행 body row)를 **후속 개미가 col16에서 "전방 흙"으로 오인해 basher로 부숨** → 계단 바닥 소멸 → 선두 귀가 실패(saved=0)·후속 갭 추락(no_more_ants). **수정=드라이버 basher 게이트를 흙 벽 직전 col로 제한**(`body_cell.x >= 15` 차단). 실제 플레이어도 벽만 시전하므로 타당(S7/S8 forward-earth/plant 게이트와 동형). 코어 무변경(STAIR=earth는 의도된 동작 — 자기 계단 파괴는 플레이어 선택).

**테스트(전부 PASS)**: **CampaignS9Clear**(3게이트 발동 단언 `_bridge_applied && _builder_applied && _bashes>0` + saved5/5 lost0 bashes1 frame1926) + 음성 3종 — **NoSkill**(무스킬→호수 추락 picks0)·**NoBasher**(bridge+builder만, `_reached_wall`=개미가 col14 실제 도달→벽서 막힘 picks0)·**NoBuilder**(bridge+basher만, `_reached_gap`=개미가 col17 실제 도달→갭서 막힘 picks0). 음성은 **위치 마커로 선행 게이트 물리 통과를 단언**(apply() 호출이 아닌 실제 통과 — codex R2). 갱신: **MenuLayout**(i<8→i<9)·**StageSelectUnlock**(case_initial slot9 COMING_SOON→LOCKED, priority slot9→slot10 retarget·clear[1..9])·**GameFlow ScenB**(Stage08 cutter→Stage09 3-스킬 `_apply_stage9_skills_if_ready` last-stage 재작성, time_scale 8x 결정적).

**배선**: `SceneFlow.STAGE_SCENES[9]=Stage09.tscn` + `LAST_STAGE_ID 8→9`. `menu_layout` slot9 해금("종합 과자점", available=true). slot10만 "준비 중" 유지.

**회귀(0 회귀)**: 큐레이트 — S1~S8 Clear / SceneFlow LastStagePredicate·ScreenState / StageDialog LastStageTitle·Dismiss·Sfx·PauseSafe / SaveData RecordClear·StarOverride·Malformed / Bridge·Basher·Builder 스킬 스위트 / GameFlow A·B·C(3x 결정적) 전부 green.

**codex 적대적 리뷰 4R**: R1 MEDIUM(클리어 테스트가 3게이트 발동 미단언)→3게이트 단언+페어 음성 신설 / R2 MEDIUM×2(음성이 apply() 호출만 확인, 물리 통과 미증명)→위치 마커(_reached_wall/_reached_gap) 추가 / R3 HIGH(stage09 리소스·S9 테스트 untracked→부분 커밋 시 깨진 내비)→**원자적 커밋 `cf7ecff`로 해소**(S6 R1 선례) / R4(커밋 diff)=**approve, no material findings**. (R1/R2 MEDIUM은 정책상 수정 의무 없으나 자체 리뷰 우려와 일치+cheap·correct라 보강.)

**교훈**: ① 복수 스킬 게이트 stage는 cliff별 즉시 건설(무장 상호 배타 회피) + forward-earth 위치 게이트 분리가 정공법. ② **동적 STAIR=kind earth** → basher/cutter 드라이버와 builder를 혼용하면 계단을 흙으로 오인 → 파괴 스킬 게이트를 벽 col로 제한 필수(새 복합 stage 주의). ③ 음성 테스트는 skill `apply()` 호출이 아닌 **개미의 물리적 위치 도달**로 선행 게이트 통과를 단언해야 게이트별 독립 필수성이 진짜 증명됨(codex R2 교훈). ④ **레벨 재설계 캠페인 S1~S9 완결** — 9스테이지 전부 저작.

## 4. 남은 작업 (권장 순서)

### A. 선행 정리 — 코드/에셋 (캠페인 저작 전 필수)
- [x] **A1. builder/bridge 운반자 허용 통일** — **완료(세션 3, 커밋 `2546212`)**. `BridgeSkill.can_apply` Walker/Carrying 허용 + has_candy 거부 제거. 상세 §3d. bridge 8종 회귀 PASS.
- [x] **A2. 기절(Stun) 메커니즘** — **완료(commit 1f2a162)**. `FallerState.enter()` 낙하 시작 y 기록 → 착지 시 `(착지y−시작y) >= 5×cell_size` & floater 미보유 → `DeadState`(신설 대신 **DeadState 재활용**). DeadState가 stun 애니 ~1초 재생 후 queue_free + 운반 시 candy_piece_lost(LostState 동일 회계). `Ant._cell_size`는 `_resolve_kill_bounds`에서 캐시, `stun_fall_threshold()`. `ant_stun` sfx id(P21 대기). floater 높이 무관 무효. 검증: `tests/StunFallTest`(5칸→기절+lost / 4칸→생존 / floater→생존 PASS).
- [x] **A3. 기절 스프라이트** — **완료(commit 1f2a162)**. `assets/sprites/characters/ant_pajama_girl/stun/`(PNG4) + AntFrames `stun` 애니(loop, speed6).
- [ ] **A4. (아트) stair 스프라이트 검토**: `cookie_stair_tile.png`가 대각 상승으로 잘 읽히는지. 충돌/로직은 정상.
- [x] **A5. builder 계단 보행 등반(코어 gated step-up)** — **완료(세션 4)**. WalkerState `_try_stair_step_up`(전방/발밑 STAIR 게이트) + Terrain `_stair_cells`/`is_stair_cell`. 상세 §3e. S4 클리어 가능화의 전제. S1 분지(정적 벽) 보존 실증. **S5 sand_mound 사다리의 후속-개미 보행 통행은 별개 갭(수직)이라 미해결 — S5 저작 시 결정**(floater 하강 귀가는 설계됨, 등반은 시전 개미만 = candy_hp>1 다중 등반 필요 시 sand_mound도 통행 메커니즘 필요).
- [x] **A6. (세션 7) 후속 개미 사다리 수직 통행** — **완료(세션 7)**. `LadderClimbState` + `Ant.ladder_climb_ahead` + `Terrain.is_ladder_cell`. 상세 §3f. A5(대각 step-up)의 수직 대응. S5 클리어 가능화. codex 5R(R4 HIGH→R5 approve).

### B. 에디터 / 데이터 (map-editor 트랙)
- [ ] **B1. 파괴 종류 브러시**: 레이아웃에 `earth`(digger·basher)/`plant`(cutter) 태그 저작. 현재 에디터는 solid/slope만.
- [ ] **B2. 해저드 배치 모드**: water(즉사)/sticky(감속) 셀.
- [ ] **B3. 흙 vs 쿠키(불괴) 시각 구분 확인**.

### C. 캠페인 저작
- [x] **C1. 9개 `stageNN.tres` + `stageNN_layout.tres`** 저작 (HTML 시안 기반) — **전부 완료**. **S1 stage01**(§3b), **S2 "오르막"**(§3c), **S3 "사탕 호수"**(§3d), **S4 "계단 공사"**(§3e), **S5 "막대과자 탑"**(§3f), **S6 "땅굴"**(§3g), **S7 "옆파기"**(§3h), **S8 "박하 덤불"**(§3i), **S9 "종합 과자점"**(§3j) 완료. **레벨 재설계 캠페인 9스테이지 완결.**
- [x] **C2. 진행 흐름 등록**: menu_layout 10슬롯·SaveData 언락(N-1 클리어)·"/30" denominator 확보. SceneFlow.STAGE_SCENES[1~9]·**LAST_STAGE_ID=9**(세션 11 갱신). **menu_layout**: 슬롯1~9 available=true(슬롯9 "종합 과자점"은 세션 11 해금, `MenuLayoutResourceTest` i<9 + `StageSelectUnlockTest` slot9 LOCKED·priority retarget slot9→slot10 동반 갱신). 슬롯10만 "준비 중"(available=false). S1~S9 완결이라 추가 슬롯은 후속 확장 시.
- [ ] **C3. blocker·distributor 재배치** + 무스킬 0번 온보딩 결정.

### D. 하우스키핑
- [x] **D1. builder 변경 커밋** — 완료(commit e0f9f02). 세션 2에서 builder/Strings/Home/Ant(blocker+stun)/S1+docs/theme 6커밋으로 분리.
- [x] **D2. stale 통합테스트 정리**: `Stage02HeadlessTest`(sand-bridge) + `Stage03HeadlessTest`(basher/blocker/cliff) **둘 다 폐기**(세션 3, git rm) — S2·S3 재저작으로 무효화. 대체: `CampaignS2/S3 Clear+Negative` 테스트.
- [ ] **D3. FloaterTraitTest 기존 실패 조사**: dev_stages/trait 스테이지에서 floater-only 개미가 낙하 미도달 → deadline. 기절 변경 무관(FallerState revert해도 실패 확인). 별도 조사 필요.
- [ ] **D4. (세션 3 신설) blocker/alternate-spawn 커버리지 보강**: `Stage03HeadlessTest` 폐기로 **D-1(AntSpawner spawn_direction_alternate) / D-2(BlockerSkill carrying 거부) / D-3(blocker clear) 통합 커버리지 소멸**. 둘 다 재설계 캠페인 미사용(blocker 보류·alternate 미사용)이라 defer. blocker/alternate 재도입 시 standalone unit test 신설.

## 5. 다음 세션 즉시 행동 (제안)
1. `python scripts/execute.py mvp validate` 1회(세션 시작 루틴) + `git log --oneline -8`로 baseline 확인. **세션 10 종료: S8 "박하 덤불" stage08 커밋 `d2632d5`(base `eb0e15c`), 워킹트리 clean(추적), 미push(로컬)**(§3i). ⚠ §6의 full-suite 선재 실패 4건(Climber/Digger/Distributor/Floater Trait류)은 여전히 baseline(내 변경 무관) — 큐레이트 세트로 회귀 검증.
2. ~~**S7 "옆파기" 저작**~~ **완료(세션 9, §3h)**. 예측대로 코어 0 변경.
3. ~~**S8 "박하 덤불" 저작**~~ **완료(세션 10, §3i, 커밋 `d2632d5`)**. cutter=basher 동형(코어 0 변경) + sticky 씬 인스턴스(Water 패턴). codex 2R(R1 MEDIUM=backward-compat 전역 plant → path-gate → R2 approve).
4. ~~**S9 "종합 과자점" 저작**~~ **완료(세션 11, §3j, 커밋 `cf7ecff`)**. bridge+basher+builder 복합 3관문 + last-stage 배선. 선결정=HP5/8마리/150s(HTML) + 선두 1마리 전부 건설. cliff별 즉시 건설(무장 상호 배타 회피) + basher col-게이트(STAIR=earth 오인 파괴 방지). codex 4R(R1/R2 MEDIUM 보강·R3 HIGH untracked 원자적 커밋·R4 approve). **레벨 재설계 캠페인 S1~S9 완결.**
5. **(선재 실패 정리)** §6의 pristine-HEAD 실패 4건(Climber/Digger/Distributor/Floater Trait류) — 내 변경과 무관하나 main이 full-suite green 아님. 조사·수정은 별도 항목.
6. (선택) **기절 5칸 경계 결함 근본수정 여부 결정**(§6 gotcha) — 현재는 스테이지를 6칸으로 우회.

## 6. Gotchas (다음 세션 주의)
- **⚠ 기절 5칸 경계 결함 (세션 3 발견)**: 기절 임계는 `fall_dist >= 5×cell_size`(=240px)인데, **기하학적 정확히 5칸 낙하는 기절을 발동 못 함**. 원인: `WalkerState.update`가 매 프레임 `velocity.y += gravity*delta` + `move_and_slide` 적용 → 개미가 ledge 이탈 후 같은 프레임에 off-floor가 되어 즉시 Faller 전이하는데, `FallerState.enter()`가 기록하는 `_fall_start_y`가 이미 중력 1프레임만큼 내려간 값 → 측정 fall_dist ≈ 239.x < 240 → 미발동. **실증**: 정확히 5칸 메사에서 floater 없는 개미 전원 생존(CampaignS2NoFloaterTest가 saved=5로 FAIL). **6칸(288px)으로 올리니 전원 기절(lost=5)**. → **레벨 저작 규칙: 기절을 의도한 낙하는 ≥6칸으로**. 디자인 "5칸=기절"을 살리려면 측정 로직 근본수정 필요(§5.4, 코어 변경이라 별도 작업).
- **⚠ star_thresholds는 오름차순 (세션 3 발견)**: 엔진 컨벤션은 `Scoring.STAR_THRESHOLDS=[0.50,0.80,0.95]` **오름차순**(`[1★최소비율, 2★, 3★]`, `compute_stars`는 `ratio>=threshold` 누적). HTML 시안 표기 `[1.0, 0.8, 0.6]`는 내림차순이라 **그대로 베끼면 `SaveData._is_clear_input_valid`가 거부**("malformed input" 경고 → 별점 미저장·attempts만 +1). **올바른 형식**: 3★=100/2★=80/1★=60이면 `[0.6, 0.8, 1.0]`. S1·S2 둘 다 내림차순 오저작이던 것을 세션 3에서 오름차순 교정(S1은 선재 버그).
- **검증은 `python scripts/run_test.py tests/Xxx.tscn`**(풀 프로젝트, autoload 활성). `godot --check-only --script`는 **autoload(EventBus) 부재로 의존 스크립트가 줄줄이 거짓 실패** → 단독 컴파일 체크 용도로 쓰지 말 것.
- Godot bin: `D:\Godot_v4.6.2-stable_win64_console.exe` (run_test.py가 자동 탐색).
- **water 해저드 저작(S3 이후)**: layout tile_map엔 water 없음 — `scenes/entities/hazards/Water.tscn`(Area2D, layer8/mask4, 48×48)를 **씬 World 아래 셀별 인스턴스**. `HazardBase._ready`가 `await physics_frame` 후 `floor(global_position/cell_size)`로 셀 등록. **표면행(예 row10) 1행이면 충분**(추락 개미 즉사 catch, dev 컨벤션). bridge tile이 `deactivate_hazards_for_placement(cell)`로 그 셀 water 끔 → 다리 위 안전. bridge 적용은 **갭 직전 마지막 지면 cell**(body_cell+(dir,+1)이 갭 첫 셀이어야 add_tile 성공)에서.
- **sticky 해저드 저작(S8 이후)**: water와 동일 — `scenes/entities/hazards/Sticky.tscn`(Area2D layer8/mask4 48×48, `StickyHazard duration=3.0`)을 씬 World 아래 셀별 인스턴스. `HazardBase._ready`가 셀 자동등록. **보행선 위 body row(예 row9)에 배치**해야 통과 개미가 overlap(water는 추락 catch라 표면행, sticky는 보행 body row). **감속 아니라 3초 완전 정지**(셀당 1회, frame-dedup) — 체감 지연은 셀 수로 조절. 새 PNG 아니므로 `--import` 불요(기존 `sticky_caramel.png`).
- **cutter vs basher 절단 칸 수**: cutter는 body row **1칸만**, basher는 body+위 **2칸**. 식물/흙 벽 통과는 개미 충돌 18×15px가 1칸(48px)에 들어가 OK지만, 천장이 막힌 좁은 통로 설계 시 차이 유의.
- **⚠ 동적 STAIR 타일 = kind "earth" → basher/cutter와 builder 혼용 stage 주의 (세션 11, S9 발견)**: builder가 까는 STAIR 타일은 `kind="earth"`라 basher `destroy_tile_at(["earth"])`의 대상이 된다. 복합 stage(S9)에서 basher 드라이버가 "전방 body cell == earth"만 보면 **builder 첫 계단(보행 body row에 위치)을 흙 벽으로 오인해 파괴** → 계단 붕괴. **드라이버 basher 게이트를 흙 벽 col 직전으로 제한**(S9는 `body_cell.x >= 15` 차단)해야 한다. 코어는 정상(STAIR=earth는 의도된 동작; 자기 계단 파괴는 플레이어 선택). 새 파괴+건설 복합 stage 저작 시 동일 게이트 필요.
- **복수 스킬 게이트 드라이버 패턴 (세션 11, S9)**: bridge/builder 무장은 **상호 배타**(`can_apply`이 둘 다 차단)라 한 개미에 동시 무장 불가 → 각 cliff(물·단)에서 **즉시 건설**로 적용(bridge 소비 후 builder 적용). basher는 비-무장 forward-earth라 독립. 테스트 드라이버 = S3 bridge x-window + S7 basher forward-earth(col-게이트) + S4 builder x-window 결합. 음성 테스트는 skill apply() 호출이 아닌 **개미 물리 위치 도달 마커**(_reached_wall/_reached_gap)로 선행 게이트 통과를 단언해야 게이트별 독립 필수성이 진짜 증명됨.
- `docs/LEVEL_DESIGN_PLAN.html`은 **gitignore(*.html)** — 커밋해도 안 올라감. 로컬 보존.
- **stage 슬롯 마이그레이션 패턴**(S2~S9 답습): ① `stageNN_layout.tres` 내용 이식(헤더 uid 유지) ② `stageNN.tres` 파라미터 ③ `StageNN.tscn` 엔티티 좌표(Home/Candy/Camera/Spawner)+hp+total ④ 지오메트리 하드코딩 테스트(GameFlowTest climber 좌표 등) 갱신 ⑤ 회귀(Hud/LayoutBuilder/GameFlow/SceneFlow). 경로 락이라 **파일명 유지·내용만 교체**.
- **세션 2 종료**: 8 커밋(`e0f9f02`~`58b0fbb`), HEAD=`58b0fbb`, 워킹트리 clean, 미push(로컬).
- **세션 3 종료**: ① S2 stage02 저작 + 버그2 → **커밋 `c8611e6`**. ② A1(BridgeSkill) + S3 stage03 저작(stage03.tres/layout/Stage03.tscn + Water8) + 신규 테스트(CampaignS3Clear/NoBridge) + Stage03HeadlessTest 폐기 + GameFlowTest Scenario B bridge 재작성 + 본 문서 → **커밋 `2546212`**. ③ 본 핸드오프 정정 docs 커밋. **HEAD 이후 추적 워킹트리 clean**. ⚠ climb 애니 2→8프레임 아트(AntFrames/climb_*.png/svg)는 **미커밋 병렬 트랙** — 스테이지 커밋에 섞지 말 것.
- **⚠ builder 계단 = 시각적 텔레포트 step-up (세션 4)**: walker가 builder STAIR(정사각)를 오를 때 `WalkerState._try_stair_step_up`이 `(dir*cs,-cs)`로 **순간 1칸 텔레포트**(builder/bridge/sandmound 텔레포트와 일관). 부드러운 보행 애니 아님. 게이트(전방/발밑 STAIR + 목적 셀 빈칸)라 **계단 없는 stage엔 미발동**(비계단 보행 바이트 동일). 정적 벽은 절대 step-up 안 함 = **climber 퍼즐 보존**(S1). CarryingState는 미적용(S4는 하강만 운반). 새 stair stage 저작 시 이 전제 활용 — builder는 단 표면보다 1칸 아래서 abort하지만 step-up이 마지막 1칸을 메운다.
- **⚠ full-suite 선재 실패 4건 (세션 4 발견, pristine HEAD `40cafc9`)**: `ClimberTraitTest`(mantle dx 37.93<38.00 0.07px 경계), `DiggerFallThroughUpperAntTest`, `DistributorSettleTest`, `FloaterTraitTest`(D3 기존)는 **내 변경 없이도 실패** = main이 141-full green 아님. 핸드오프의 "회귀 green"은 **큐레이트 세트**(S1~S3·GameFlow·Stun·Hud·Layout·Scoring·SaveData·SceneFlow) 기준이었음. + `SkillDropAssignTest`는 pristine HEAD엔 PASS·미커밋 아트(AntFrames) 존재 시 FAIL = **아트 트랙 회귀(또는 flaky)**. 모두 A5/S4 무관. 회귀 검증은 큐레이트 세트 + 변경 인접 테스트로 하되, full-suite 4건 선재 실패를 baseline으로 인지.
- **세션 4 종료**: A5 gated step-up(WalkerState+Terrain) + S4 stage04 저작(layout/tres/scene + CampaignS4Clear/NoBuilder) + SceneFlow(STAGE_SCENES[4]+LAST_STAGE_ID=4) + GameFlow Scenario B 재작성 + 본 문서 → **커밋 `ef2551b`**. 전체 141 회귀: 내 변경 0 회귀(선재 5건 제외 전부 PASS). ⚠ climb 아트는 여전히 미커밋 병렬 트랙 — 커밋에 섞지 말 것.
