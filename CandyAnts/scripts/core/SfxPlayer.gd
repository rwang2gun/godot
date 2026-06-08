extends Node
## Phase 21 — SFX receiver. / Phase 22 — Kenney CC0 에셋으로 교체.
## EventBus.sfx_request(id) 를 받아 실제 효과음 파일(Kenney CC0, assets/audio/sfx/)을 재생한다.
## 모든 id는 clean id(콜론/prefix 없음)여야 하며 런타임 정규화는 하지 않는다
## — emit이 clean id를 보내는 것이 계약 (plan review P21 Round 2 HIGH).
## 절차 합성(P21)에서 파일 로드(P22)로 전환 — ADR-012. 인터페이스(emit·계약·테스트)는 불변.

const POOL_SIZE: int = 8
const SFX_BUS: StringName = &"SFX"
const SFX_DIR: String = "res://assets/audio/sfx"

## clean id → 효과음 리소스 경로. 게임 청취 후 이 한 줄만 바꿔 교체 가능.
## 출처/원본 매핑은 assets/audio/sfx/CREDITS.txt 참조.
const SFX_SPECS: Dictionary = {
	&"candy_pick": SFX_DIR + "/candy_pick.ogg",
	&"candy_depleted": SFX_DIR + "/candy_depleted.ogg",
	&"candy_lost": SFX_DIR + "/candy_lost.ogg",
	&"ant_stun": SFX_DIR + "/ant_stun.ogg",
	&"ant_save": SFX_DIR + "/ant_save.ogg",
	&"water_splash": SFX_DIR + "/water_splash.ogg",
	&"sticky_glue": SFX_DIR + "/sticky_glue.ogg",
	&"stage_cleared": SFX_DIR + "/stage_cleared.ogg",
	&"stage_failed": SFX_DIR + "/stage_failed.ogg",
	&"dialog_open": SFX_DIR + "/dialog_open.ogg",
	&"dialog_stats_pop": SFX_DIR + "/dialog_stats_pop.ogg",
	&"dialog_btn_press": SFX_DIR + "/dialog_btn_press.ogg",
	&"star_fill": SFX_DIR + "/star_fill.ogg",
	&"locked": SFX_DIR + "/locked.ogg",
	# 스킬 흐름(선택 → 부여/배치 → 발동) — Kenney CC0 전용 음원(2026-06-08). 출처는 CREDITS.txt 참조.
	&"skill_select": SFX_DIR + "/skill_select.ogg",
	&"skill_assign": SFX_DIR + "/skill_assign.ogg",
	&"skill_activate": SFX_DIR + "/skill_activate.ogg",
	# 반복 재생음(풋스텝/공사) — 다수 개미가 동시에 보내므로 아래 THROTTLE_MS로 뭉치고 VOLUME_DB로 작게.
	# Kenney CC0 전용 음원: footstep=발소리(grass), skill_build=판자 놓기, skill_dig=채굴음.
	&"footstep": SFX_DIR + "/footstep.ogg",
	&"footstep_sticky": SFX_DIR + "/footstep_sticky.ogg",  # 끈끈이 감속 중 먹먹한 발소리(carpet)
	&"skill_build": SFX_DIR + "/skill_build.ogg",
	&"skill_dig": SFX_DIR + "/skill_dig.ogg",
	# 착지/낙하산 — Kenney CC0 전용 음원: ant_land=부드러운 착지, parachute=펼침 swoosh.
	&"ant_land": SFX_DIR + "/ant_land.ogg",
	&"parachute": SFX_DIR + "/parachute.ogg",
}

# 반복 재생 id의 글로벌 coalesce 간격(ms) — 다수 개미가 동시에 쏟아내도 잔잔히 뭉치게 한다(per-id).
# 여기 없는 id는 쓰로틀 없음(1회성 이벤트음은 즉시 재생). per-ant tick(공사 ~0.2s)보다 짧게 잡아
# 단일 개미 리듬은 보존하고 다중 개미 겹침만 합친다.
const THROTTLE_MS: Dictionary = {
	&"footstep": 70,
	&"footstep_sticky": 70,
	&"skill_build": 60,
	&"skill_dig": 60,
	&"ant_land": 60,     # 다수 개미 동시 착지 coalesce
	&"parachute": 150,   # floater 개미 잦은 재진입(작은 단 낙하) 스팸 방지
}
# 반복음 볼륨(dB). 여기 없는 id는 0 dB(기본). 풋스텝은 "작게", 공사·착지·낙하산은 약간만 낮춰 또렷하게.
const VOLUME_DB: Dictionary = {
	&"footstep": -7.0,
	&"footstep_sticky": -7.0,
	&"skill_build": -6.0,
	&"skill_dig": -6.0,
	&"ant_land": -8.0,
	&"parachute": -8.0,
}

var _streams: Dictionary = {}          # clean id → AudioStream (로드 캐시)
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_play_ms: Dictionary = {}     # 쓰로틀 대상 id → 마지막 재생 ticks_msec(첫 요청은 항상 통과).

# 테스트 가시성용 (런타임 동작엔 영향 없음).
var last_played: StringName = &""


func _ready() -> void:
	_build_pool()
	for id in SFX_SPECS:
		var path: String = SFX_SPECS[id]
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("[SfxPlayer] sfx 로드 실패 (id=%s path=%s) — skip" % [id, path])
			continue
		_streams[id] = stream
	EventBus.sfx_request.connect(_on_sfx_request)


func _build_pool() -> void:
	# SFX 버스가 없으면(레이아웃 미로드 등) Master로 폴백 — 헤드리스/안전.
	var bus: StringName = SFX_BUS if AudioServer.get_bus_index(SFX_BUS) >= 0 else &"Master"
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_pool.append(p)


func _on_sfx_request(id: StringName) -> void:
	# 런타임 정규화 없음. id를 그대로 조회. 미매핑/로드실패는 경고 후 skip (크래시 금지).
	if not _streams.has(id):
		push_warning("[SfxPlayer] unmapped or unloaded sfx id: %s" % id)
		return
	# 반복음만 글로벌 쓰로틀 — 간격 미달 요청은 조용히 skip(다수 개미 합치기). 그 외 1회성 id엔 무영향.
	if THROTTLE_MS.has(id):
		var now: int = Time.get_ticks_msec()
		if now - int(_last_play_ms.get(id, -100000)) < int(THROTTLE_MS[id]):
			return
		_last_play_ms[id] = now
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[id]
	# 풀 플레이어 재사용 — id별 볼륨을 매 재생 시 명시 설정(없으면 0 dB; 이전 재생 볼륨 잔존 방지).
	player.volume_db = float(VOLUME_DB.get(id, 0.0))
	player.play()
	last_played = id
