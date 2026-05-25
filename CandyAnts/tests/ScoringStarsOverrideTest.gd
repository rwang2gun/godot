extends Node

# Phase 20 — F-D3 회귀 가드. Scoring.compute_stars 시그니처 확장(thresholds 인자) 검증.
# 빈 배열 fall-back / 명시 override / R1-M2 invalid 입력 0 star + warning.

var _failed: bool = false

func _ready() -> void:
	# (1) 빈 배열 fall-back은 글로벌 STAR_THRESHOLDS와 동일.
	_assert(Scoring.compute_stars(0, 10, []), 0, "[] empty (0,10)")
	_assert(Scoring.compute_stars(5, 10, []), 1, "[] empty (5,10)")
	_assert(Scoring.compute_stars(8, 10, []), 2, "[] empty (8,10)")
	_assert(Scoring.compute_stars(10, 10, []), 3, "[] empty (10,10)")
	# (2) 명시 글로벌과 동일한 override는 글로벌 결과와 동일.
	_assert(Scoring.compute_stars(8, 10, [0.50, 0.80, 0.95]), 2, "[0.50,0.80,0.95] (8,10)")
	# (3) stage03 override [0.55, 0.85, 0.97].
	_assert(Scoring.compute_stars(8, 10, [0.55, 0.85, 0.97]), 1, "[0.55,0.85,0.97] (8,10) ratio 0.8 < 0.85")
	_assert(Scoring.compute_stars(9, 10, [0.55, 0.85, 0.97]), 2, "[0.55,0.85,0.97] (9,10) ratio 0.9 >= 0.85 < 0.97")
	_assert(Scoring.compute_stars(10, 10, [0.55, 0.85, 0.97]), 3, "[0.55,0.85,0.97] (10,10) ratio 1.0 >= 0.97")
	# (4) R1-M2 invalid 입력 → 0 star + push_warning.
	_assert(Scoring.compute_stars(10, 10, [0.50, 0.80]), 0, "invalid len=2")
	_assert(Scoring.compute_stars(10, 10, [0.50, 0.30, 0.95]), 0, "descending")
	_assert(Scoring.compute_stars(10, 10, [-0.10, 0.80, 0.95]), 0, "out of range (<0)")
	_assert(Scoring.compute_stars(10, 10, [0.50, 0.80, 1.10]), 0, "out of range (>1)")
	# (5) original_hp <= 0 degenerate.
	_assert(Scoring.compute_stars(0, 0, []), 0, "(0,0) degenerate")
	_assert(Scoring.compute_stars(5, 0, [0.50, 0.80, 0.95]), 0, "(5,0) degenerate with override")
	if not _failed:
		print("[ScoringStarsOverrideTest] PASS")
		get_tree().quit(0)

func _assert(got: int, expected: int, label: String) -> void:
	if _failed:
		return
	if got != expected:
		_failed = true
		print("[ScoringStarsOverrideTest] FAIL %s: expected=%d got=%d" % [label, expected, got])
		get_tree().quit(1)
