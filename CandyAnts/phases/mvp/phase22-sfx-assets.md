---
name: sfx-assets
duration_estimate: 5400
verify: python scripts/run_test.py --import && python scripts/run_test.py tests/SfxReceiverTest.tscn --audio-driver Dummy
large_change_ok: false
sot: docs/ADR.md
sot_aux: [docs/ARCHITECTURE.md, scripts/core/SfxPlayer.gd, phases/mvp/phase21-sfx-receiver.md, tests/SfxReceiverTest.gd]
---

# Phase 22: sfx-assets (post-MVP)

## 목표
Phase 21의 절차 합성 톤(레트로 삑삑이)을 **Kenney CC0 실제 효과음 파일**로 교체한다. `SfxPlayer`를 절차 합성 → 파일 로드 방식으로 전환. emit 14곳·`EventBus.sfx_request` 계약·14 id는 불변. **SFX만** (BGM은 추후 별도 phase).

## 배경 (현재 상태)
- Phase 21에서 `SfxPlayer`(autoload)가 `SFX_SPECS`(id→톤 스펙)로 `AudioStreamWAV`를 절차 합성해 재생 중 ([SfxPlayer.gd](../../scripts/core/SfxPlayer.gd)). 사용자: "옛날 게임 같다" → 실제 에셋 교체.
- ADR-011이 "절차 합성 → 파일 교체 시 SFX_SPECS만 바꾸면 되는 인터페이스 유지"를 명시 → 본 phase가 그 교체.
- `assets/audio/`에 Kenney CC0 4팩(367 파일, 팩별 폴더) 압축 해제 완료:
  - `kenney_ui_audio/` (51 wav), `kenney_interface_sounds/Audio/` (100 ogg),
  - `kenney_impact_sounds/Audio/` (130 ogg), `kenney_music_jingles/Audio/*jingles/` (86 ogg).
- 원본 367 파일을 전부 커밋하면 리포 비대 → **14개만 선별·복사**하고 원본 팩은 `.gitignore`로 제외.

## 변경 대상
1. **`assets/audio/sfx/<id>.ogg`** (신규, 14개) — 367 팩에서 선별한 파일을 id 이름으로 복사·정규화. git 커밋 대상.
2. **`scripts/core/SfxPlayer.gd`** — `SFX_SPECS`를 톤 스펙 Dictionary → **파일 경로 매핑**(id→`res://assets/audio/sfx/<id>.ogg`)으로 교체. `_ready`의 `_build_stream(...)` → `load(path)`. 절차 합성 헬퍼(`_build_stream`, MIX_RATE 등) 제거. 로드 실패(null) 시 `push_warning` + 해당 id skip (graceful). `_on_sfx_request`/pool/bus 폴백/`last_played`/미매핑 guard는 불변.
3. **`tests/SfxReceiverTest.gd`** — 검사 (c) "절차 합성 무결성" → "리소스 로드 무결성"으로 의미 교체: 각 id의 `_streams[id]`가 non-null `AudioStream`(WAV 또는 OggVorbis)인지. (a)(b)(d)(e)(f)는 불변. repo-도출 커버리지·글로벌 prefix 가드 유지.
4. **`.gitignore`** — 원본 Kenney 팩 폴더 4종 제외 (`assets/audio/kenney_*/`). 선별본 `assets/audio/sfx/*.ogg`(+CREDITS)는 추적. **`.import`는 커밋하지 않음** — 본 프로젝트는 루트 `.gitignore`에 `*.import` 규칙이 있어 추적 `.import` 0개가 관례(전부 `--import`로 재생성). fresh clone은 커밋된 `.ogg`만으로 `run_test.py --import`가 `.import` 사이드카 + `.godot/imported` 변환 캐시를 함께 재생성 → 자족. (실측 검증됨: ogg만 남기고 `.import`·`imported` 전부 제거 후 `--import`+`SfxReceiverTest` PASS.)
5. **`assets/audio/sfx/CREDITS.txt`** (신규) — Kenney CC0 출처·팩명·id별 원본 파일 기록 (라이선스 표기는 의무 아니나 출처 추적용).
6. **`docs/ADR.md`** — `ADR-012: SFX 절차합성 → Kenney CC0 에셋 교체` 추가 (ADR-011 supersede 명시).
7. **트래커 원자적 갱신** (plan review Round 1 HIGH 대응 — 이미 완료): `phases/mvp/notion-phase-ids.json` 22=sfx-assets(page_id null→sync skip), input-touch/advanced를 23/24로 시프트. `phases/mvp/README.md` phase 표 동기화. `metadata.json` post_mvp_phase_range [21,24].

## 14 id → 원본 파일 매핑 (초기안 — 게임에서 듣고 조정)
| id | 원본 파일 | 팩 | 성격 |
|----|----------|-----|------|
| candy_pick | pluck_001.ogg | interface | 밝은 픽업 |
| candy_depleted | confirmation_002.ogg | interface | 완료 |
| candy_lost | error_004.ogg | interface | 상실/부정 |
| ant_stun | impactPunch_medium_000.ogg | impact | 둔탁 타격 |
| ant_save | confirmation_003.ogg | interface | 성공 |
| water_splash | drop_001.ogg | interface | 물방울 근사 |
| sticky_glue | impactSoft_heavy_000.ogg | impact | 묵직/끈적 |
| stage_cleared | 8-Bit jingles/jingles_NES07.ogg | jingles | 승리 팡파레 |
| stage_failed | 8-Bit jingles/jingles_NES09.ogg | jingles | 실패 |
| dialog_open | open_001.ogg | interface | 열림 |
| dialog_stats_pop | tick_001.ogg | interface | 짧은 틱 |
| dialog_btn_press | click_001.ogg | interface | 클릭 |
| star_fill | select_002.ogg | interface | 밝은 반짝 |
| locked | error_002.ogg | interface | 거부 |

> 매핑은 파일명 기반 추정 — 헤드리스로 소리를 들을 수 없으므로 jingles(승리/실패 NES 번호) 등은 사용자가 게임에서 듣고 조정. SFX_SPECS 한 줄 수정으로 교체 가능.

## 검증 방법
**import 부트스트랩 선행** (신규 ogg 에셋 → load() 캐시 재생성; plan review Round 1 HIGH 대응):
`python scripts/run_test.py --import && python scripts/run_test.py tests/SfxReceiverTest.tscn --audio-driver Dummy`
1. (글로벌 prefix 가드) `scripts/` 스캔 raw id 중 콜론 0건.
2. (repo-도출 커버리지) 추출 raw id 전부 `SFX_SPECS` 키에 존재.
3. (로드 무결성) 14 id 전부 non-null `AudioStream`으로 load (파일 누락/오타 = FAIL).
4. (동적 재생) 각 raw id emit 후 `last_played` 일치, `play()` 무에러 (dummy 드라이버).
5. (회귀) StageSelect.gd `locked` clean id 유지.
6. (graceful) 미등록 id skip.
7. CampaignS1ClearTest 등 코어 회귀 통과 (실제 게임플레이 sfx 라우팅).

### clean-clone 자족성 (plan review Round 1·Round 2 HIGH 대응)
원본 367 팩(`assets/audio/kenney_*/`)을 gitignore해도 빌드가 깨지지 않아야 한다. **stale `.godot/imported` 캐시로 인한 false green을 차단**하려면 source 팩 부재 + import 캐시 무효화를 동시에 시뮬레이션해야 한다. impl 시 다음을 명시 확인:
- `git ls-files assets/audio/sfx/`로 14개 `.ogg`(+CREDITS)가 **실제 커밋**되는지 (`.import`는 관례상 미추적).
- **진짜 fresh-clone 시뮬레이션** (Round 2 HIGH 대응 — 실측 완료):
  1. source 팩 4폴더를 임시 이동(`assets/audio/kenney_* → 프로젝트 밖 bak`).
  2. **import 산출물 전부 제거**: `.godot/imported/` + `.godot/global_script_class_cache.cfg` + `assets/audio/sfx/*.import` — 커밋되는 `.ogg`만 남겨 진짜 새 체크아웃 상태 재현.
  3. `python scripts/run_test.py --import` 로 `.import`+`.godot/imported`를 **ogg에서 새로** 재생성.
  4. `SfxReceiverTest --audio-driver Dummy` 통과 확인 (ogg만으로 자족 입증).
  5. source 팩 원복(재생성된 `.import`/`imported`는 유지 — 정상 상태).
- SfxPlayer는 어떤 source 팩 경로도 직접 참조하지 않음 — `SFX_SPECS`는 오직 `res://assets/audio/sfx/<id>.ogg`만 가리킨다.

## 비범위 (defer)
- BGM/스테이지 음악 (별도 phase — OpenGameArt CC0 루프 음원).
- 볼륨 설정 UI / 음소거 토글.
- 소리 자체의 미세 튜닝(어느 jingle이 더 어울리는지 등)은 사용자 청취 후 SFX_SPECS 수정으로 처리 — 본 phase는 "파일 로드 전환 + 합리적 초기 매핑"까지.
