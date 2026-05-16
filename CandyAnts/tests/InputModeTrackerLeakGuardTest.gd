extends Node

# Phase 8 — InputModeTracker가 게임 로직에 leak되지 않는지 코드 grep으로 검증.
# 계약(INPUT_PLAN §2 책임 분리): mode는 UI 힌트 전용. 게임 분기 금지.


func _ready() -> void:
	var pairs: Array = [
		# 게임 로직 파일에 InputModeTracker 참조 0건
		{"path": "res://scripts/input/InputRouter.gd", "needle": "InputModeTracker"},
		{"path": "res://scripts/ui/SkillToolbar.gd",  "needle": "InputModeTracker"},
		{"path": "res://scripts/ant/Ant.gd",          "needle": "InputModeTracker"},
		# 반대로 InputModeTracker가 게임 로직을 import하지 않는지
		{"path": "res://scripts/input/InputModeTracker.gd", "needle": "InputRouter"},
		{"path": "res://scripts/input/InputModeTracker.gd", "needle": "SkillToolbar"},
		{"path": "res://scripts/input/InputModeTracker.gd", "needle": "CursorTargeting"},
	]
	for pair in pairs:
		var content: String = _read_file(pair["path"])
		if content == "":
			_fail("파일 못 읽음: %s" % pair["path"]); return
		# 주석 라인은 제외 — leak은 코드 참조만 검출.
		var code_only: String = _strip_comments(content)
		if code_only.find(pair["needle"]) != -1:
			_fail("%s 안에 '%s' 코드 참조 발견" % [pair["path"], pair["needle"]]); return

	print("[InputModeTrackerLeakGuardTest] PASS")
	get_tree().quit(0)


func _strip_comments(text: String) -> String:
	# String-aware comment stripping (codex impl-review Round 1 LOW-1 대응):
	# - 한 줄을 한 글자씩 스캔, '"' 또는 "'" 안의 # 는 주석 처리 안 함.
	# - 이스케이프(\")는 문자열 내부로 간주.
	# - 다중 라인 string("""..." / '''...''')은 GDScript에서 거의 안 쓰므로 single-line만 처리.
	#   docstring 형태의 long string은 leak 표적이 아니므로 fail-soft 허용.
	var out: PackedStringArray = PackedStringArray()
	for raw in text.split("\n"):
		var line: String = raw
		var stripped: String = ""
		var in_string: bool = false
		var quote_char: String = ""
		var i: int = 0
		while i < line.length():
			var c: String = line.substr(i, 1)
			if in_string:
				if c == "\\" and i + 1 < line.length():
					stripped += c + line.substr(i + 1, 1)
					i += 2
					continue
				if c == quote_char:
					in_string = false
				stripped += c
			else:
				if c == "\"" or c == "'":
					in_string = true
					quote_char = c
					stripped += c
				elif c == "#":
					break  # 주석 시작 — 나머지 라인 버림
				else:
					stripped += c
			i += 1
		out.append(stripped)
	return "\n".join(out)


func _read_file(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


func _fail(label: String) -> void:
	push_error("[InputModeTrackerLeakGuardTest] FAIL %s" % label)
	print("[InputModeTrackerLeakGuardTest] FAIL %s" % label)
	get_tree().quit(1)
