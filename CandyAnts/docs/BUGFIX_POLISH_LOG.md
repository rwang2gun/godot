# 버그 수정 & 폴리싱 로그

레벨 재설계 캠페인(S1~S9) 완결 이후의 **버그 수정 · UX 폴리싱** 작업을 누적 기록한다.

- **이 문서의 역할**: 작은 수정/폴리싱은 phase 절차를 거치지 않으므로, "무엇을·왜 고쳤는가"와 "고치진 않았지만 어색하거나 잘못된 것"을 한 곳에 남긴다.
- worklog(세션 단위)·`LEVEL_REDESIGN_STATUS.md`(레벨 저작 트랙)와 **직교**한다. 중복 기록 금지, 여기엔 버그/폴리싱만.
- 항목 형식:
  - **수정함(Fixed)**: 증상 → 원인 → 수정 → 검증
  - **미수정(Known issue)**: 어색/오류 내용 → 왜 지금 안 고쳤는가(효율·스코프) → 고친다면 어떻게

---

## 2026-06-08 — 끈끈이 감속 땀 연출

> F-19에서 끈끈이를 "정지+게이지"에서 감속 존으로 재설계하며 머리 위 표식을 전부 제거했는데, 감속 중이라는 피드백이 시각적으로 약했다. 가벼운 땀방울 연출을 추가해 "지금 느려지는 중"을 비언어로 전달한다. **기록만 — 커밋은 사용자 확인 후.**

### Fixed

#### F-21. 끈끈이 감속 중 땀방울 연출 추가
- **내용(사용자 요청)**: 끈끈이로 느려질 때(`Ant.is_slowed()`) 머리 옆에 만화풍 땀방울을 띄워 감속을 시각화. F-19로 비운 머리 위 표식 자리를 가벼운 연출로 대체.
- **수정**:
  - 신규 에셋 [assets/icons/sweat_drop.svg](../assets/icons/sweat_drop.svg) — 만화풍 땀방울(하늘색 + 흰 하이라이트).
  - [Ant.tscn](../scenes/entities/Ant.tscn): `TraitBadges/SweatDrop` Sprite2D 추가(머리 중앙 (0,16)·scale 0.5·기본 숨김; 초안 (26,16) 우측 → 사용자 요청으로 중앙 정렬). 옛 정지설계 잔재 `StickyBadge`/`StickyTimerBar`는 그대로 둠(스코프).
  - [Ant.gd](../scripts/ant/Ant.gd): `_update_trait_badges()`(매 물리프레임, 시각 전용)에서 `_update_sweat()` 호출 — `is_alive() && is_slowed()` 진입/이탈 **전이에서만** 표시 토글 + 가벼운 bob/fade yoyo tween(매 프레임 churn 방지). 운반 중 개미도 끈끈이 감속하므로 동일 적용.
- **검증**: `AntStickyVisualTest`에 case (5) 통합(감속 중 SweatDrop 표시·이탈 시 숨김; 별도 중복 테스트 대신 기존 끈끈이 시각 가드에 합침). 끈끈이 스위트(AntStickyVisual/StickyCarryingPreserved/StickyStuckRelease/BridgeOverWaterStickyOverlap/WaterStickyOverlapLostTerminal)·CampaignS8 Clear/NoCutter·CampaignS1 Clear PASS. **tween 시각(위치/타이밍)은 헤드리스 미검증 — 창모드 실행으로 땀방울 위치 미세조정 필요할 수 있음**(현재 (26,16)·scale 0.5는 추정값).

---

## 2026-06-07 — 스킬 어포던스 UX 폴리싱 (표지판/커서/끈끈이/글로우)

> 스킬 선택·설치 어포던스의 시각/체감 폴리싱 세션. 푯말→표지판 용어 통일, SIGN/DEVICE 커서·설치물 크기, 끈끈이 메커니즘(정지→감속) 재설계, 스킬 선택 캐릭터 글로우 가시성(두께·색·경계). **커밋/푸시는 별도 세션에서 일괄 처리 예정 — 이 세션은 기록만.** 워킹트리에는 이 세션 변경 + 별도 세션의 "세부 가이드 팝업"(`scripts/core/GuidePage.gd`·`assets/guide/`·`StageGuideData.gd`·`StageIntroCard` 등) 변경이 섞여 있음. 각 항목은 헤드리스 테스트로 검증(글로우는 비-headless 실렌더 캡처로 육안 검증).

### Fixed

#### F-16. '푯말' → '표지판' 용어 통일
- **증상**: 코드베이스 대부분은 이미 "표지판"을 쓰는데 플레이어 노출 가이드 카피([Strings.gd](../scripts/core/Strings.gd))만 "푯말"이라 불일치.
- **수정**: `guide.badge.sign` + S5/S6/S7 스킬 설명 4건을 표지판으로 교체. 활성 소스 주석(SkillAffordance/PlacementPreview/SignPlacement/SkillToolbar)·CursorKindByCategoryTest 주석도 정렬. docs/phases 등 역사 기록은 미변경(스코프).
- **검증**: `StringsTable`/`StageGuideDataRender` PASS(Strings.t() 파생 비교라 값 변경에 안전).

#### F-17. 표지판(①SIGN)·장치(④DEVICE) 커서 2배 + 아이콘 패널 맞춤
- **증상**: 스킬 선택 시 마우스 커서(표지판/점프대 모양)가 너무 작아 무엇을 어디 놓는지 분간 어려움. + 표지판 보드 안 아이콘이 패널 밖으로 넘침.
- **원인**: 커서 소스(보드/점프대 48px)에 `CURSOR_SCALE=0.5` → 24px(ICON 64px보다 작음). OS 커서는 뷰포트 스트레치 미적용이라 더 작게 보임. 아이콘 스케일 0.60이 패널(24×15px) 초과.
- **수정**([SkillToolbar.gd](../scripts/ui/SkillToolbar.gd)): `SIGN_DEVICE_CURSOR_SCALE=2.0`(보드 48→96px, 설치 표지판과 동일 크기). 보드 텍스처 패널 영역 픽셀 측정(크림 24×15, 중심 y −0.188) → `SkillSign.PANEL_ICON_FRAC=0.30`/`PANEL_ICON_CENTER_Y_FRAC=-0.188` 상수로 설치 표지판·커서 합성 양쪽 아이콘을 패널 안에 맞춤(상수 공유).
- **검증**: `CursorKindByCategory`/Sign 계열/Strings PASS + 합성 커서 PNG 렌더 육안 확인.

#### F-18. 표지판 설치물 2배 + 지면 매립 / 나뭇잎 점프대는 1배 유지
- **표지판**([SkillSign.gd](../scripts/world/SkillSign.gd)): `DISPLAY_SCALE=2.0`(셀의 2배) + `EMBED_DEPTH_FRAC=0.40`(기둥 밑동을 surface 안으로 0.4셀 매립 → "꽂힌" 모습; z_index=120이라 지형 위에 그려짐). 발동은 열(x) 기준이라 시각만 변하고 게임플레이 불변.
- **점프대**([LeafJumpPad.gd](../scripts/world/LeafJumpPad.gd)): 사용자 요청으로 **설치물은 1배 원복**(평패드라 자연스러움), 커서만 2배 유지(F-17).
- **검증**: SandMound/Basher/Cutter SignTest·SignGroundSnap·LeafJumpSign PASS.

#### F-19. 끈끈이(StickyHazard) = 감속 존 재설계 (정지+카운트다운 폐기)
- **증상(사용자 보고)**: 끈끈이 멈춤 시 머리 위 (블로커류) 아이콘이 떠서 거슬림 + 게이지바가 "감소 애니를 반복 재생"하는 느낌.
- **원인**: S8 끈끈이 셀 3개가 인접(`Sticky_4_9/5_9/6_9`) → 칸마다 3초 재고착 → 게이지 리셋 반복(단일 셀은 정상). 사용자 결정 = **HTML 원안대로 감속 존**으로 전환 + 게이지 제거.
- **수정**:
  - [Ant.gd](../scripts/ant/Ant.gd): 타이머(`_sticky_remaining/_sticky_max`)·게이지·sprite pause·머리 아이콘 폐기 → `enter_sticky`/`exit_sticky`/`is_slowed()` 오버랩 집합 + `STICKY_SPEED_MULT=0.35`. `effective_speed()`가 끈끈이 겹침 시 ×0.35.
  - [WalkerState](../scripts/ant/states/WalkerState.gd)/[CarryingState](../scripts/ant/states/CarryingState.gd): 정지 분기 제거(느리게 계속 보행).
  - [StickyHazard.gd](../scripts/world/hazards/StickyHazard.gd): body_entered/exited → enter/exit. `set_active(false)` 시 겹친 개미 감속 소스 정리(monitoring off가 body_exited 미발화) 안전장치.
  - [Sticky.tscn](../scenes/entities/hazards/Sticky.tscn): 무의미해진 `duration` 제거. [Strings.gd](../scripts/core/Strings.gd): S8 가이드 "3초 멈춰요"→"느려져요".
- **부수효과**: 감속이 정지보다 덜 가혹 → S8 약간 쉬워짐(여전히 cutter 필수·클리어 정상). is_stuck→is_slowed로 테스트 6종 마이그레이션 + AntStickyVisualTest 재작성.
- **검증**: 끈끈이 11종(AntStickyVisual/StickyStuckRelease/StickyCarryingPreserved/LeafJumpSign/BridgeOverWaterSticky/CutterOverHazard/WaterStickyOverlap/**CampaignS8Clear 5/5**/S8NoCutter/Strings/StageGuideData) + S1~S7 캠페인 클리어 회귀 전부 PASS.

#### F-20. 스킬 선택 캐릭터 외곽선 글로우 — 가시성(두께·색·경계) + 셰이더 버그
- **증상(사용자 보고, 순차)**: ① 외곽선이 너무 얇아 안 보임 → ② (수정 후) 글로우 자체가 아예 안 보임 → ③ 노란색이 파스텔 배경에 묻힘 → ④ 보라가 검은 캐릭터와 붙어 경계 안 보임.
- **원인/수정**(누적):
  1. **두께**: 개미 Sprite가 400×431 PNG를 scale 0.24로 축소 → 외곽선 텍셀 단위라 2텍셀≈0.48px(사실상 안 보임). [outline.gdshader](../assets/shaders/outline.gdshader) 8탭→**24방향 단일 링**(큰 폭에서도 솔리드) + [AffordanceGlowController](../scripts/world/AffordanceGlowController.gd)가 `화면 3.5px ÷ scale`로 환산한 텍셀 폭 전달.
  2. **★셰이더 컴파일 버그**: 내가 추가한 `const float TAU`가 **Godot 내장 상수 TAU와 충돌**(`Redefinition of TAU`) → 셰이더 미컴파일 → 글로우 전혀 안 그려짐. **헤드리스 테스트는 GPU 컴파일을 안 해 못 잡음.** 내장 TAU 사용으로 수정.
  3. **색**: 레몬(#F0D77B)이 파스텔 배경에 묻힘 → `ANT_GLOW_COLOR = Tokens.GRAPE_700`(보라).
  4. **경계**: 보라가 검은 캐릭터에 붙어 안 보임 → 셰이더 **2-밴드**화(`inner_color`/`inner_ratio` uniform): 캐릭터에 닿는 안쪽 띠=흰색, 바깥=보라. [Glow.apply](../scripts/ui/Glow.gd)에 inner 선택 인자(기본 비활성=하위호환). 개미: 흰띠 `inner_ratio=0.45`.
- **검증**: 글로우 테스트 4종(OutlineGlowSmoke/TapTargetGlowAnt/Surface/Integration) PASS + **Godot 비-headless 실렌더 캡처**로 흰띠+보라 2단 외곽선이 파스텔 배경에서 또렷함을 육안 확인.
- **교훈**: `--headless`는 셰이더 GPU 컴파일을 검증 못 함(리소스 로드/uniform만). 셰이더 변경은 비-headless 렌더 캡처로 검증할 것.

### 조정 가능한 튜닝 상수 (이 세션 산출)
- 커서 배율 `SkillToolbar.SIGN_DEVICE_CURSOR_SCALE`(2.0) · 표지판 매립 `SkillSign.EMBED_DEPTH_FRAC`(0.40) · 끈끈이 감속 `Ant.STICKY_SPEED_MULT`(0.35) · 글로우 두께 `AffordanceGlowController.ANT_GLOW_SCREEN_PX`(3.5) · 흰띠 비율 `ANT_GLOW_INNER_RATIO`(0.45) · 색 `ANT_GLOW_COLOR`(GRAPE_700).

---

## 2026-06-07

> 맵에디터로 S3~S9 레벨 재저작(지형·파라미터 조정) 후 9스테이지 전수 클리어 검증 + climber 천정 충돌 방향 버그 수정 + 현재 버전 웹빌드(itch.io zip) 산출 세션.

### Fixed

#### F-15. climber 천정 충돌 시 진행 반대 방향으로 낙하
- **증상(사용자 보고)**: 좁은 천장 아래에서 climber가 등반 중 머리가 천정에 막혀 떨어지면, **낙하 후 같은 방향으로 다시 벽으로 가 재등반** → 같은 자리에서 등반↔낙하 루프(S6 갱도 천장 등).
- **원인**: [ClimberState.gd](../scripts/ant/states/ClimberState.gd) `_update_climbing`의 `is_on_ceiling()` 분기가 `FallerState`로만 전이하고, `exit()`가 모든 종료 경로에서 `a.direction = _climb_direction`(등반 방향)을 복원 → 낙하·착지 후 등반 방향(=벽 쪽)으로 보행 재개.
- **수정**: 천정 분기에서 `_climb_direction = -_climb_direction`로 반전 후 전이. `exit()`가 반전된 값을 복원 → FallerState가 그 방향으로 표류·착지 → `return_to_walking`이 반대 방향 보행(벽에서 멀어짐). **천정 경로에만** 적용(mantle 완료·stall guard·blocker bounce 경로는 등반 방향 유지).
- **검증**: 신규 `ClimberCeilingReverseTest`(천정 캡 강제 → enter dir=1 → 천정 → FallerState dir=-1 → 착지 WalkerState dir=-1, 기절 없는 짧은 낙하) PASS. 회귀: `ClimberStall`/`ClimberBlockerOverlap`/`ClimberBlockerOverlapStall`(stall-guard 복원=비반전 확인)/`TraitCombined`/`CampaignS1Clear`/`CampaignS1NoClimber` 전부 PASS. `ClimberTraitTest`(mantle 0.07px 경계)는 stash로 되돌려도 동일 실패 = pristine HEAD 선재([[#K-4]]), 무관.

### Verified — S3~S9 맵에디터 재저작 클리어 전수 검증
사용자가 맵에디터로 S3~S9 지형·파라미터를 §3a~3j 커밋(`cf7ecff` 등) 대비 재조정(인벤토리 대폭 축소 등). 현재 워킹트리 기준 9스테이지 전수 클리어 확인:

| Stage | 파라미터(현행) | 검증 |
|---|---|---|
| S1 첫마실 | 5/hp5/90s · climber5+blocker1 · ★[.6,.8,1] | 자동 PASS 5/5 |
| S2 오르막 | 7/hp5/100s · climber6+floater1+blocker1 | 자동 PASS 5/5 |
| S3 사탕호수 | 5/hp5/110s · bridge2 (이중갭) | 수동 클리어(스샷) · 테스트 stale |
| S4 계단공사 | 5/hp5/110s · builder1 | 자동 PASS 5/5 |
| S5 막대과자탑 | **6**/hp5/120s · sand_mound1+floater1 | 자동 PASS 5/5 (마리수 5→6 교정) |
| S6 땅굴 | 5/hp5/120s · digger1+climber5 | 수동 클리어(digger+climber) · 테스트 stale |
| S7 옆파기 | 5/hp5/120s · basher2 | 자동 PASS 5/5 |
| S8 박하덤불 | 5/hp5/60s · cutter1+leaf_jump3 | 자동 PASS 5/5 |
| S9 종합과자점 | 6/hp5/150s · bridge1+basher1+blocker1+sand_mound1 | 수동 클리어(스샷) · 테스트 stale |

- **S5 마리수 교정**: `total_ants` 5→6. floater 분배자 1마리 영구 희생([[#F-3]]) → 배달 가능 4 < hp5였던 결함(saved 4/5 cap)을 6마리로 해소(`CampaignS5Clear` saved 5/5 검증).
- 현재 버전 **웹빌드 산출**: `build/web/CandyAnts-web.zip`(itch.io 업로드용, 49.5MB) — `python scripts/build_web.py`.

### Known issues (미수정)

#### K-10. S3/S6/S9 campaign clear 테스트 드라이버 stale → ✅ 해소(2026-06-07) — [[#K-5]] 연장
- **내용**: S3=옛 단일갭 col8 캐스팅(현 이중갭은 col6/col13 필요), S6=옛 floater-분배자 모델(현 digger+climber), S9=옛 builder 캐스팅(현 bridge+basher+blocker+sand_mound). 셋 다 레벨은 클리어 가능했고, 테스트 드라이버만 stale이었음.
- **해소**: 세 클리어 테스트 + 페어 음성 테스트를 현 지형/스킬에 맞춰 재작성. 전부 PASS(실측):
  - **S3** Clear 5/5 — 각 갭 가장자리(col6/col13)에서 bridge 즉시 건설.
  - **S6** Clear 5/5(digs1) — 전원 선반 강하 → col14(벽 인접) digger 1구멍(탈출 샤프트를 col13 벽에 정렬) → climber 복귀. NoDigger PASS(필수성). `CampaignS6NoFloaterTest` 삭제(현 S6에 floater 없음).
  - **S9** Clear 5/5(bridge+basher+sand_mound+blocker 4관문 발동 단언) — bridge 물갭 → basher로 좌 기둥 관통 → 내부 방서 sand_mound로 지붕 cap → blocker로 후속 개미 사탕 쪽 유도(lost 0 확보). NoBasher·신규 NoSandMound 음성 PASS(각 필수성, 물리 위치 도달 단언). `CampaignS9NoBuilderTest`→`NoSandMoundTest` 재타깃.

#### K-11. stage05/stage06 `time_limit_seconds` 명시 누락 → ✅ 해소(2026-06-07)
- 기능은 정상이었음(`StageData` 기본값 120s 폴백 — 인게임 TIME 카운터 정상 동작). 다른 스테이지(60~150s)와 일관되게 `time_limit_seconds = 120.0` 명시 추가.

## 2026-06-06

> digger 표지판화 + digger 자유낙하 기절 수정 + S6 "땅굴" 재설계 세션. 스킬을 "적용 방식(푯말/정착·이탈/무장·자동발동/장치 설치)" 축으로 분류하는 작업의 일환으로 digger를 표지판 스킬로 편입했고, 그 과정에서 발견한 "굴착 모션으로 떨어져 기절 미발동" 버그를 수정하며 의존 스테이지 S6를 재설계했다.

### Fixed

#### F-13. digger 발동 표지판(설치형) 편입 — sand_mound/basher/cutter와 통일 ([[#F-12]] 확장)
- **요청**: 지형 작업 스킬을 "타일에 푯말 설치 → 첫 도착 개미가 그 자리서 작동" 방식으로 통일. digger만 직접-탭(즉시 발동)으로 남아 있었음.
- **수정**: [SkillSign.gd](../scripts/world/SkillSign.gd) `SIGN_SKILLS`에 `"digger"` 추가(+ 발동 의미 주석). 클릭/드래그 양 경로가 `SkillSignScript.SIGN_SKILLS.has(id)` 단일 SoT([SkillToolbar.gd](../scripts/ui/SkillToolbar.gd) `_try_assign`/`try_assign_dragged`)를 타므로 자동으로 푯말 배치로 라우팅. digger 발동은 sand_mound와 대칭(제자리 발동 — 무장/지연 분기 없이 `DiggerSkill.apply`가 즉시 `WorkerState("digger")` 전이). 표지판 비주얼은 기존 `digger.png` 재사용.
- **검증**: `SkillToolbarCutterIntegration`/`SkillToolbarReentry`/`SkillToolbarPositionGuard` PASS. digger 발동 자체 회귀는 `DiggerVerticalTunnel`(흙 연속 굴착)·`DiggerFallThroughUpperAnt` PASS.

#### F-14. digger 자유낙하 = 굴착 모션 대신 FallerState(기절 대상) + S6 "땅굴" Design B 재설계
- **증상(사용자 보고)**: digger가 마지막 굴착 후 **굴착 모션(WorkerState) 그대로 떨어져** 기절 판정을 건너뜀(낙하 동작이 아니라 땅파기 동작으로 추락).
- **원인**: 구 digger는 off-floor 중에도 WorkerState를 유지(`DIGGER_OFF_FLOOR_LIMIT=180` void timeout, Phase18 v4 "Option A")해, 갱도가 빈 공간으로 뚫린 뒤의 자유낙하도 WorkerState에서 일어나 FallerState의 기절 거리 측정을 영영 거치지 않았다.
- **수정(코어)**: [WorkerState.gd](../scripts/ant/states/WorkerState.gd) `_update_digger` — off-floor 진입 첫 frame에 앵커(`_dig_fall_anchor_y`) 기록 후, 앵커 대비 `DIGGER_FREEFALL_CELLS(1.5칸)`를 넘게 떨어지면 갱도가 뚫린 자유낙하로 보고 `FallerState`로 이양(앵커를 넘겨 이미 떨어진 거리까지 포함해 기절 거리 정확 측정). **굴착 사이 1칸 인접 드롭(연속 터널)은 임계 미달 → WorkerState 유지**. 구 `DIGGER_OFF_FLOOR_LIMIT`/`_off_floor_frames` 폐기. [FallerState.gd](../scripts/ant/states/FallerState.gd)에 낙하 시작 y override(`_init(start_y_override := NAN)`) 추가(기본 NAN=enter 시점 y, 기존 모든 호출 경로 무영향).
- **S6 재설계 (Design B)**: 이 수정으로 S6 개척자의 "공동 7칸 자유낙하 자력 안전강하"(구 굴착낙하 면역)가 깨져, **"digger=흙 캡 천장 뚫기, 깊은 공동 강하는 모두(개척자 포함) floater 필요"**로 의미 변경. 지오메트리는 무변경(공동 air 유지) — 누구든 공동에 진입하면 7칸 자유낙하 → 기절(floater 없으면)이라 "느린 개척자에 후속이 올라타 생존"하던 Design A(공동 흙 채우기) 결함도 회피. **사용자 결정**: 수정 적용 + S6 재설계(A안).
- **검증**: `StunFall`/`CarryFallState`(FallerState 하위호환) PASS. `DiggerVerticalTunnel`(흙 연속 굴착=자유낙하 미발동) PASS. `DiggerFallThroughUpperAnt` 재작성(구 D11 180-timeout 박제 → 자유낙하 핸드오프: destroy 후 짧은 창 내 FallerState 진입) PASS — [[#K-4]] 선재실패 1건 해소. S6 3종: `CampaignS6Clear`(digger+분배자 floater → saved 4/4 lost 0)·`CampaignS6NoFloater`(digger만 → 공동 기절 saved 0 → 미클리어)·`CampaignS6NoDigger`(캡 못 뚫음 picks 0) PASS. 회귀: S1/S2/S4/S5/S7/S8/S9 Clear + bridge 4종 PASS([[#K-9]] S3 제외=무관 선재실패).

### Known issues

#### K-9. S3 "사탕 호수" 선재 회귀 — `BRIDGE_MAX_LENGTH`(5) < 갭(8칸) → 미클리어
- **내용**: `CampaignS3ClearTest`가 `stage_failed reason=no_more_ants saved=0`. S3 갭은 cols 9–16(8칸)인데 [WorkerState.gd](../scripts/ant/states/WorkerState.gd) `BRIDGE_MAX_LENGTH`/[PlacementPreview.gd](../scripts/world/PlacementPreview.gd) `BRIDGE_MAX`가 [[#F-9]] 인근(2026-06-04, 구 8→5)에서 5로 축소돼, 단일 다리가 갭을 못 건너 개미가 물에 빠진다. **세션 시작 git status상 S3 파일 미변경 = 커밋된 HEAD에서 이미 실패하는 선재 회귀**(본 세션 digger 작업과 무관 — bridge 코어 4종·FallerState 하위호환 전부 green으로 격리 확인).
- **왜 안 고쳤나**: digger 표지판/기절 수정 범위 밖. 수정은 설계 결정이 필요(① S3 갭을 ≤5칸으로 축소 ② S3 전용으로 bridge max 환원/스테이지별 캡 ③ 2단 다리 전제로 재저작·테스트 갱신).
- **고친다면**: 위 중 하나 선택 후 `stage03_layout.tres` 또는 bridge 캡 + `CampaignS3ClearTest`/`GameFlowTest` Scenario B 갱신.

## 2026-06-05

> iPad Mini 타겟 대응 + UI/UX 폴리싱 + 무장 스킬(armed) 메커니즘 확장 세션. 커밋엔 세션 전부터 작업 중이던
> 변경(스킬 라벨 리네임·StageSelect/SlotCard UI·맵 에디터 addon)도 사용자 지시로 함께 반영했다. 맵 에디터
> addon(`addons/candyants_level_tool/*`)은 별도 툴링 트랙이라 본 로그(버그/폴리싱 전용)엔 상세 기록하지 않는다.

### Fixed

#### F-4. iPad Mini(3:2) 해상도 대응
- **요청**: 게임을 iPad Mini 미니 해상도 기준으로 동작하게. **사용자 결정**: iPad Mini 6세대(2266×1488 = 1.5228), 가로(landscape), keep(레터박스).
- **제약**: 카메라 zoom=1·limit 없음 → base 해상도가 곧 "보이는 월드 범위". 세로를 iPad 논리값 744로 잡으면 지표 아래 ~6셀(낙하·기절 개미, y≈768)이 화면에서 잘림.
- **수정**: [project.godot](../project.godot) `[display]` — `viewport 1644×1080`(세로 1080 유지로 낙하 가시성 보존, 과한 가로 여백만 3:2로 축소) + `window override 1133×744`(데스크톱 에뮬레이트) + `stretch canvas_items/keep` + `handheld/orientation=landscape`.
- **검증**: `GameFlowTest` 3시나리오 PASS. HUD/메뉴는 앵커 기반이라 base 너비 변화에 자동 적응(무영향).

#### F-5. 타이틀 인트로 영상 레터박스
- **증상**: 16:9(1280×720) 인트로 영상이 3:2 프레임에서 `expand=true`로 세로 늘어나 왜곡.
- **수정**: [TitleScene.tscn](../scenes/ui/TitleScene.tscn) — 영상 뒤 검은 `Letterbox` ColorRect(풀스크린) + `VideoPlayer`를 가로 꽉(1644)·세로 924.75(16:9 유지) 중앙 박스로(위아래 ~77.6px 검은 바).
- **검증**: `TitleSceneInputTest` PASS.

#### F-6. 스킬 버튼 확대 + 자동 간격 + 세로 중앙 정렬 + 라벨 폰트
- **요청**: 스킬 버튼 크게(누적 ×1.32), 커진 만큼 버튼 사이 간격 자동 조정, 하단 바 세로 중앙 정렬, 스킬 이름 폰트 확대.
- **핵심 버그**: [SkillSlot.gd](../scripts/ui/atoms/SkillSlot.gd)가 `_ready`에서 `custom_minimum_size = _SIZE`(88×88)로 `.tscn` 크기를 매번 덮어써, `.tscn`만 키우면 버튼은 88 그대로이고 자식(MainBG/Icon/라벨)만 116 기준으로 커져 **버튼 밖으로 삐져나와 겹침**.
- **수정**: `SkillSlot.gd` `_SIZE` 88→116.16 + `size_flags_vertical = SHRINK_CENTER`; [SkillSlot.tscn](../scenes/ui/atoms/SkillSlot.tscn) 자식 offset ×1.32 + `KoLabel` 폰트 18; [SkillToolbar.gd](../scripts/ui/SkillToolbar.gd) 자동 간격(`separation = round(슬롯폭 × 14/88)`); [SkillToolbar.tscn](../scenes/ui/SkillToolbar.tscn) HBox를 panel 전체로 확장(세로 중앙 정렬).
- **검증**: `SkillToolbarPositionGuard`/`SkillToolbarReentry`/`AtomShowcase` PASS + 실측(슬롯 116.16, 간격 18, y=11 중앙).

#### F-7. 방출 속도 스테퍼 제거 → 배속 버튼 신설
- **요청**: 개미 수가 적어 방출 속도 조절은 불필요, 대신 진행 속도 배속 버튼이 낫다.
- **수정**: [HUD.tscn](../scenes/ui/HUD.tscn) `ReleaseRateStepper` 인스턴스 제거 + `SpeedBtn` 추가. [SpeedBtn.gd](../scripts/ui/SpeedBtn.gd) **신규** — 기존 `speed_toggle` 액션(키보드 F)+버튼 클릭으로 1×→2×→3× 순환, `Engine.time_scale` **상대 배수**(진입 시 base 캡처 → 헤드리스 테스트 time_scale=8 비간섭, `_exit_tree`에서 base 복원해 메뉴 가속 방지).
- **검증**: `HudCounterRegression`/`GameActionContract` PASS, `GameFlowTest`의 time_scale=8 보존(전 시나리오 PASS).

#### F-8. 터치 스킬 부여 — 머리 터치 미인식
- **증상**: 터치 조작으로 스킬 부여 시, 특히 개미 **머리** 터치가 인식 안 됨.
- **원인**: 개미 충돌 원점은 발(y=0)인데 스프라이트(보이는 캐릭터, 높이 ~103px)는 중심이 -43.5라 캐릭터 전체가 원점 위. [SkillToolbar.gd](../scripts/ui/SkillToolbar.gd) `_find_closest_ant`가 **원점 기준 반경 48**로 판정 → 캐릭터 아래 절반만 덮어 머리(원점에서 ~58~95px)가 빠짐. (좌표 변환은 정상 — 레터박스 무관.)
- **수정**: [Ant.gd](../scripts/ant/Ant.gd) `tap_target_position()`(스프라이트 시각 중심) 추가 → 툴바가 그 기준으로 거리 측정 + `CLICK_RADIUS` 48→64.
- **검증**: probe(머리/몸통/발 모두 인식, 한참 빗나간 지점 미인식) + 툴바 회귀 PASS.

#### F-9. basher / cutter 무장(armed) 패턴 전환
- **요청**: basher·cutter도 (bridge/builder처럼) 개미에 부착하면 벽을 만날 때까지 들고 있다가 작동 후 해제. (basher=전방 5칸 굴착, cutter=연결 덩쿨 일괄 절단.)
- **수정**: [Ant.gd](../scripts/ant/Ant.gd) `basher_armed`/`cutter_armed` + `try_bash_armed_wall()`/`try_cut_armed_wall()` + `basher_wall_ahead()`(전방 earth)/`cutter_plant_ahead()`(전방 plant) + `forward_cell_open()`; [WalkerState.gd](../scripts/ant/states/WalkerState.gd) 매 frame 훅(벽 flip보다 먼저). 전방이 **열림→무장 후 보행**, 흙/식물 벽 도달 시 자동 작동. 이미 벽에서 부여하면(전방 막힘) **기존처럼 즉시 처리**(대상이면 작업, 비대상이면 자연 abort=cross-kind 침범 차단) → 기존 테스트 전부 보존. [WorkerState.gd](../scripts/ant/states/WorkerState.gd) `BASHER_MAX_CELLS` 12→5. [BasherSkill](../scripts/skills/BasherSkill.gd)/[CutterSkill](../scripts/skills/CutterSkill.gd)/[BridgeSkill](../scripts/skills/BridgeSkill.gd)/[BuilderSkill](../scripts/skills/BuilderSkill.gd) 4종 armed 상호 배타. [Ant.tscn](../scenes/entities/Ant.tscn) `BasherBadge`/`CutterBadge` 무장 표식 배지.
- **검증**: Basher 단위 4 + Cutter 단위 5 + `CampaignS7/S8/S9` Clear/음성 + `ArmedSkillMutexTest`(4-way로 확장) + armed probe(열린 공간 적용→무장→벽 자동 작동, 비대상 미침범) PASS.

#### F-10. 메인 메뉴 설정·크레딧 버튼 숨김
- **요청**: 메인 메뉴에서 설정·크레딧 버튼 숨기기.
- **수정**: [MainMenu.tscn](../scenes/ui/MainMenu.tscn) `SettingsBtn`/`CreditsBtn` `visible=false`(노드·시그널 연결은 보존 — 재노출은 `visible=true`만). VBox가 빈 공간 자동 접음.
- **검증**: `MainMenuNav`(`.pressed.emit()`은 신호 직접 발화라 숨김 무관)/`MainMenuContinueGuard` PASS.

#### F-11. 스킬 한글 라벨 명확화 (세션 전 작업분, 번들)
- [Strings.gd](../scripts/core/Strings.gd) 스킬 라벨을 더 직관적으로 리네임(등반→**벽 오르기**, 굴착→**벽 부수기**, 절단→**식물 자르기**, 계단→경사면, 차단→길 막기, 다리→다리만들기, sand_mound→막대세우기, floater→낙하산 분배). 라벨을 직접 단언하던 테스트 2개([StringsTableTest](../tests/StringsTableTest.gd) climber, [SkillToolbarCutterIntegrationTest](../tests/SkillToolbarCutterIntegrationTest.gd) cutter)를 새 라벨로 동기화(stale 해소).
- **검증**: 두 테스트 PASS.

#### F-12. basher/cutter/sand_mound 발동 표지판(설치형) — "빠른 탭" 난이도 완화
- **요청**: basher·cutter·sand_mound는 타일 앞에서 (움직이는 개미를) 빠르게 탭해야 발동돼 난이도가 과함. 타일에 발동 표지판을 설치하고, 그 타일에 **처음 도착한 개미**가 자동 발동하도록.
- **수정**: [SkillSign.gd](../scripts/world/SkillSign.gd) **신규** — 표지판 노드(설치·시각·도착 감지·발동·소비). `SIGN_SKILLS=[sand_mound, basher, cutter]`, 표지판 열(column)에 처음 도착한 적격 개미(`can_apply` 통과)에 `skill.apply` 호출 후 `queue_free`. basher/cutter는 [[#F-9]] armed 분기([BasherSkill](../scripts/skills/BasherSkill.gd)/[CutterSkill](../scripts/skills/CutterSkill.gd).apply: 전방 열림→armed, 벽 직면→즉시 작동)를 **그대로 재사용** → 흙벽/식물벽 "앞 셀"에 설치하면 도착 개미가 armed 후 벽에서 자동 작동. sand_mound는 표지판 자리(빈 바닥)에서 그대로 사다리 건설. [SkillToolbar.gd](../scripts/ui/SkillToolbar.gd) sign-skill이면 개미 탭(`_find_closest_ant`) 대신 `_place_sign`으로 분기(클릭·드롭 공통) — 현재 씬 트리에서 Terrain 탐색, 빈(비점유) 셀에만 설치, 설치 시 인벤토리 차감(`can_apply`는 발동 시점 재검사).
- **검증**: 신규 헤드리스 `SandMound/Basher/CutterSignTest`(설치→발동→벽 제거/사다리 건설→표지판 소비) 전부 PASS + 기존 탭/드롭(`SkillDropAssignTest`/`PausedAssignTest`)·각 스킬 통합(`BasherTunnelThroughWall`/`BasherEdgeStop`/`BasherOnPlantRejected`/`CutterCutThroughVine`/`CutterEdgeStop`/`CutterOnEarthRejected`/`SandMound*`) 회귀 없음. 커밋 `2d07b31`.
- **⚠ 프로토타입**: 정식 Phase·adversarial-review 미적용("먼저 빠른 프로토타입으로 손맛 확인" 합의). 후속 [[#K-8]].

### Known issues (미수정 — 효율/스코프 사유로 보류)

#### K-8. 표지판(F-12) 프로토타입 잔여 항목
- **내용**: ① 도착 판정이 `같은 x열 + is_on_floor` 단순식 → 같은 열 다층 지형에서 오발동 가능. ② [PlacementPreview.gd](../scripts/world/PlacementPreview.gd)는 아직 ant 기반 ghost(sand_mound)라 표지판 위치 미리보기와 불일치(dev 씬엔 미배선이라 현재 충돌 없음, Stage01 적용 시 필요). ③ 표지판 회수/취소 불가(설치 시 인벤토리 차감, 미발동 시 낭비). ④ 시각은 폴+아이콘 임시 표식(전용 스프라이트 미정). ⑤ 메인 Stage01~03 미적용(dev 씬에서만 검증).
- **왜 안 고쳤나**: "먼저 빠른 프로토타입으로 손맛 확인" 후 정식 Phase화 합의(스코프 분리).
- **고친다면**: `/harness` 정식 Phase로 ①~⑤ + adversarial-review 일괄 처리.

#### K-7. release_rate 키보드 단축키가 UI 없이 잔존
- **내용**: F-7로 방출속도 스테퍼 UI는 제거했으나, 입력 액션 `release_rate_up`/`release_rate_down`(`[`/`]`)은 `GameActionContractTest`의 canonical InputMap 계약에 묶여 있어 **바인딩은 유지**. UI 없이 스폰 주기를 조용히 바꾼다(무해, 스포너는 release_rate를 내부 스폰 주기로 계속 사용).
- **왜 안 고쳤나**: 입력 액션 제거는 계약 fixture(`GameActionContractTest` + `project.godot` InputMap)까지 동반 수정 필요 → 스코프 확대.
- **고친다면**: release_rate 조절을 완전히 폐기하기로 확정 시 액션 2개 + 계약 fixture + `StageRunner._on_action`의 RELEASE_RATE 분기 + `ReleaseRateStepper` 위젯/테스트 일괄 정리.

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
  - **남은 선재 실패**: `ClimberTraitTest`(mantle 0.07px 경계). (`DiggerFallThroughUpperAnt`는 2026-06-06 [[#F-14]]에서 재작성·해소.) F-3와 무관, 별도 트랙에서 점검.
- **왜 안 고쳤나**: F-2 요청 범위 밖의 선재 결함. 메모리 핸드오프 노트에도 "pristine HEAD 선재 실패 4건(ClimberTrait mantle / DiggerFallThroughUpperAnt / DistributorSettle / FloaterTrait)"으로 이미 기록돼 있음.
- **고친다면**: 별도 버그 수정 작업으로 ① `FloaterTraitTest` 데드라인/측정 윈도우 재조정(또는 `TraitCombinedTest`로 커버되니 폐기 검토) ② `DistributorSettleTest`는 marker.x 대비 허용오차를 넓히거나, 정착 트리거 시 x를 marker.x로 스냅(`SettledState.enter`에서 `_settle_pos.x = marker.x`)할지 설계 결정 필요. **남은 선재 실패**(`ClimberTraitTest` mantle 0.07px 경계)도 같은 트랙에서 함께 점검. (`DiggerFallThroughUpperAnt`는 [[#F-14]]에서 해소.)
