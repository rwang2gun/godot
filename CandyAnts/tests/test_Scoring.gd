extends Node

# Phase 12 TDD stub — Scoring.compute_stars(saved, original_hp) -> int 단일 SoT 존재 가드.
# 자세한 boundary 검증은 tests/ScoringStarsTest.{tscn,gd}가 담당.

func _ready() -> void:
	assert(Scoring.compute_stars(8, 10) == 2, "Scoring.compute_stars present + basic case")
	print("[test_Scoring] PASS")
	get_tree().quit(0)
