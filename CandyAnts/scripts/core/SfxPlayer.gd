extends Node
## Phase 21 — SFX receiver.
## EventBus.sfx_request(id) 를 받아 코드로 절차 합성한 톤을 재생한다.
## 외부 오디오 에셋 0개 (ADR-011). 모든 id는 clean id(콜론/prefix 없음)여야 하며
## 런타임 정규화는 하지 않는다 — emit이 clean id를 보내는 것이 계약 (plan review Round 2 HIGH).

const MIX_RATE: int = 22050
const POOL_SIZE: int = 8
const SFX_BUS: StringName = &"SFX"

## clean id → 절차 합성 스펙.
## segments: 순차 재생 톤 [{f=주파수Hz, d=길이s, w="sine"|"square"|"noise"}, ...]
## vol_db: 전체 볼륨(dB).
const SFX_SPECS: Dictionary = {
	&"candy_pick": {
		"segments": [{"f": 784.0, "d": 0.04, "w": "sine"}, {"f": 1047.0, "d": 0.06, "w": "sine"}],
		"vol_db": -8.0,
	},
	&"candy_depleted": {
		"segments": [{"f": 523.0, "d": 0.08, "w": "sine"}, {"f": 392.0, "d": 0.10, "w": "sine"}],
		"vol_db": -8.0,
	},
	&"candy_lost": {
		"segments": [{"f": 440.0, "d": 0.07, "w": "sine"}, {"f": 330.0, "d": 0.09, "w": "sine"}, {"f": 220.0, "d": 0.12, "w": "sine"}],
		"vol_db": -7.0,
	},
	&"ant_stun": {
		"segments": [{"f": 90.0, "d": 0.06, "w": "square"}, {"f": 0.0, "d": 0.10, "w": "noise"}],
		"vol_db": -9.0,
	},
	&"ant_save": {
		"segments": [{"f": 659.0, "d": 0.06, "w": "sine"}, {"f": 988.0, "d": 0.10, "w": "sine"}],
		"vol_db": -6.0,
	},
	&"water_splash": {
		"segments": [{"f": 0.0, "d": 0.18, "w": "noise"}],
		"vol_db": -10.0,
	},
	&"sticky_glue": {
		"segments": [{"f": 147.0, "d": 0.20, "w": "square"}],
		"vol_db": -9.0,
	},
	&"stage_cleared": {
		"segments": [{"f": 523.0, "d": 0.08, "w": "sine"}, {"f": 659.0, "d": 0.08, "w": "sine"}, {"f": 784.0, "d": 0.16, "w": "sine"}],
		"vol_db": -5.0,
	},
	&"stage_failed": {
		"segments": [{"f": 392.0, "d": 0.12, "w": "square"}, {"f": 311.0, "d": 0.12, "w": "square"}, {"f": 233.0, "d": 0.20, "w": "square"}],
		"vol_db": -7.0,
	},
	&"dialog_open": {
		"segments": [{"f": 587.0, "d": 0.05, "w": "sine"}, {"f": 880.0, "d": 0.07, "w": "sine"}],
		"vol_db": -9.0,
	},
	&"dialog_stats_pop": {
		"segments": [{"f": 1320.0, "d": 0.03, "w": "sine"}],
		"vol_db": -10.0,
	},
	&"dialog_btn_press": {
		"segments": [{"f": 660.0, "d": 0.04, "w": "square"}],
		"vol_db": -9.0,
	},
	&"star_fill": {
		"segments": [{"f": 1047.0, "d": 0.05, "w": "sine"}, {"f": 1319.0, "d": 0.07, "w": "sine"}],
		"vol_db": -7.0,
	},
	&"locked": {
		"segments": [{"f": 196.0, "d": 0.06, "w": "square"}, {"f": 165.0, "d": 0.10, "w": "square"}],
		"vol_db": -8.0,
	},
}

var _streams: Dictionary = {}          # clean id → AudioStreamWAV (합성 캐시)
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0

# 테스트 가시성용 (런타임 동작엔 영향 없음).
var last_played: StringName = &""


func _ready() -> void:
	_build_pool()
	for id in SFX_SPECS:
		_streams[id] = _build_stream(SFX_SPECS[id])
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
	# 런타임 정규화 없음. id를 그대로 조회. 미매핑은 경고 후 skip (크래시 금지).
	if not _streams.has(id):
		push_warning("[SfxPlayer] unmapped sfx id: %s" % id)
		return
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _streams[id]
	player.play()
	last_played = id


## 스펙 → 16-bit PCM AudioStreamWAV 절차 합성.
func _build_stream(spec: Dictionary) -> AudioStreamWAV:
	var amp: float = db_to_linear(spec.get("vol_db", -8.0))
	var samples := PackedFloat32Array()
	for seg in spec.get("segments", []):
		var f: float = seg.get("f", 0.0)
		var d: float = seg.get("d", 0.1)
		var w: String = seg.get("w", "sine")
		var n: int = int(d * MIX_RATE)
		if n <= 0:
			continue
		var attack: float = 0.1 * n
		var release: float = 0.4 * n
		for i in n:
			var t: float = float(i) / MIX_RATE
			var phase: float = f * t
			var s: float = 0.0
			match w:
				"sine":
					s = sin(TAU * phase)
				"square":
					s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"noise":
					s = randf() * 2.0 - 1.0
			# 클릭 방지용 per-segment ADSR (선형 attack 10% / release 40%).
			var env: float = 1.0
			if i < attack:
				env = float(i) / attack
			elif i > n - release:
				env = float(n - i) / release
			samples.append(s * env * amp)

	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = data
	return stream
