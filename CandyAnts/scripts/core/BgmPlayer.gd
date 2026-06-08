extends Node
## Phase 23 — BGM receiver. EventBus.bgm_request(track)/bgm_stop()를 받아 루프 BGM을 재생한다.
## SfxPlayer 패턴 미러링(autoload + 시그널 구독 + *_SPECS Dictionary SoT + 버스 Master 폴백 + graceful skip).
## BGM 고유: 무한 루프 + 짧은 크로스페이드(2-player A/B) + 같은 track 재진입 무중단(idempotent).
##
## 실제 CC0 루프 음원은 Phase 24 — 본 phase는 인터페이스만. BGM_SPECS 경로의 ogg가 부재하면
## _ready의 load가 graceful skip → _streams 비어 무음(의도된 상태). 로직 검증은 테스트가
## 합성 스트림을 _streams에 주입해 수행(BgmReceiverTest). 실배선은 BgmSceneFlowTest.

const BGM_BUS: StringName = &"BGM"
const BGM_DIR: String = "res://assets/audio/bgm"
const FADE_SEC: float = 0.4
const MIN_DB: float = -40.0   # 페이드 아웃 목표 — 충분히 무음(denormal 회피 위해 -80 미사용).

## track id → 루프 음원 경로. Phase 24에서 실제 ogg 배치. clean id(콜론/prefix 없음)만 허용.
const BGM_SPECS: Dictionary = {
	&"menu": BGM_DIR + "/menu.ogg",
	&"gameplay": BGM_DIR + "/gameplay.ogg",
}

## track id → 재생 볼륨(dB). 페이드인 목표값으로 사용. 여기 없는 track은 0 dB(기본, 무변경).
## SFX(SfxPlayer.VOLUME_DB)와 동형 — 게임 청취 후 이 값만 바꿔 BGM/SFX 밸런스를 맞춘다.
const VOLUME_DB: Dictionary = {
	&"menu": -5.0,
	&"gameplay": -13.0,
}

var _streams: Dictionary = {}                  # track id → AudioStream (로드 성공분만)
var _players: Array[AudioStreamPlayer] = []    # 2-player 크로스페이드 A/B
var _tweens: Array[Tween] = [null, null]       # per-player 활성 fade tween (새 fade 전 kill).
var _active: int = 0                           # 현재 활성 player 인덱스

# 테스트 seam (런타임 동작엔 영향 없음).
var current_track: StringName = &""            # 실제 재생 중인 track. graceful skip 시 미갱신(무음 유지).
var last_requested: StringName = &""           # 마지막 _on_bgm_request track. autoload 구독 검증용.
var play_generation: int = 0                   # 실제 (재)시작 횟수. idempotent 검증용.


func _ready() -> void:
	_build_players()
	for track in BGM_SPECS:
		var path: String = BGM_SPECS[track]
		# Phase 23: 파일 부재 → graceful(무음). Phase 24에서 실제 로드 → _streams 채워짐.
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("[BgmPlayer] bgm 로드 실패 (track=%s path=%s) — skip" % [track, path])
			continue
		_streams[track] = stream
	EventBus.bgm_request.connect(_on_bgm_request)
	EventBus.bgm_stop.connect(_on_bgm_stop)


func _build_players() -> void:
	# BGM 버스가 없으면(레이아웃 미로드 등) Master로 폴백 — 헤드리스/안전.
	var bus: StringName = BGM_BUS if AudioServer.get_bus_index(BGM_BUS) >= 0 else &"Master"
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = MIN_DB
		add_child(p)
		_players.append(p)


func _on_bgm_request(track: StringName) -> void:
	last_requested = track
	# idempotent: 같은 track이 이미 활성·재생 중이면 무중단(예: 메뉴 내 이동 menu→menu).
	if track == current_track and _players[_active].playing:
		return
	# 런타임 정규화 없음. 미매핑/미로드는 경고 후 skip — current_track 미갱신(무음 유지, 크래시 금지).
	if not _streams.has(track):
		push_warning("[BgmPlayer] unmapped or unloaded bgm track: %s" % track)
		return
	_start_track(track)


func _start_track(track: StringName) -> void:
	var prev: int = _active
	var next: int = 1 - _active
	# 캐시(_streams)된 원본을 변형하지 않도록 재생용 **복제본**에만 루프 플래그 적용(공유 리소스 격리,
	# codex impl-review R1 MEDIUM). duplicate(false)는 무거운 packet/data를 공유하고 loop 프로퍼티만
	# 새 인스턴스로 분리 → Phase 24+에서 같은 ogg를 비-루프 용도로 재사용해도 루프 누출 0.
	var stream: AudioStream = (_streams[track] as AudioStream).duplicate() as AudioStream
	_apply_loop(stream)
	var np: AudioStreamPlayer = _players[next]
	np.stream = stream
	np.volume_db = MIN_DB
	np.play()
	_active = next
	current_track = track
	play_generation += 1
	_fade(next, _target_db(track))   # 새 player fade in → track 볼륨(VOLUME_DB, 미지정 0 dB)
	if prev != next:
		_fade_out_stop(prev)   # 이전 player fade out → stop(콜백 시점 여전히 비활성일 때만)


func _on_bgm_stop() -> void:
	last_requested = &""
	current_track = &""
	var idx: int = _active
	_kill_tween(idx)
	var p: AudioStreamPlayer = _players[idx]
	var t := create_tween()
	_tweens[idx] = t
	t.tween_property(p, "volume_db", MIN_DB, FADE_SEC)
	t.tween_callback(p.stop)   # 명시적 stop은 무조건 정지.


## track 재생 볼륨(dB). VOLUME_DB 미지정 시 0 dB(기본).
func _target_db(track: StringName) -> float:
	return float(VOLUME_DB.get(track, 0.0))


# ─── 페이드(per-player tween 소유권 + 취소) ────────────────────────
func _fade(idx: int, target_db: float) -> void:
	_kill_tween(idx)           # 같은 player의 이전 fade를 죽여 볼륨 싸움 차단.
	var t := create_tween()
	_tweens[idx] = t
	t.tween_property(_players[idx], "volume_db", target_db, FADE_SEC)


func _fade_out_stop(idx: int) -> void:
	_kill_tween(idx)
	var p: AudioStreamPlayer = _players[idx]
	var t := create_tween()
	_tweens[idx] = t
	t.tween_property(p, "volume_db", MIN_DB, FADE_SEC)
	# 빠른 재진입으로 콜백 시점에 다시 활성이 됐으면 stop 금지 — stale stop 방지.
	t.tween_callback(func() -> void:
		if _active != idx:
			p.stop()
	)


func _kill_tween(idx: int) -> void:
	var t: Tween = _tweens[idx]
	if t != null and t.is_valid():
		t.kill()
	_tweens[idx] = null


# ogg/mp3는 loop 프로퍼티, wav는 loop_mode. 타입별로 루프 플래그를 보장한다(명시적 캐스트).
func _apply_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			if wav.loop_end <= 0:
				# 16-bit mono 기준 프레임 수 = data 바이트/2. 루프 끝을 데이터 끝으로.
				wav.loop_end = wav.data.size() / 2
