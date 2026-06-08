extends Node
## Phase 23 — BgmPlayer receiver 검증 (repo-도출 커버리지, 정규화 없음). SfxReceiverTest 미러.
##
## 검증:
##  (a) repo-도출 커버리지: scripts/ 스캔 bgm_request.emit track 전부 BgmPlayer.BGM_SPECS 키에 존재.
##  (b) 글로벌 prefix 가드: 추출 track 중 콜론 0건.
##  (c) 로드 무결성(Phase 24): 실제 CC0 ogg가 non-null AudioStream으로 로드 + length>0 (무음 경계 역전).
##  (d) 로직(합성 WAV 주입, 포맷-결정적): emit→current_track 일치 + 활성 player playing + 루프 on / idempotent /
##      전환 / graceful / bgm_stop.
##  (e) rapid re-entry: menu→gameplay→menu 연속 emit 후 fade(>0.4s) 대기 → 활성 player만 playing,
##      stale player stop, current_track==menu (tween 소유권/취소 입증).

const SCRIPTS_ROOT: String = "res://scripts"

var _failed: bool = false


func _ready() -> void:
	var tracks: Array[StringName] = _scan_emit_tracks()
	if tracks.is_empty():
		_fail("scripts/ 스캔에서 bgm_request.emit track을 0건 추출 — 스캐너/배선 결함 의심")
		return
	print("[BgmReceiverTest] 추출 track %d종: %s" % [tracks.size(), str(tracks)])

	# (a) repo-도출 커버리지.
	for t in tracks:
		if not BgmPlayer.BGM_SPECS.has(t):
			_fail("emit track '%s' 가 BgmPlayer.BGM_SPECS에 없음 (미매핑)" % t)
			return
	print("[BgmReceiverTest] (a) 커버리지 OK — %d track 전부 매핑" % tracks.size())

	# (b) prefix 가드.
	for t in tracks:
		if String(t).contains(":"):
			_fail("emit track에 콜론(prefix) 잔존: '%s'" % t)
			return
	print("[BgmReceiverTest] (b) prefix 가드 OK")

	# (c) 로드 무결성 — Phase 24: 실제 CC0 ogg가 로드됨(무음 경계 역전, ADR-013). 파일 누락/오타/
	# import 미완 시 _streams에 빠지거나 null → FAIL. (Phase 23의 "_streams 비어있음" 단언을 뒤집음.)
	if BgmPlayer._streams.size() != BgmPlayer.BGM_SPECS.size():
		_fail("(c) 로드 stream 수(%d) != BGM_SPECS 수(%d) — 파일 누락/오타/import 미완" % [BgmPlayer._streams.size(), BgmPlayer.BGM_SPECS.size()])
		return
	for t in BgmPlayer.BGM_SPECS:
		var s = BgmPlayer._streams.get(t)
		if s == null or not (s is AudioStream):
			_fail("(c) track '%s' 리소스 로드 실패 (null/타입)" % t)
			return
		if (s as AudioStream).get_length() <= 0.0:
			_fail("(c) track '%s' stream 길이 0 (빈 오디오)" % t)
			return
	print("[BgmReceiverTest] (c) 로드 무결성 OK — %d 실제 stream 로드" % BgmPlayer._streams.size())

	# (c2) 실제 ogg 루프/격리 — WAV 주입 *이전에* `_apply_loop(AudioStreamOggVorbis)` 경로를 검증
	# (codex impl R1 HIGH). ogg 분기 제거/캐시 변형 회귀 시 "한 번 재생 후 EOF 무음"을 잡는다.
	# 캐시 원본 loop를 false로 강제 → emit → 활성 스트림이 *별도* ogg 인스턴스 + loop==true,
	# 캐시 원본은 loop==false 유지(격리).
	for t in [&"menu", &"gameplay"]:
		var src_ogg := BgmPlayer._streams[t] as AudioStreamOggVorbis
		if src_ogg == null:
			_fail("(c2) track '%s'가 AudioStreamOggVorbis 아님 — 포맷 가정 깨짐" % t)
			return
		src_ogg.loop = false
		EventBus.bgm_request.emit(t)
		await get_tree().process_frame
		var active_ogg := BgmPlayer._players[BgmPlayer._active].stream as AudioStreamOggVorbis
		if active_ogg == null or not active_ogg.loop:
			_fail("(c2) track '%s' 재생 ogg 스트림 loop 미설정 — EOF 무음 회귀" % t)
			return
		if active_ogg == src_ogg:
			_fail("(c2) track '%s' 격리 위반 — 재생 ogg가 캐시 원본과 동일 인스턴스" % t)
			return
		if src_ogg.loop:
			_fail("(c2) track '%s' 격리 위반 — 캐시 ogg 원본 loop가 변형됨" % t)
			return
	# 다음 로직 검사가 처음부터 재생하도록 상태 리셋(current_track 비움).
	EventBus.bgm_stop.emit()
	await get_tree().process_frame
	print("[BgmReceiverTest] (c2) ogg 루프/격리 OK — 실제 ogg 재생 스트림 loop==true, 원본 격리")

	# 이하 로직 검증: 합성 WAV 주입으로 재생 경로를 결정적으로 운동(loop_mode 단언이 포맷-결정적).
	# (c)/(c2)가 실제 ogg 로드+루프를 증명했으므로, crossfade/idempotent 로직은 주입 WAV로 검사.
	BgmPlayer._streams[&"menu"] = _make_wav()
	BgmPlayer._streams[&"gameplay"] = _make_wav()

	# (d-1) 재생/루프.
	EventBus.bgm_request.emit(&"menu")
	await get_tree().process_frame
	if BgmPlayer.current_track != &"menu":
		_fail("(d) emit menu 후 current_track='%s' (기대 menu)" % BgmPlayer.current_track)
		return
	if not BgmPlayer._players[BgmPlayer._active].playing:
		_fail("(d) 활성 player가 playing 아님")
		return
	# 루프: 활성 player에 *할당된* 스트림(복제본)이 루프. 원본 _streams 엔트리는 미변형(격리).
	var active_stream := BgmPlayer._players[BgmPlayer._active].stream as AudioStreamWAV
	if active_stream == null or active_stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		_fail("(d) 재생 스트림 루프 미설정")
		return
	var src_stream := BgmPlayer._streams[&"menu"] as AudioStreamWAV
	if src_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		_fail("(d) 격리 위반 — 캐시된 원본 스트림이 변형됨 (loop_mode=%d, 기대 DISABLED=0)" % src_stream.loop_mode)
		return
	if src_stream == active_stream:
		_fail("(d) 격리 위반 — 재생 스트림이 원본과 동일 인스턴스 (복제 안 됨)")
		return
	print("[BgmReceiverTest] (d) 재생/루프 + 원본 격리 OK")

	# (d-2) idempotent — 동일 track 재emit 시 무중단.
	var gen_before: int = BgmPlayer.play_generation
	EventBus.bgm_request.emit(&"menu")
	await get_tree().process_frame
	if BgmPlayer.play_generation != gen_before:
		_fail("(d) idempotent 위반 — 같은 track 재emit에 play_generation 증가 (%d→%d)" % [gen_before, BgmPlayer.play_generation])
		return
	print("[BgmReceiverTest] (d) idempotent OK")

	# (d-3) 전환.
	EventBus.bgm_request.emit(&"gameplay")
	await get_tree().process_frame
	if BgmPlayer.current_track != &"gameplay" or BgmPlayer.play_generation != gen_before + 1:
		_fail("(d) 전환 실패 — current='%s' gen=%d" % [BgmPlayer.current_track, BgmPlayer.play_generation])
		return
	print("[BgmReceiverTest] (d) 전환 OK")

	# (d-4) graceful — 미매핑 track skip, current_track 불변.
	var before_track: StringName = BgmPlayer.current_track
	EventBus.bgm_request.emit(&"__no_such_bgm__")
	await get_tree().process_frame
	if BgmPlayer.current_track != before_track:
		_fail("(d) graceful 위반 — 미매핑 track이 current_track 변경 ('%s')" % BgmPlayer.current_track)
		return
	print("[BgmReceiverTest] (d) graceful OK")

	# (d-5) bgm_stop.
	EventBus.bgm_stop.emit()
	await get_tree().process_frame
	if BgmPlayer.current_track != &"":
		_fail("(d) bgm_stop 후 current_track='%s' (기대 빈값)" % BgmPlayer.current_track)
		return
	print("[BgmReceiverTest] (d) bgm_stop OK")

	# (e) rapid re-entry — menu→gameplay→menu 연속, fade 시간보다 길게 대기 후 최종 상태.
	EventBus.bgm_request.emit(&"menu")
	EventBus.bgm_request.emit(&"gameplay")
	EventBus.bgm_request.emit(&"menu")
	await get_tree().create_timer(0.6).timeout
	if BgmPlayer.current_track != &"menu":
		_fail("(e) rapid 후 current_track='%s' (기대 menu)" % BgmPlayer.current_track)
		return
	var active: int = BgmPlayer._active
	if not BgmPlayer._players[active].playing:
		_fail("(e) rapid 후 활성 player가 playing 아님")
		return
	if BgmPlayer._players[1 - active].playing:
		_fail("(e) rapid 후 stale(비활성) player가 여전히 playing — tween 취소/stop 누락")
		return
	print("[BgmReceiverTest] (e) rapid re-entry OK")

	print("[BgmReceiverTest] PASS")
	get_tree().quit(0)


## 16-bit mono 무음 WAV 1초 — 재생 경로 운동용(내용 무관, 길이>0 + 루프 가능).
func _make_wav() -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = 22050
	s.stereo = false
	var data := PackedByteArray()
	data.resize(22050 * 2)   # 1초 분량(16-bit mono)
	s.data = data
	return s


## scripts/ 재귀 스캔 → bgm_request.emit(&"track") literal에서 track 집합 추출(주석 줄 제외).
func _scan_emit_tracks() -> Array[StringName]:
	var re := RegEx.new()
	re.compile("bgm_request\\.emit\\(&\"([^\"]+)\"\\)")
	var files: Array[String] = []
	_collect_gd_files(SCRIPTS_ROOT, files)
	var seen := {}
	var ids: Array[StringName] = []
	for path in files:
		var content := FileAccess.get_file_as_string(path)
		for line in content.split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			var m := re.search(line)
			if m == null:
				continue
			var id := StringName(m.get_string(1))
			if not seen.has(id):
				seen[id] = true
				ids.append(id)
	return ids


func _collect_gd_files(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if d.current_is_dir():
			if name == "." or name == "..":
				continue
			_collect_gd_files(dir_path.path_join(name), out)
		elif name.ends_with(".gd"):
			out.append(dir_path.path_join(name))
	d.list_dir_end()


func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[BgmReceiverTest] FAIL ", msg)
	get_tree().quit(1)
