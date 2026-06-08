---
name: bgm-receiver
duration_estimate: 7200
verify: python scripts/run_test.py tests/BgmReceiverTest.tscn --audio-driver Dummy && python scripts/run_test.py tests/BgmSceneFlowTest.tscn --audio-driver Dummy
large_change_ok: false
sot: docs/ADR.md
sot_aux: [docs/ARCHITECTURE.md, scripts/core/SfxPlayer.gd, scripts/core/SceneFlow.gd, scripts/core/EventBus.gd, tests/SfxReceiverTest.gd]
---

# Phase 23: bgm-receiver (post-MVP)

## 목표
BGM 재생 **시스템과 배선**을 외부 에셋 의존 0으로 깐다. SFX(Phase 21/22)의 `SfxPlayer` 패턴을 미러링한 `BgmPlayer` autoload + `BGM` 오디오 버스 + `EventBus.bgm_request`/`bgm_stop` 시그널 + `SceneFlow` 화면 전이 배선을 만들고, 헤드리스 테스트로 루프·페이드·idempotent·graceful 로직을 검증한다. **실제 CC0 루프 음원은 Phase 24**(이 phase는 인터페이스만 — 런타임 `_streams`는 비어 있어 무음, 로직은 합성 스트림 주입으로 검증).

## 배경 (현재 상태)
- SFX는 `SfxPlayer`(autoload) + `EventBus.sfx_request(id)` + `SFX` 버스(Master 폴백) + repo-도출 `SfxReceiverTest`로 완비 ([SfxPlayer.gd](../../scripts/core/SfxPlayer.gd), Phase 21/22, ADR-011/012).
- BGM은 ADR-011/012·Phase22 비범위에서 "별도 phase, OpenGameArt CC0 루프 음원"으로 명시적 defer.
- 화면 전이는 `SceneFlow`(Main.tscn, autoload 아님)가 단일 상태머신으로 소유 ([SceneFlow.gd](../../scripts/core/SceneFlow.gd)): `ScreenState{TITLE, MAIN_MENU, STAGE_SELECT, STAGE}`. 모든 전이가 `_swap_screen`(메뉴 3종) / `load_stage`(STAGE) 두 메서드를 거침 → BGM 컨텍스트는 자연히 **menu(TITLE/MAIN_MENU/STAGE_SELECT) vs gameplay(STAGE)** 2종.
- 사용자 정렬(2026-06-08): (1) 음원은 사용자가 CC0 루프 직접 소싱·배치(Phase 24), (2) menu + gameplay 2종 화면별 다른 곡, (3) **재생 시스템만** — 볼륨/음소거 UI·SaveData는 defer, (4) 전환은 짧은 페이드.

## 설계 결정 (SfxPlayer 패턴 미러링 + BGM 고유)
SFX와 동일: autoload receiver, `EventBus` 시그널 구독, `*_SPECS` Dictionary가 SoT(track id → 리소스 경로), 버스 미존재 시 Master 폴백, 미매핑 graceful skip, repo-도출 테스트. **BGM 고유 추가**:
- **루프 재생** — SFX는 one-shot, BGM은 무한 루프 (스트림 loop 플래그).
- **짧은 크로스페이드** — 전환 시 ~0.4s. 2-player 토글(A/B) 동시 fade out/in.
- **per-player tween 소유권 + 취소** (plan review R1 MEDIUM-2): 각 player는 자신의 활성 tween 참조(`_tweens: Array[Tween]`, 2개)를 들고, 새 fade 시작 전 해당 player의 이전 tween을 **반드시 `kill()`**한다(없으면 rapid menu→gameplay→menu 시 stale tween이 새 tween과 볼륨 싸움 / 잘못된 player를 stop). fade-out 완료 콜백은 **자신이 여전히 비활성 player일 때만** stop — 콜백 시점에 다시 활성이 됐으면(빠른 재진입) stop하지 않음(`_active` 재확인). 활성/볼륨의 최종 상태는 항상 `_active`/`_current_track`이 결정(tween은 보간만).
- **idempotent 재진입** — 같은 track을 다시 request하면 **재시작하지 않음**(예: title→main_menu→stage_select 모두 "menu" → 무중단). 활성 track == 요청 track이고 재생 중이면 no-op.
- **`current_track`/`play_generation` 테스트 seam** — request 시 `current_track`을 **동기적으로** 갱신(페이드 완료 대기 없이 결정성 확보). 실제 (재)시작 때만 `play_generation` 증가 → idempotent 검증용. fade 완료 후 최종 상태(활성 player만 playing, stale player stop)는 별도 await-기반 테스트로 검증.

## 변경 대상
1. **`assets/audio/default_bus_layout.tres`** — `bus/2`에 `BGM` 버스 추가 (`send = &"Master"`, 기존 SFX `bus/1` 형식 그대로). Master/SFX/BGM 3-버스.
2. **`scripts/core/EventBus.gd`** — `signal bgm_request(track: StringName)` + `signal bgm_stop()` 추가 (sfx_request 줄 근처, 주석으로 phase 23 표기).
3. **`scripts/core/BgmPlayer.gd`** (신규, `scripts/core/`) — autoload receiver:
   - `const BGM_BUS := &"BGM"`, `const BGM_DIR := "res://assets/audio/bgm"`.
   - `const BGM_SPECS: Dictionary` — track id → 리소스 경로. **Phase 23 시점엔 파일 미존재** → `&"menu": BGM_DIR + "/menu.ogg"`, `&"gameplay": BGM_DIR + "/gameplay.ogg"` (Phase 24에서 실제 ogg 배치). `_ready`의 `load()`는 null 반환 → graceful skip(`_streams` 비어 있음), **런타임 무음**(의도된 상태, 시스템/배선만 검증).
   - 2-player 크로스페이드: `_players: Array[AudioStreamPlayer]`(2개, BGM 버스/Master 폴백), `_active: int`, `_current_track: StringName`, `play_generation: int`(테스트 seam).
   - `_on_bgm_request(track)`: 같은 track + 재생중이면 no-op(idempotent); 미매핑이면 `push_warning` skip(graceful); 그 외 `current_track=track` 동기 갱신 → 새 player에 stream(loop on) 세팅·play·fade in + 이전 player fade out → `play_generation += 1`.
   - `_on_bgm_stop()`: 활성 fade out 후 stop, `current_track=&""`.
   - 페이드는 `create_tween()`으로 `volume_db` 보간(~0.4s). 헤드리스/dummy에서도 tween은 SceneTree에서 동작하나 `current_track`/`play_generation`은 동기라 테스트는 페이드 대기 불요.
4. **`project.godot`** — `[autoload]`에 `BgmPlayer="*res://scripts/core/BgmPlayer.gd"` 추가. **EventBus 다음**(EventBus 구독 의존), SfxPlayer 인접. SceneFlow(Main.tscn `_ready`)는 모든 autoload `_ready` 이후 실행되므로 emit 전 BgmPlayer 구독 보장.
5. **`scripts/core/SceneFlow.gd`** — 화면 전이에서 BGM emit:
   - `_swap_screen(new_node, new_state)` 끝(`current_screen = new_state` 이후): `EventBus.bgm_request.emit(&"menu")` (TITLE/MAIN_MENU/STAGE_SELECT 전부 메뉴 — idempotent가 메뉴 내 이동을 무중단 처리).
   - `load_stage(stage_id)`에서 `current_screen = ScreenState.STAGE` 직후: `EventBus.bgm_request.emit(&"gameplay")`.
   - 부트(`_boot → go_to_title → _swap_screen`)에서 자연히 "menu" 시작. 결과 오버레이(StageDialog)는 STAGE 유지(freeze)이므로 gameplay 곡 지속(의도).
6. **`tests/BgmReceiverTest.gd` + `tests/BgmReceiverTest.tscn`** (신규) — `SfxReceiverTest` 미러:
   - (a) **repo-도출 커버리지**: `scripts/` 스캔으로 `bgm_request.emit(&"...")` track id 추출(주석 줄 제외) → 전부 `BgmPlayer.BGM_SPECS` 키에 존재. (현재 emit: menu, gameplay.)
   - (b) **prefix 가드**: 추출 track id에 콜론 0건.
   - (c) **무음 경계 단언**(plan review R1 HIGH-2 — 합성 주입 *이전*에): 이 phase는 "에셋 부재 → 런타임 무음"을 의도하므로, 그 전제를 **테스트가 직접 증명**한다. (1) `BgmPlayer._streams.is_empty()` 참 — 어떤 track도 실제 로드 안 됨; (2) 각 `BGM_SPECS` 경로(`menu.ogg`/`gameplay.ogg`)가 `ResourceLoader.exists() == false` (실수로 커밋/로컬 배치된 에셋·경로 오타·stale import를 잡음). 둘 중 하나라도 깨지면 FAIL → Phase 24가 가정하는 "23은 실제 스트림 0" 경계가 보장됨. (Phase 24에서 이 (c)가 "실제 로드 무결성"으로 의미 교체 — SfxReceiverTest 21→22 진화와 동형.)
   - (d) **로직 검증(합성 스트림 주입)**: (c) 통과 후 `AudioStreamWAV` 합성 스트림을 `BgmPlayer._streams[&"menu"]`/`[&"gameplay"]`에 주입 → `bgm_request.emit(&"menu")` 후 `current_track==&"menu"` + 활성 player `playing` + 활성 stream loop 플래그 on. **idempotent**: 동일 track 재emit 시 `play_generation` 불변. **전환**: `&"gameplay"` emit 시 `current_track` 갱신 + `play_generation` 증가. **graceful**: `&"__no_such__"` emit 시 `current_track` 불변·크래시 없음. **bgm_stop**: emit 후 `current_track==&""`.
   - (e) **rapid re-entry / fade 최종상태**(plan review R1 MEDIUM-2): `menu→gameplay→menu`를 연속 emit(각 사이 1프레임 이내) 후 **fade 시간(>0.4s)보다 길게 await** → 활성 player만 `playing`, 비활성 player는 `stop`(또는 무음), `_active`/`_current_track`이 마지막 요청(menu)과 일치, stale tween 잔존 0(`_tweens[비활성]` killed/finished). overlapping tween이 잘못된 player를 죽이거나 볼륨 싸움을 일으키지 않음을 입증.
7. **`tests/BgmSceneFlowTest.gd` + `tests/BgmSceneFlowTest.tscn`** (신규, plan review R1 MEDIUM-1) — repo 스캔이 못 잡는 "실제 전이가 옳은 지점에서/구독 이후 emit되는지"를 검증. **무음 경계 양립**(plan review R2 HIGH): 이 테스트는 `Main.tscn`을 **실제(빈 `_streams`) 상태로** 구동하므로 playback이 일어나지 않는다 → `play_generation`/idempotent 단언은 여기 두지 **않고**(그건 BgmReceiverTest (d)/(e)가 주입 스트림으로 소유), 본 테스트는 **emit 순서·track 매핑·구독 순서**만 본다(스트림 시딩 없음). `EventBus.bgm_request`를 별도 listener로 구독해 `(track, 순서)` 시퀀스를 수집:
   - (1) **boot emit 이전 구독 보장**: BgmPlayer(autoload)가 `bgm_request`에 이미 connect돼 있음을 확인(autoload `_ready` < Main `_ready` 순서 입증) — boot 첫 "menu" emit 유실 0.
   - (2) **무음 graceful**: 빈 `_streams`로 boot/menu emit 시 `BgmPlayer.current_track`은 미매핑 graceful로 갱신 안 됨 + `play_generation == 0`(playback 0) + 크래시 0 — Phase 23 무음 경계가 실전이에서도 성립함을 입증.
   - (3) **실전이 매핑/순서**: 수집된 시퀀스가 `go_to_title`/`go_to_main_menu`/`go_to_stage_select` → "menu", `load_stage(published)` → "gameplay"와 일치(전이마다 emit 1회, 올바른 track). 헤드리스 STAGE 로드는 published 스테이지 1개 사용(인트로 카드 헤드리스 자동 스킵 경로 활용).
   - (4) **메뉴 내 이동 emit 수**: title→main_menu→stage_select는 "menu" emit 3회 발생(BgmPlayer가 idempotent로 무중단 처리하는지는 BgmReceiverTest (e)가 주입 스트림으로 검증 — 여기선 emit이 빠짐없이 발생하는지만 확인).
8. **`docs/ADR.md`** — `ADR-013: BGM 재생 시스템 (BgmPlayer + 화면 전이 배선)` 추가. SfxPlayer 패턴 미러링·2종 컨텍스트·페이드(tween 소유권/취소)·idempotent·무음 경계·에셋은 Phase 24 defer 명시. ADR-011/012 관련 표기.
9. **트래커 원자적 갱신**(plan review R1 HIGH-1 — **이 plan에서 이미 처리**, status.json 변경과 동시 정합): `phases/mvp/notion-phase-ids.json` 23=bgm-receiver/24=bgm-assets(page_id null, sync skip)·input-touch/advanced를 25/26으로 시프트(page_id 보존) + `_renumber_history` 1줄, `phases/mvp/README.md` phase 표(23/24 bgm, 25/26 input), `metadata.json` post_mvp_phase_range [21,24]→[21,26] + notes 갱신. (impl 단계에서 추가 변경 없음 — drift 0 상태로 진입.)

## 검증 방법
`python scripts/run_test.py tests/BgmReceiverTest.tscn --audio-driver Dummy && python scripts/run_test.py tests/BgmSceneFlowTest.tscn --audio-driver Dummy`

**BgmReceiverTest** (로직/계약):
1. (repo-도출 커버리지) 스캔된 emit track id(menu/gameplay) 전부 `BGM_SPECS` 키에 존재.
2. (prefix 가드) 추출 track id 콜론 0건.
3. (무음 경계) `_streams` 비어 있음 + `menu.ogg`/`gameplay.ogg` 둘 다 `ResourceLoader.exists()==false` — 실수 배치/오타/stale import 차단(HIGH-2).
4. (재생/루프) 합성 스트림 주입 후 emit → `current_track` 일치 + 활성 player `playing` + 루프 on.
5. (idempotent) 동일 track 재emit 시 `play_generation` 불변(무중단).
6. (전환) 다른 track emit 시 `current_track` 갱신 + `play_generation` 증가.
7. (graceful) 미매핑 track skip, 크래시 0, `current_track` 불변.
8. (stop) `bgm_stop` emit 후 `current_track==&""`.
9. (rapid fade) menu→gameplay→menu 연속 emit 후 fade(>0.4s) await → 활성 player만 playing, stale tween 0, 최종 `current_track==menu`(MEDIUM-2).

**BgmSceneFlowTest** (실배선, 빈 `_streams` = 무음 상태로 구동 — emit 순서/매핑/구독만, playback 단언 없음):
10. boot "menu" emit 이전 BgmPlayer 구독 보장(autoload `_ready` < Main `_ready`).
11. 무음 graceful: 빈 `_streams` boot에서 `current_track` 미갱신 + `play_generation==0` + 크래시 0(무음 경계가 실전이에서도 성립).
12. 실전이 매핑/순서: 메뉴 3종 전이 → "menu"(각 1회), `load_stage(published)` → "gameplay". (idempotent/`play_generation` 단언은 BgmReceiverTest 5·9가 주입 스트림으로 소유.)

**회귀**:
13. 기존 SceneFlow 테스트군(`SceneFlowEmitContractTest`/`SceneFlowSwapNoStaleEmitTest`/`SceneFlowScreenStateTest`) + `SfxReceiverTest` PASS — BGM emit 추가가 화면 전이/SFX 회귀 0.

## 비범위 (defer)
- 실제 CC0 루프 음원 소싱·배치 → **Phase 24 (bgm-assets)**.
- 볼륨/음소거 설정 UI + SaveData 영속화.
- 스테이지별 개별 BGM(현재는 gameplay 단일 곡) — 향후 BGM_SPECS 확장 + SceneFlow에서 stage_id 기반 track 선택으로 가능.
- 결과 화면(승리/실패)에서 BGM 덕킹/전환.
- (트래커 매핑은 본 plan에서 이미 원자적으로 처리 — README/metadata/notion-ids 23·24 bgm, 25·26 input. impl 단계 추가 변경 없음.)
