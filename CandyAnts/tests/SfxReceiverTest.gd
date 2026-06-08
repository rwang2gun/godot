extends Node
## Phase 21 — SfxPlayer receiver 검증 (repo-도출 커버리지, 정규화 없음).
## plan review Round 1 HIGH: 하드코딩 목록 금지 — scripts/ 스캔으로 emit id를 동적 추출.
## plan review Round 2 HIGH: 정규화 마스킹 차단 — raw id를 그대로 검사·재생.
##
## 검증:
##  (a) 글로벌 prefix 가드: 추출 raw id 중 콜론 포함 0건 (전 스크립트 대상).
##  (b) 직접 커버리지: 추출된 모든 raw id가 SfxPlayer.SFX_SPECS에 그대로 존재.
##  (c) 합성 무결성: SFX_SPECS의 14 stream 전부 non-null + data 비어있지 않음.
##  (d) 동적 재생: 각 raw id emit 후 SfxPlayer가 그 id를 재생 (last_played 일치).
##  (e) 정규화 회귀: StageSelect.gd에 sfx:locked 부재 + locked 존재.
##  (f) graceful: 미등록 id emit 시 크래시 없이 skip (last_played 미갱신).

const SCRIPTS_ROOT: String = "res://scripts"
const STAGE_SELECT_PATH: String = "res://scripts/ui/StageSelect.gd"

var _failed: bool = false


func _ready() -> void:
	var raw_ids: Array[StringName] = _scan_emit_ids()
	if raw_ids.is_empty():
		_fail("scripts/ 스캔에서 sfx_request.emit id를 0건 추출 — 스캐너 결함 의심")
		return
	print("[SfxReceiverTest] 추출 raw id %d종: %s" % [raw_ids.size(), str(raw_ids)])

	# (a) 글로벌 prefix 가드 — 정규화 없이 raw 그대로 검사.
	for id in raw_ids:
		if String(id).contains(":"):
			_fail("raw emit id에 콜론(prefix) 잔존: '%s' — clean id로 emit해야 함" % id)
			return
	print("[SfxReceiverTest] (a) 글로벌 prefix 가드 OK")

	# (b) 직접 커버리지 — 추출된 모든 raw id가 SFX_SPECS에 존재.
	for id in raw_ids:
		if not SfxPlayer.SFX_SPECS.has(id):
			_fail("emit id '%s' 가 SfxPlayer.SFX_SPECS에 없음 (미매핑)" % id)
			return
	print("[SfxReceiverTest] (b) 직접 커버리지 OK — %d id 전부 매핑" % raw_ids.size())

	# (c) 리소스 로드 무결성 — 모든 spec이 non-null AudioStream으로 load됨 (P22 파일 기반).
	# 파일 누락/오타/import 미완 시 _streams에 빠지거나 null → 여기서 FAIL.
	if SfxPlayer._streams.size() != SfxPlayer.SFX_SPECS.size():
		_fail("로드 stream 수(%d) != SFX_SPECS 수(%d) — 파일 누락/오타/import 미완 의심" % [SfxPlayer._streams.size(), SfxPlayer.SFX_SPECS.size()])
		return
	for id in SfxPlayer.SFX_SPECS:
		var stream = SfxPlayer._streams.get(id)
		if stream == null or not (stream is AudioStream):
			_fail("id '%s' 리소스 로드 실패 (null/타입: %s)" % [id, SfxPlayer.SFX_SPECS[id]])
			return
		if (stream as AudioStream).get_length() <= 0.0:
			_fail("id '%s' stream 길이 0 (빈 오디오)" % id)
			return
	print("[SfxReceiverTest] (c) 리소스 로드 무결성 OK — %d stream" % SfxPlayer._streams.size())

	# (d) 동적 재생 — 각 raw id emit → SfxPlayer가 그 id를 재생.
	for id in raw_ids:
		SfxPlayer.last_played = &""
		EventBus.sfx_request.emit(id)
		await get_tree().process_frame
		if SfxPlayer.last_played != id:
			_fail("emit '%s' 후 last_played='%s' (재생 누락)" % [id, SfxPlayer.last_played])
			return
	print("[SfxReceiverTest] (d) 동적 재생 OK — %d id 전부 재생" % raw_ids.size())

	# (e) 정규화 회귀 — StageSelect.gd.
	var ss := FileAccess.get_file_as_string(STAGE_SELECT_PATH)
	if ss.is_empty():
		_fail("StageSelect.gd 읽기 실패")
		return
	if ss.contains("sfx:locked"):
		_fail("StageSelect.gd에 'sfx:locked' literal 잔존 — 'locked'로 통일해야 함")
		return
	if not ss.contains("sfx_request.emit(&\"locked\")"):
		_fail("StageSelect.gd에 clean 'locked' emit 부재")
		return
	print("[SfxReceiverTest] (e) 정규화 회귀 OK")

	# (f) graceful — 미등록 id는 크래시 없이 skip.
	SfxPlayer.last_played = &""
	EventBus.sfx_request.emit(&"__no_such_sfx__")
	await get_tree().process_frame
	if SfxPlayer.last_played != &"":
		_fail("미등록 id가 재생됨 (graceful skip 위반)")
		return
	print("[SfxReceiverTest] (f) graceful skip OK")

	print("[SfxReceiverTest] PASS")
	get_tree().quit(0)


## scripts/ 재귀 스캔 → sfx_request.emit(&"id") literal에서 raw id 집합 추출.
## 주석 줄(스트립 후 '#' 시작)은 제외해 doc 멘션이 false id를 만들지 않게 한다.
func _scan_emit_ids() -> Array[StringName]:
	var re := RegEx.new()
	re.compile("sfx_request\\.emit\\(&\"([^\"]+)\"\\)")
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
	var name := d.get_next()
	while name != "":
		if d.current_is_dir():
			if name != "." and name != "..":
				_collect_gd_files(dir_path + "/" + name, out)
		elif name.ends_with(".gd"):
			out.append(dir_path + "/" + name)
		name = d.get_next()
	d.list_dir_end()


func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[SfxReceiverTest] FAIL ", msg)
	get_tree().quit(1)
