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
}

var _streams: Dictionary = {}          # clean id → AudioStream (로드 캐시)
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0

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
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[id]
	player.play()
	last_played = id
