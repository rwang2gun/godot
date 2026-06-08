---
name: sfx-receiver
duration_estimate: 7200
verify: python scripts/run_test.py tests/SfxReceiverTest.tscn --audio-driver Dummy
large_change_ok: false
sot: docs/ARCHITECTURE.md
sot_aux: [docs/ADR.md, scripts/core/EventBus.gd, tests/SfxRequestEmitTest.gd]
---

# Phase 21: sfx-receiver (post-MVP)

## 목표
`EventBus.sfx_request(id)` 신호를 받아 **코드로 절차 합성한 톤**을 실제 재생하는 `SfxPlayer` autoload + SFX 오디오 버스를 구축한다. emit은 Phase 12/20에서 14 unique id(22 call site)에 이미 깔려 있으므로 본 phase는 receiver만 신설한다 (외부 오디오 에셋 0개).

## 배경 (현재 상태)
- `EventBus.sfx_request(id: StringName)` 신호 정의됨 ([EventBus.gd:19](../../scripts/core/EventBus.gd)) — 주석 "receiver는 phase 21 산출".
- **14 unique id × 22 emit call site** (호출 site와 id 개수는 다름 — plan review Round 1 HIGH 교정):
  - `candy_lost`×4 (AdriftState.gd:44, DeadState.gd:23, FloaterSkill.gd:41, LostState.gd:13)
  - `dialog_btn_press`×4 (StageDialog.gd:162, StageIntroCard.gd:326/333/487)
  - `candy_pick`×2 (Candy.gd:43, DroppedCandy.gd:26), `dialog_open`×2 (StageDialog.gd:112, StageIntroCard.gd:121)
  - 단발: `candy_depleted` `ant_stun` `ant_save` `water_splash` `sticky_glue` `stage_cleared` `stage_failed` `dialog_stats_pop` `star_fill` `sfx:locked`
- `assets/audio/`는 `.gitkeep`만 (실제 파일 없음) → 절차 합성으로 해결.
- `sfx:locked`만 `sfx:` prefix 불일치 (StageSelect.gd:69) → emit 쪽을 `locked`로 통일.
- 기존 `tests/SfxRequestEmitTest`는 **최초 8 id만** 정적 검증 → 본 phase에서 repo-도출 커버리지로 대체/확장한다.

## 변경 대상
1. **`scripts/core/SfxPlayer.gd`** (신규 autoload, `scripts/core/` 규칙 준수)
   - `_ready()`에서 `EventBus.sfx_request.connect(_on_sfx_request)`.
   - `const SFX_SPECS: Dictionary` — **clean id**(StringName, prefix·콜론 없음) → 톤 스펙(waveform/freq/duration/envelope/volume_db, 옵션 noise). 14 id 전부.
   - **런타임 정규화 없음** (Round 2 HIGH 대응): `_on_sfx_request(id)`는 받은 id를 그대로 `SFX_SPECS`에서 조회. 키 변형/`sfx:` 스트립 금지 — emit이 clean id를 보내는 것이 계약.
   - 시작 시 각 id의 `AudioStreamWAV`를 절차 합성·캐시 (`_build_stream(spec)` 헬퍼: 16-bit PCM, ADSR 엔벨로프, sine/square/noise).
   - `AudioStreamPlayer` 풀(8개) round-robin 재생, `bus = &"SFX"`.
   - 미매핑 id → `push_warning` 후 graceful skip (크래시 금지).
   - 헤드리스/dummy 오디오 드라이버에서도 `play()` 호출이 에러 없이 통과해야 함.
2. **`project.godot`** — `[autoload]`에 `SfxPlayer="*res://scripts/core/SfxPlayer.gd"` 추가 (EventBus 의존 → EventBus 뒤에 배치).
3. **`default_bus_layout.tres`** (신규, 프로젝트 루트) — `Master` + `SFX`(send=Master) 2버스.
4. **`scripts/ui/StageSelect.gd:69`** — `EventBus.sfx_request.emit(&"sfx:locked")` → `&"locked"` (prefix 통일).
5. **`tests/SfxReceiverTest.gd` + `.tscn`** (신규) — **repo-도출 커버리지, 정규화 없음** (plan review Round 1 HIGH + Round 2 HIGH 대응):
   - **설계 결정**: SfxPlayer는 런타임 정규화를 **하지 않는다**. 모든 emit은 clean id(prefix·콜론 없음)여야 하고 `SFX_SPECS`도 clean id로 키잉. `sfx:locked`는 emit 쪽(StageSelect.gd:69)에서 `locked`로 고쳐 제거 → 정규화 마스킹 위험 원천 차단.
   - 하드코딩 id 목록 금지. `scripts/` 전체를 스캔해 모든 `sfx_request.emit(&"...")` literal에서 **raw id 집합을 동적 추출**.
   - (a) **글로벌 prefix 가드**: 추출된 raw id 중 `:`(콜론) 또는 `sfx:` prefix를 포함한 것이 1건이라도 있으면 FAIL — StageSelect.gd 한정이 아니라 전 스크립트 대상. 정규화 단계 없음.
   - (b) **직접 커버리지**: 추출된 **모든 raw id**가 `SfxPlayer.SFX_SPECS`에 그대로 존재하는지 단언 (누락 = FAIL). → 새 emit site/오타/prefix 추가 시 자동 감지.
   - (c) **재생**: 추출된 각 raw id를 그대로 `EventBus.sfx_request.emit(id)` 후 풀에서 play() 무에러 (raw id로 재생 — 테스트가 정규화로 보정하지 않음).
6. **`docs/ADR.md`** — `ADR-011: 절차적 SFX 합성 (외부 에셋 0)` 추가.

## 사운드 성격 (절차 합성 파라미터 가이드)
| id | 성격 | 방향 |
|----|------|------|
| candy_pick | 밝은 짧은 픽업음 | 상승 sine |
| candy_depleted | 사탕 소진 완료음 | 중음 2-step |
| candy_lost | 상실 | 하강 sine |
| ant_stun | 둔탁한 타격 | 저음 + noise |
| ant_save | 성공 | 상승 2음 |
| water_splash | 물 튀김 | noise 버스트 |
| sticky_glue | 끈끈이 | 저음 묵직 |
| stage_cleared | 클리어 | 상승 아르페지오 3음 |
| stage_failed | 실패 | 하강 3음 |
| dialog_open | 다이얼로그 | 부드러운 팝 |
| dialog_stats_pop | 스탯 등장 | 짧은 틱 |
| dialog_btn_press | 버튼 | 클릭 |
| star_fill | 별 채움 | 반짝 상승 |
| locked | 잠금 거부 | 저음 부저 |

## 검증 방법
헤드리스 (dummy 오디오 드라이버 명시 — plan review Round 1 MEDIUM 대응):
`python scripts/run_test.py tests/SfxReceiverTest.tscn --audio-driver Dummy`
1. (글로벌 prefix 가드) `scripts/` 스캔 추출 raw id 중 `:`/`sfx:` 포함 0건 (전 스크립트 대상, 정규화 없음).
2. (repo-도출 직접 커버리지) 추출한 **모든 raw id**가 `SFX_SPECS`에 그대로 존재 (누락 시 FAIL). 하드코딩 목록 미사용.
3. (합성 무결성) 14 spec 전부 non-null `AudioStreamWAV` 빌드 성공 (null/빈 data = FAIL). dummy 드라이버 하에서 검증.
4. (동적 재생) 각 raw id를 그대로 `EventBus.sfx_request.emit(id)` 후 SfxPlayer 풀 중 하나가 stream 할당 + `play()` 무에러.
5. (회귀) `StageSelect.gd`에 `sfx:locked` literal 부재 + `locked` literal 존재.
6. (graceful) 미등록 id emit 시 크래시 없이 `push_warning`만 (테스트가 임의 id emit 후 생존 확인).
7. 기존 `tests/SfxRequestEmitTest.tscn` 회귀 통과 (emit 위치 불변).

## 비범위 (defer)
- BGM/스테이지 음악 (Phase 22+ 후보).
- 볼륨 설정 UI / 음소거 토글 (SaveData 연동) — 후속.
- 실제 녹음 에셋 교체 (절차 합성 → 파일 교체는 SFX_SPECS만 바꾸면 되는 인터페이스 유지).
