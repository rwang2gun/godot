extends Node

# Scoring.compute_stars(saved, original_hp) 경계 검증 — 전역 고정 규칙 회귀 가드.
# 규칙: saved>=1 → 1성 / 비율>=50% → 2성 / 비율>=80% → 3성. (UI_GUIDE §5.3 단일 SoT)
# is_perfect(saved, hp) = 비율==100% (보라색 별).

var _failed: bool = false

func _ready() -> void:
	# hp=10 경계.
	_assert_stars(0, 10, 0, "(0,10) 0조각 → 0성")
	_assert_stars(1, 10, 1, "(1,10) 1조각(10%) → 1성, HP 무관")
	_assert_stars(4, 10, 1, "(4,10) 40% < 50% → 1성")
	_assert_stars(5, 10, 2, "(5,10) 50% 경계 → 2성")
	_assert_stars(7, 10, 2, "(7,10) 70% < 80% → 2성")
	_assert_stars(8, 10, 3, "(8,10) 80% 경계 → 3성")
	_assert_stars(9, 10, 3, "(9,10) 90% → 3성")
	_assert_stars(10, 10, 3, "(10,10) 100% → 3성")
	_assert_stars(0, 0, 0, "(0,0) degenerate → 0성")
	# 작은 HP — 1조각이면 비율 무관 1성.
	_assert_stars(1, 5, 1, "(1,5) 20% → 1성")
	_assert_stars(1, 100, 1, "(1,100) 1% → 1성 (HP 무관)")
	_assert_stars(50, 100, 2, "(50,100) 50% 경계 → 2성")
	_assert_stars(79, 100, 2, "(79,100) 79% < 80% → 2성")
	_assert_stars(80, 100, 3, "(80,100) 80% 경계 → 3성")
	# is_perfect.
	_assert_perfect(10, 10, true, "(10,10) 100% perfect")
	_assert_perfect(9, 10, false, "(9,10) 90% not perfect")
	_assert_perfect(5, 5, true, "(5,5) 100% perfect")
	_assert_perfect(0, 0, false, "(0,0) degenerate not perfect")
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

func _assert_perfect(saved: int, original: int, expected: bool, label: String) -> void:
	if _failed:
		return
	var got := Scoring.is_perfect(saved, original)
	if got != expected:
		_failed = true
		print("[ScoringStarsTest] FAIL %s: expected=%s got=%s" % [label, str(expected), str(got)])
		get_tree().quit(1)
