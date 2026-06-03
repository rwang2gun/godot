# 버그 수정 & 폴리싱 로그

레벨 재설계 캠페인(S1~S9) 완결 이후의 **버그 수정 · UX 폴리싱** 작업을 누적 기록한다.

- **이 문서의 역할**: 작은 수정/폴리싱은 phase 절차를 거치지 않으므로, "무엇을·왜 고쳤는가"와 "고치진 않았지만 어색하거나 잘못된 것"을 한 곳에 남긴다.
- worklog(세션 단위)·`LEVEL_REDESIGN_STATUS.md`(레벨 저작 트랙)와 **직교**한다. 중복 기록 금지, 여기엔 버그/폴리싱만.
- 항목 형식:
  - **수정함(Fixed)**: 증상 → 원인 → 수정 → 검증
  - **미수정(Known issue)**: 어색/오류 내용 → 왜 지금 안 고쳤는가(효율·스코프) → 고친다면 어떻게

---

## 2026-06-03

### Fixed

#### F-1. 일시정지 메뉴 "타이틀로 돌아가기" → "메인 메뉴로 돌아가기"
- **증상/요청**: 일시정지 메뉴의 마지막 버튼이 타이틀 화면으로 보냈다. 메인 메뉴로 보내는 것이 의도.
- **원인**: 버튼 텍스트가 `"타이틀로 돌아가기"`이고, 핸들러 `_on_title_pressed`가 `EventBus.request_title`(→ `SceneFlow.go_to_title()`)을 emit.
- **수정**:
  - [scenes/ui/PauseMenu.tscn](../scenes/ui/PauseMenu.tscn) `TitleBtn.text` → `"메인 메뉴로 돌아가기"`
  - [scripts/ui/PauseMenu.gd](../scripts/ui/PauseMenu.gd) `_on_title_pressed`가 `EventBus.request_main_menu`(→ `SceneFlow.go_to_main_menu()`) emit. 헤더 주석 정정.
  - [tests/PauseMenuSmokeTest.gd](../tests/PauseMenuSmokeTest.gd) 주석을 새 동작에 맞게 갱신.
- **검증**: `python scripts/run_test.py tests/PauseMenuSmokeTest.tscn` → PASS.

#### F-2. 낙하산(floater) 스킬 = "낙하산 분배자"로 통합
> **⚠ F-3로 대체됨(superseded).** F-2는 "floater+distributor 트레잇 동승 + 마커 도달 시 정착" 단계였고, F-3에서 "적용 즉시 정착 + 사탕 드롭/재획득 + DistributorSkill 은퇴"로 발전. 아래 F-2 기술은 이력 보존용.
- **요청**: 사용자는 낙하산 스킬이 그 개미를 "낙하산 분배자"(정착해서 지나가는 개미에게 낙하산을 나눠주는 개미)로 만드는 스킬이라고 생각했음. 실제로는 `floater`(자기 강하) + `distributor`(정착·전이) **두 스킬을 조합**해야 했음(S2 인벤토리 `floater:1 + distributor:1`).
- **제약(충돌)**: `floater`는 S5/S6/S9에서 "각 개미 자신이 천천히 강하"하는 자기 낙하산으로도 쓰여, floater를 전역 "정착+분배"로 재정의하면 그 스테이지들이 깨짐. 정착(settle)은 씬에 `SettlementMarker`가 있어야만 발동하고 그 마커는 **S2에만** 존재.
- **결정 (사용자 선택: "floater에 distributor 결합")**: `FloaterSkill.apply`가 `floater` + `distributor` 트레잇을 **함께** 부여. 마커 없는 S5/S6/S9는 정착 트리거가 없어 distributor가 무해한 무동작(배지 없음, settle 배지는 `SettledState`에서만 표시)이라 자기 낙하산 용도 무영향.
- **수정**:
  - [scripts/skills/FloaterSkill.gd](../scripts/skills/FloaterSkill.gd) `apply`에 `ant.set_trait(&"distributor")` 추가 + 설계 주석.
  - [data/stages/stage02.tres](../data/stages/stage02.tres) 이제 중복인 `distributor`를 `available_skills`/`skill_inventory`에서 제거 → `["climber","floater"]`, `{climber:6, floater:1}`. floater 하나로 분배자 생성.
  - [tests/CampaignS2ClearTest.gd](../tests/CampaignS2ClearTest.gd) 선두 개미에 floater **단독** 부여로 단순화(단일 스킬 흐름 입증). `CampaignS2NoFloaterTest`는 원래 climber-only라 무변경.
- **검증**:
  - 의도 동작: `CampaignS2ClearTest` PASS(saved=5/5, floater 단독), `CampaignS2NoFloaterTest` PASS(picks=5/lost=5/saved=0).
  - 회귀(자기 낙하산): `CampaignS5ClearTest`/`CampaignS6ClearTest`/`CampaignS6NoFloaterTest`/`CampaignS9ClearTest`/`TraitCombinedTest` 전부 PASS — distributor 트레잇 동승이 무영향.
  - 연쇄 정착 방지: `SettlementTraitTransferTest` PASS, 전이받은 개미 `has_floater=true **has_distributor=false**`(TRANSFER_WHITELIST=[floater]만 전이)라 receiver가 또 정착하지 않음.

#### F-3. 낙하산 = "낙하산 분배자" 전면 재설계 (적용 즉시 정착 + 사탕 드롭/재획득)
- **요청**: "낙하산 스킬을 적용하면 적용한 순간 멈춰서 낙하산 분배를 시작. 들고 있던 사탕은 바닥에 떨어지고, 운반중이 아닌 다른 개미가 떨어진 사탕을 들고 갈 수 있다." + "지면에 위치한 개미에게만 부여 가능(낙하 중·물 속 불가)."
- **사용자 결정 (Q&A)**: ① S5/S6/S9 충돌 → **B: floater 분배자 전용**(자기 강하 폐기). ② 드롭 사탕 획득 자격 → **비운반 보행 개미 모두**(재생성 포함). ③ 미회수 드롭 → **즉시 lost 처리**(클리어 차단 안 함, 재획득 시 보정). ④ 구 DistributorSkill+정적-마커 테스트 → **전면 은퇴**. ⑤ 깨진 S5/S6 → **known-broken 보류**([[#K-5]]).
- **수정 (코어)**:
  - [FloaterSkill.gd](../scripts/skills/FloaterSkill.gd): `can_apply` = is_alive + **is_on_floor** + (Walker|Carrying) + not distributor. `apply` = (운반 중이면 has_candy 해제 + `candy_piece_lost` + DroppedCandy 생성) → floater+distributor 트레잇 → **즉시 SettledState 정착** → 자기 위치에 SettlementMarker 동적 생성(`bind_distributor`).
  - [SettlementMarker.gd](../scripts/world/SettlementMarker.gd): `bind_distributor(a)` 추가 — 분배자 직접 주입(settle 트리거 분기 우회) + 1 physics frame 뒤 `_drain_pending_receivers`로 이미 겹친 개미 즉시 전이.
  - [DroppedCandy.gd](../scripts/world/DroppedCandy.gd) + [DroppedCandy.tscn](../scenes/world/DroppedCandy.tscn) **신규**: Area2D(layer16/mask4). 비운반 WalkerState 개미 진입 시 → CarryingState 전이 **후** `candy_piece_recovered` emit(옵저버가 has_candy=true 정확 상태 관측) → queue_free.
  - [EventBus.gd](../scripts/core/EventBus.gd): `candy_piece_recovered(by_ant)` 신호.
  - [ScoreSystem.gd](../scripts/core/ScoreSystem.gd): `_on_recovered` = lost−1, in_transit+1 (드롭 시 lost 처리분을 재획득 시 보정, 4-카운터 유지·이중계산 방지). connect/disconnect 추가.
  - [stage02.tscn](../scenes/stages/Stage02.tscn): 정적 SettlementMarker 노드 제거(in-place 정착이라 불필요).
- **은퇴 (DistributorSkill — [[#K-3]] 해소)**: `DistributorSkill.gd` 삭제 + SkillRegistry/Strings(분배자 라벨)/SkillToolbar(아이콘·커서)/StringsTableTest/SkillIconPngSmokeTest에서 distributor 제거. **distributor.png/cursor + distributor 트레잇 + SettledState/SettlementMarker는 유지**(SettleBadge·마커·새 메커니즘이 사용). 구 정착/분배자 통합 테스트 10개 + dev_stages 픽스처 4개(settle/settle_race/settle_stuck/sticky_settle) + test_DistributorSkill 스텁 삭제.
- **신규 테스트**: `ScoreRecoveryAccountingTest`(드롭/재획득 회계 정합+불변식), `FloaterDistributorTest`(지면게이트 Faller거부 + 즉시정착 + 정착면역 + floater전이/distributor미전이), `FloaterDropRecoveryTest`(운반 개미 드롭→DroppedCandy 생성+정착 / 다른 walker 재획득→CarryingState).
- **slow-fall 트레잇 테스트 이관**: floater 스킬이 자기강하 대신 정착으로 바뀌어, `TraitCombinedTest`·`FloaterTraitTest`의 "FloaterSkill.apply로 자기강하" 검증이 깨짐. slow-fall **트레잇**은 still-live(분배자가 전이)이므로 `_ant.set_trait(&"floater")` 직접 부여로 이관. `TraitCombinedTest` PASS 복구(mean_dvy=6.75, 등반 후 감쇠 낙하). `FloaterTraitTest`는 트레잇 부여해도 deadline(그 스테이지에서 개미가 절벽 미도달=낙하 자체가 안 일어나는 선재 결함, 4대 선재실패 중 1건)이고 slow-fall 커버리지가 TraitCombined와 중복이라 **은퇴**.
- **검증**: 위 신규 3 + `CampaignS2Clear`(saved5/5)/`CampaignS2NoFloater` PASS. 회귀: `CampaignS1/S3/S4/S7/S8/S9 Clear`, `StringsTable`, `SkillIconPngSmoke`, `SkillDropAssign`, GameFlow/SceneFlow/UI 스윕(아래 세션 검증). **S9는 floater 미사용이라 영향 없음(PASS)**.
- **신규 class_name 주의**: `DroppedCandy` 추가 후 `python scripts/run_test.py --import`로 글로벌 클래스 캐시 등록 필요(미실행 시 `is DroppedCandy` Parse Error).

### Known issues (미수정 — 효율/스코프 사유로 보류)

#### K-5. S5·S6 자동 테스트 드라이버가 stale (레벨 자체는 클리어 가능 — 사용자 수동 검증 완료)
- **정정 (2026-06-03 사용자 보고)**: S5·S6 레벨은 **깨지지 않았다.** 사용자가 새 낙하산 분배자 메커니즘으로 **직접 플레이해 클리어 확인**(강하 지점에 분배자 배치 → 지나가는 개미가 우산 받아 안전 강하). floater 스킬 쓰는 다른 스테이지도 수동 클리어 "문제 없음".
- **실제 남은 문제**: `CampaignS5ClearTest`·`CampaignS6ClearTest` **자동 드라이버**가 옛 자기-강하 패턴(개미마다 floater 직접 부여)으로 작성돼 stale → `time_out, picks=0`으로 실패. **레벨 결함이 아니라 테스트 드라이버 결함.** (S9는 floater 미사용이라 무사.)
- **고친다면**: S5/S6 테스트 드라이버를 새 패턴으로 재작성 — 강하 지점 직전에서 선두 개미에 floater(분배자) 부여 → 후속 개미가 마커 통과 시 floater 받아 강하 → 클리어 단언. (`CampaignS2ClearTest`가 동일 패턴의 레퍼런스.) 레벨 데이터 변경 불필요.

#### K-6. 구 정착/분배자 테스트 은퇴로 일부 커버리지 축소
- **내용**: F-3 은퇴로 `SettledImmuneToHazardTest`(정착 개미 hazard 면역)·`SkillToolbarSettledTargetFilterTest`(정착 개미 스킬 타겟 제외)가 삭제됐다. 이 두 행동은 여전히 유효(SettledState terminal·toolbar 필터)하나 현재 직접 커버하는 테스트가 없다. (정착·전이·면역·드롭·재획득은 신규 3 테스트로 대체 커버됨.)
- **왜 안 고쳤나**: 전면 은퇴 결정 + 핵심 행동은 신규 테스트로 이관. 두 엣지(hazard 면역·타겟 필터)는 우선순위 낮아 보류.
- **고친다면**: 새 in-place 분배자(FloaterSkill)로 정착시킨 뒤 hazard 면역 / toolbar 타겟 제외를 검증하는 소형 테스트 2개 추가.

#### K-1. PauseMenu의 "title" 네이밍이 동작과 불일치
- **내용**: F-1로 동작은 "메인 메뉴로"가 됐지만, 노드명 `TitleBtn`, `@onready var _title_btn`, 메서드 `_on_title_pressed`는 여전히 "title"을 가리킨다.
- **왜 안 고쳤나**: 노드명을 바꾸면 `.tscn` 노드 경로 + `@onready` 경로 + `pressed.connect` + 메서드명 + `PauseMenuSmokeTest`가 직접 호출하는 `_pause_menu._on_title_pressed()`까지 연쇄 수정이 필요해 스코프가 커진다. 동작·표시 텍스트만 정정하는 최소 변경을 택함.
- **고친다면**: `TitleBtn`→`MainMenuBtn`, `_title_btn`→`_main_menu_btn`, `_on_title_pressed`→`_on_main_menu_pressed`로 일괄 리네임 + 테스트 호출부 동기화.

#### K-2. `EventBus.request_title` 시그널이 발화자 없는 reserved 상태
- **내용**: F-1로 PauseMenu가 더 이상 `request_title`을 쓰지 않게 되면서, `request_title` **시그널은 현재 어떤 발화자도 없다**. 다만 `SceneFlow._on_request_title`(구독자)은 남아 있고, `go_to_title()` 자체는 부팅 진입점([SceneFlow.gd:74](../scripts/core/SceneFlow.gd))과 legacy `start_game()`([SceneFlow.gd:79](../scripts/core/SceneFlow.gd))에서 **여전히 활발히 사용**된다(타이틀 화면 자체는 죽지 않음). 선언 주석에 이미 "reserved (현재 발화자 없음, 향후 phase 추가용)"로 적혀 있어 의도된 상태.
- **왜 안 고쳤나**: 죽은 코드 제거는 요청 범위 밖이고, "런타임 중 타이틀로 보내기"가 향후 다시 필요할 수 있다(타이틀↔메인 메뉴 분리 흐름).
- **고친다면**: 타이틀 복귀 UX가 영구히 불필요하다고 확정되면 `request_title` 시그널 + `SceneFlow._on_request_title` 구독 + PauseMenu의 `request_title.connect(_force_hide)`만 제거. **`go_to_title()`은 부팅에서 쓰이므로 유지.** 확정 전까지는 reserved.

#### K-3. `DistributorSkill`이 F-2 이후 캠페인에서 미사용 — ✅ F-3에서 은퇴 완료
> **해소됨**: F-3에서 DistributorSkill + 구 정적-마커 테스트 스위트를 전면 은퇴했다. distributor 트레잇/아이콘/SettledState/SettlementMarker는 새 in-place 메커니즘이 사용하므로 유지. 아래는 이력.
- **내용**: F-2로 S2가 floater 단독을 쓰게 되면서 `distributor` 스킬을 인벤토리에 가진 스테이지가 0개가 됐다. `DistributorSkill.gd` + `SkillRegistry`의 distributor preload + 아이콘/커서 에셋 + `distributor.png` 등은 남아 있으나 캠페인에선 호출 경로 없음. (단, distributor **트레잇**·`SettlementMarker`·`SettledState`는 floater가 의존하므로 여전히 핵심.)
- **왜 안 고쳤나**: 스킬 스크립트/에셋 제거는 요청 범위 밖이고, 향후 "낙하산 외 트레잇을 분배하는" 범용 분배자가 다시 필요할 수 있다(TRANSFER_WHITELIST 확장 시).
- **고친다면**: 범용 분배자가 영구히 불필요하다고 확정되면 `DistributorSkill.gd` + `SkillRegistry.SKILL_SCRIPTS`의 distributor 1줄 + 관련 아이콘/커서/Strings 항목 + distributor 단독 테스트(`DistributorSettleTest` 등) 일괄 정리.

#### K-4. 선재 테스트 실패 (내 변경과 무관 — pristine HEAD에서도 실패)
- **내용**: F-2 회귀 검증 중 `git stash`로 내 변경 제거 후에도 동일 실패 실증. 핸드오프 노트의 "pristine 선재 실패 4건" 중:
  - `FloaterTraitTest`(deadline)·`DistributorSettleTest`(정착 x drift 31.5px) — **둘 다 F-3에서 삭제됨**(FloaterTraitTest=자기강하 폐기로 obsolete+TraitCombined와 중복 / DistributorSettleTest=DistributorSkill 은퇴). 더는 스위트에 없음.
  - **남은 선재 실패 2건**: `ClimberTraitTest`(mantle 0.07px 경계), `DiggerFallThroughUpperAnt`. F-3와 무관, 별도 트랙에서 점검.
- **왜 안 고쳤나**: F-2 요청 범위 밖의 선재 결함. 메모리 핸드오프 노트에도 "pristine HEAD 선재 실패 4건(ClimberTrait mantle / DiggerFallThroughUpperAnt / DistributorSettle / FloaterTrait)"으로 이미 기록돼 있음.
- **고친다면**: 별도 버그 수정 작업으로 ① `FloaterTraitTest` 데드라인/측정 윈도우 재조정(또는 `TraitCombinedTest`로 커버되니 폐기 검토) ② `DistributorSettleTest`는 marker.x 대비 허용오차를 넓히거나, 정착 트리거 시 x를 marker.x로 스냅(`SettledState.enter`에서 `_settle_pos.x = marker.x`)할지 설계 결정 필요. **남은 선재 실패 2건**(`ClimberTraitTest` mantle 0.07px 경계, `DiggerFallThroughUpperAnt`)도 같은 트랙에서 함께 점검.
