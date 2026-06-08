---
name: bgm-assets
duration_estimate: 5400
verify: python scripts/run_test.py --import && python scripts/run_test.py tests/BgmReceiverTest.tscn --audio-driver Dummy && python scripts/run_test.py tests/BgmSceneFlowTest.tscn --audio-driver Dummy
large_change_ok: false
sot: docs/ADR.md
sot_aux: [docs/ARCHITECTURE.md, scripts/core/SfxPlayer.gd, phases/mvp/phase23-bgm-receiver.md, phases/mvp/phase22-sfx-assets.md]
---

# Phase 24: bgm-assets (post-MVP)

## 목표
Phase 23이 인터페이스만 깐(런타임 무음) BGM 시스템에 **실제 CC0 루프 음원**을 배치한다. `BgmPlayer.BGM_SPECS`가 가리키는 `assets/audio/bgm/menu.ogg`·`gameplay.ogg`를 실제 루프 트랙으로 채우고, `BgmReceiverTest`에 **로드 무결성** 검사를 추가해 자족성을 보장한다. **인터페이스(BgmPlayer·`bgm_request` 계약·track id·버스·SceneFlow 배선)는 불변** — SFX 21→22(ADR-011→012)와 동형.

## 배경 (현재 상태)
- Phase 23에서 `BgmPlayer`(autoload) + `BGM` 버스 + `EventBus.bgm_request`/`bgm_stop` + `SceneFlow` 배선(menu/gameplay)이 완성됐으나, `BGM_SPECS` 경로의 ogg가 부재 → 런타임 `_streams` 비어 무음(의도). 로직은 합성 스트림 주입으로 검증됨.
- 사용자: CC0 루프 음원을 직접 소싱·배치하기로 정렬(2026-06-08). 분위기 = 경쾌·아기자기 캔디/개미 테마.
- SFX 선례(ADR-012): 실제 파일은 `load()`로 로드, `*.ogg`만 커밋(`.import`는 `*.import` gitignore 관례로 미추적), fresh clone은 `run_test.py --import`가 `.import`+`.godot/imported` 재생성으로 자족.

## 변경 대상
1. **`assets/audio/bgm/menu.ogg`** (신규) — 메뉴(TITLE/MAIN_MENU/STAGE_SELECT) 루프. CC0(OpenGameArt/Kenney 등), 이음새 없는 루프(loop-seamless) 우선. 경쾌·아기자기.
2. **`assets/audio/bgm/gameplay.ogg`** (신규) — 스테이지 플레이 루프. 메뉴와 구분되는 분위기(집중/리듬감), 역시 CC0 루프.
3. **`assets/audio/bgm/*.import`** — Godot가 ogg import 시 생성. **루프 활성화**: import 프리셋에서 `loop=true`(또는 BgmPlayer가 스트림 로드 후 `stream.loop = true` 강제 — Phase 23 설계대로 코드에서 보장하면 import 설정 무관하게 루프). `.import`는 `*.import` gitignore 관례로 미추적 — `.ogg`만 커밋.
4. **`scripts/core/BgmPlayer.gd`** — 코드 변경 **불필요**(BGM_SPECS 경로 이미 `bgm/menu.ogg`·`bgm/gameplay.ogg` 가리킴). 다만 Phase 23 시점 `load()` null→graceful였던 경로가 이제 실제 stream 로드 → `_streams` 채워짐. (코드 손 안 댐을 검증으로 확인.)
5. **`tests/BgmReceiverTest.gd`** — 검사 (c) **역전/교체**(보강 아님): Phase 23의 (c)는 "무음 경계" — `_streams.is_empty()` + `ResourceLoader.exists(menu/gameplay.ogg)==false`를 단언했다. 실제 ogg가 배치되면 이 단언은 **반드시 FAIL**하므로, Phase 24에서 (c)를 "실제 로드 무결성"으로 **교체**한다: `BgmPlayer._streams.size() == BGM_SPECS.size()`, 각 track stream non-null `AudioStream` + `get_length() > 0`. (SfxReceiverTest 21→22의 (c) "합성 무결성"→"로드 무결성" 진화와 동형 — 파일 부재 단언을 파일 존재 단언으로 뒤집음.) (d) 로직 검사는 이제 **주입 없이 실제 로드된 스트림으로** 동작(idempotent/전환/graceful/stop/rapid-fade 유지).
6. **`tests/BgmSceneFlowTest.gd`** — **무음 경계 단언 역전**(plan review R3 MEDIUM): Phase 23의 SceneFlowTest는 빈 `_streams`를 전제로 (11) `current_track` 미갱신 + `play_generation==0`을 단언했다. 에셋이 배치되면 boot "menu" emit이 **실제 재생**되므로 이 단언은 FAIL → Phase 24에서 **asset-present 단언으로 교체**: boot "menu" → `current_track=="menu"` + `play_generation` 증가(실제 playback); `load_stage(published)` → `current_track=="gameplay"` + 전환 시 `play_generation` 추가 증가. emit 순서/매핑/구독순서 검사(10·12)는 유지. **verify 명령에 BgmSceneFlowTest 포함**(실제 유저가 받는 asset-present 구성에서 SceneFlow boot/전이 배선 커버). BgmReceiverTest 21→22 (c) 역전과 동일 패턴.
7. **`assets/audio/bgm/CREDITS.txt`** (신규) — 출처·라이선스(CC0)·원본 URL·track별 파일 기록 (sfx/CREDITS.txt 형식).
8. **`docs/ADR.md`** — ADR-013에 "Phase 24에서 CC0 루프 배치로 무음→가청 완성" 1줄 보강(또는 ADR-013-A). SFX ADR-012 에셋 관리 관례 참조.
9. **`.gitignore`** — 필요 시 BGM 원본/대용량 소스 폴더 제외(선별본 `assets/audio/bgm/*.ogg`+CREDITS는 추적). SFX `kenney_*` 패턴과 동일 정책.

## 검증 방법
**import 부트스트랩 선행**(신규 ogg → load() 캐시 재생성):
`python scripts/run_test.py --import && python scripts/run_test.py tests/BgmReceiverTest.tscn --audio-driver Dummy && python scripts/run_test.py tests/BgmSceneFlowTest.tscn --audio-driver Dummy`
1. (로드 무결성) menu/gameplay 2 track 전부 non-null `AudioStream`으로 load + `get_length() > 0` (파일 누락/오타/import 미완 = FAIL).
2. (루프) 로드된 스트림이 BgmPlayer 재생 시 loop on(코드 강제 또는 import 플래그).
3. Phase 23의 BgmReceiverTest 검사(커버리지/prefix/idempotent/전환/graceful/stop/rapid-fade) 유지 PASS, (c)만 무음경계→로드무결성 역전.
4. (SceneFlow asset-present) BgmSceneFlowTest: boot "menu" 실제 재생(`current_track=="menu"` + `play_generation` 증가), `load_stage(published)`→"gameplay" 전환. emit 순서/매핑/구독순서 유지.
5. (회귀) SceneFlow 테스트군 + SfxReceiverTest PASS.

### clean-clone 자족성 (SFX 22 선례 — fresh-clone 시뮬레이션)
- `git ls-files assets/audio/bgm/`로 `menu.ogg`/`gameplay.ogg`(+CREDITS) **실제 커밋** 확인(`.import` 미추적).
- fresh-clone 시뮬레이션: `assets/audio/bgm/*.import` + `.godot/imported`(해당 항목) 제거 → `run_test.py --import`로 ogg에서 재생성 → `BgmReceiverTest` PASS(ogg만으로 자족 입증).
- BgmPlayer는 `res://assets/audio/bgm/<track>.ogg`만 참조 — 외부 소스 팩 경로 직접 참조 0.

### 게임 청취 확인 (수동)
- 게임 실행 → 타이틀/메뉴/스테이지셀렉트에서 menu 곡 루프, 스테이지 진입 시 gameplay로 짧은 페이드 전환, 메뉴 복귀 시 menu로 페이드. 루프 이음새·볼륨 밸런스(SFX 대비) 청취 후 필요 시 `BGM_SPECS`/버스 `volume_db` 한 줄 조정.

## 비범위 (defer)
- 볼륨/음소거 UI + SaveData 영속화.
- 스테이지별 개별 BGM, 결과 화면 덕킹.
- 루프 음원 미세 튜닝(어느 트랙이 더 어울리는지)은 사용자 청취 후 `BGM_SPECS` 교체로 처리 — 본 phase는 "실제 CC0 루프 배치 + 로드 무결성 + 자족성"까지.
