class_name Scoring
extends RefCounted

# Phase 12 owner — UI_GUIDE §5.3 단일 SoT.
# Phase 13 SaveData.record_clear도 본 함수만 호출 (자체 계산 금지).
# Phase 20 — `thresholds: Array = []` 시그니처 확장. 빈 배열은 글로벌 fall-back.
#  R1-M2: invalid thresholds(길이 != 3 / descending / 0..1 범위 외)는 0 star + push_warning.

const STAR_THRESHOLDS := [0.50, 0.80, 0.95]   # ascending, len = max_stars(3)

static func compute_stars(saved: int, original_hp: int, thresholds: Array = []) -> int:
	if original_hp <= 0:
		return 0
	# R1-M2 — invalid thresholds 0 star + warning fall-back.
	# 길이 ≠ 3 / descending / 0..1 범위 외는 silent corruption 차단.
	if not thresholds.is_empty():
		if thresholds.size() != STAR_THRESHOLDS.size():
			push_warning("[Scoring] invalid star_thresholds length: %d (expected %d)" % [thresholds.size(), STAR_THRESHOLDS.size()])
			return 0
		var prev: float = -1.0
		for t in thresholds:
			var tf: float = float(t)
			if tf < prev or tf < 0.0 or tf > 1.0:
				push_warning("[Scoring] invalid star_thresholds entry %s (must be ascending in [0,1])" % str(thresholds))
				return 0
			prev = tf
	var ratio := float(saved) / float(original_hp)
	var th: Array = thresholds if not thresholds.is_empty() else STAR_THRESHOLDS
	var stars := 0
	for threshold in th:
		if ratio >= threshold:
			stars += 1
	return stars
