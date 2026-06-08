# 2026-06-08 — 게임플레이 SFX 확장 (스킬·이동·공사·낙하·끈끈이)

## 한 일
- 비어 있던 게임플레이 피드백 효과음을 대거 배선. 신규 clean id **9종** 추가:
  - 스킬 흐름: `skill_select`(선택/arm) · `skill_assign`(부여·배치 확정) · `skill_activate`(설치형 발동) + 재고0 슬롯 클릭 `locked` 거부음
  - 이동: `footstep`(보폭 12px 기반) + `footstep_sticky`(끈끈이 감속 전용)
  - 공사: `skill_build`(다리/계단/사다리) · `skill_dig`(basher/digger/cutter) — WorkerState 타일 단위
  - 낙하: `ant_land`(1.5칸↑ 비기절 착지) · `parachute`(floater slow-fall 진입)
- 모든 신규 id를 **받아둔 Kenney CC0 팩의 목적별 전용 음원**으로 배치(초기 placeholder 재사용 → 교체).
- 곁다리: 어제 스트링 대수정으로 깨져 있던 `SkillToolbarCutterIntegrationTest` 라벨 단언 fix(식물→덩굴 자르기).

## 결정 / 변경
- **풋스텝은 시간이 아니라 이동거리(12px) 기반** — 느려지면 보폭 간격이 자동으로 벌어져 속도에 비례. 끈끈이(×0.35)에선 133ms→381ms로 ~2.9배 벌어지고 음색도 carpet(먹먹)으로 분기 → "질척" 이중 표현. 운반/끈끈이 전이로 상태가 바뀌어도 누적은 Ant에 남겨 연속성 유지.
- **반복음 공통 처리** — SfxPlayer에 `THROTTLE_MS`(per-id 글로벌 coalesce) + `VOLUME_DB`(per-id) 맵 도입. 다수 개미 동시 발화(풋스텝/공사/착지)를 잔잔한 patter로 뭉치고 볼륨을 작게. 단일 개미 cadence는 throttle(<70ms 미만 간격 없음)에 안 걸려 완전 비례.
- **에셋: placeholder 재사용 → 전용 음원 교체** — 처음에 in-repo ogg를 재사용했으나, 받아둔 팩에 footstep_grass/impactMining/impactPlank/maximize 등 목적에 맞는 음원이 있어 교체. P22 방식대로 `assets/audio/sfx/<id>.ogg`로 선별 복사(.import는 `*.import` gitignore라 빌드 재생성).
- **리터럴 emit 강제(삼항 금지)** — 끈끈이 분기를 `emit(&"a" if … else &"b")`로 짰더니 SfxReceiverTest repo-스캐너(`emit(&"리터럴")`만 인식)가 footstep/footstep_sticky를 통째로 못 잡아 emit 커버리지에서 누락(테스트는 PASS했지만 검증 구멍). `if/else` 리터럴 2개로 교정 → 23 id 전부 스캔.

## 산출물
- 코드: `scripts/core/SfxPlayer.gd`(id 9종 + 쓰로틀/볼륨 맵), `scripts/ant/Ant.gd`(footstep_tick 보폭 헬퍼 + 끈끈이 분기), `scripts/ant/states/{WalkerState,CarryingState,WorkerState,FallerState}.gd`, `scripts/ui/SkillToolbar.gd`, `scripts/world/{SkillSign,LeafJumpPad}.gd`
- 에셋: `assets/audio/sfx/`에 전용 ogg 9개(skill_select/assign/activate, footstep, footstep_sticky, skill_build, skill_dig, ant_land, parachute) + CREDITS.txt 출처 갱신
- 테스트: `tests/test_LeafJumpPad.gd`(TDD 가드 스텁) 신규, `tests/SkillToolbarCutterIntegrationTest.gd` 라벨 fix
- 커밋(메인): `0074ab5`(feat 8종 배선) → `53843f3`(placeholder→전용음 교체) → `c32cc04`(cutter test fix) → `4c7a5fd`(끈끈이 발소리)

## 다음 진입점
- **실제 게임 청취 후 튜닝**: 볼륨(`SfxPlayer.VOLUME_DB`)·쓰로틀(`THROTTLE_MS`)·음색(`SFX_SPECS` 경로) 3곳만 만지면 됨.
- 후속 폴리시 후보(미구현): 지형 타일별 발소리(팩에 footstep_wood/concrete/snow/grass 표면별 5변종 보유) · 한 id 다변종 랜덤재생(또각 단조로움 완화) · 끈끈이 음색 대안.

## 미해결
- **정식 Phase 절차 미수행** — 세션 중 직접 요청 작업이라 `execute.py`/`/codex:adversarial-review`/Notion 동기화는 돌리지 않음. 정식 phase로 승격할지 여부는 사용자 판단 대기.
- 발소리는 현재 surface 무관 grass 1종 고정(끈끈이만 분기). 표면별/변종 다양화는 후속.
