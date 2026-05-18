extends Node

# Phase 13 — plan Δ14 ★MED-C 회귀 가드.
# UI scene .gd 파일들이 legacy `request_menu` literal을 사용하지 않음을 정적 검증.

const TARGETS_NO_REQUEST_MENU := [
	"res://scripts/ui/TitleScene.gd",
	"res://scripts/ui/MainMenu.gd",
	"res://scripts/ui/StageSelect.gd",
	"res://scripts/ui/ComingSoonOverlay.gd",
]

const TARGETS_KEEP_REQUEST_MENU := [
	# StageDialog만 legacy alias emit (phase 12 산출).
	"res://scripts/ui/StageDialog.gd",
]

func _ready() -> void:
	# (1) UI scenes는 `request_menu` literal 없어야 함.
	# 단, `request_main_menu`처럼 superstring은 OK → "request_menu" 뒤 char가 word boundary인지 확인.
	for path in TARGETS_NO_REQUEST_MENU:
		if _file_contains_word(path, "request_menu"):
			return _fail("%s contains literal `request_menu` (use request_main_menu instead)" % path)
	# (2) StageDialog는 보존 검증.
	for path in TARGETS_KEEP_REQUEST_MENU:
		if not _file_contains_word(path, "request_menu"):
			return _fail("%s should still emit `request_menu` (legacy alias for StageDialog)" % path)
	print("[SceneFlowEmitContractTest] PASS")
	get_tree().quit(0)

func _file_contains_word(path: String, word: String) -> bool:
	# word boundary 검사: word 앞/뒤 char가 alphanumeric/underscore가 아니어야 함.
	var content := FileAccess.get_file_as_string(path)
	if content.is_empty():
		push_error("[SceneFlowEmitContractTest] cannot read %s" % path)
		return false
	var idx := 0
	while true:
		idx = content.find(word, idx)
		if idx < 0:
			return false
		var before_ok := idx == 0 or not _is_word_char(content[idx - 1])
		var after_idx := idx + word.length()
		var after_ok := after_idx >= content.length() or not _is_word_char(content[after_idx])
		if before_ok and after_ok:
			return true
		idx += 1
	return false

func _is_word_char(c: String) -> bool:
	if c.length() != 1:
		return false
	var code := c.unicode_at(0)
	# [A-Za-z0-9_]
	return (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code == 95

func _fail(msg: String) -> void:
	print("[SceneFlowEmitContractTest] FAIL ", msg)
	get_tree().quit(1)
