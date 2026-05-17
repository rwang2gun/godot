extends Node

# Phase 12 — Scoring.compute_stars(saved, original_hp) boundary 검증.
# UI_GUIDE §5.3 STAR_THRESHOLDS=[0.50, 0.80, 0.95]. 단일 SoT 회귀 가드.

var _failed: bool = false

func _ready() -> void:
	_assert_stars(0, 10, 0, "(0,10)")
	_assert_stars(4, 10, 0, "(4,10) just below 0.5")
	_assert_stars(5, 10, 1, "(5,10) at 0.5 boundary")
	_assert_stars(7, 10, 1, "(7,10) below 0.8")
	_assert_stars(8, 10, 2, "(8,10) at 0.8 boundary")
	_assert_stars(9, 10, 2, "(9,10) below 0.95")
	_assert_stars(10, 10, 3, "(10,10) at 1.0")
	_assert_stars(0, 0, 0, "(0,0) degenerate")
	_assert_stars(95, 100, 3, "(95,100) at 0.95 boundary")
	_assert_stars(94, 100, 2, "(94,100) just below 0.95")
	if not _failed:
		print("[ScoringStarsTest] PASS")
		get_tree().quit(0)

func _assert_stars(saved: int, original: int, expected: int, label: String) -> void:
	if _failed:
		return
	var got := Scoring.compute_stars(saved, original)
	if got != expected:
		_failed = true
		print("[ScoringStarsTest] FAIL %s: expected=%d got=%d" % [label, expected, got])
		get_tree().quit(1)
