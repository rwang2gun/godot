class_name Scoring
extends RefCounted

# Phase 12 owner — UI_GUIDE §5.3 단일 SoT.
# Phase 13 SaveData.record_clear도 본 함수만 호출 (자체 계산 금지).

const STAR_THRESHOLDS := [0.50, 0.80, 0.95]   # ascending, len = max_stars(3)

static func compute_stars(saved: int, original_hp: int) -> int:
	if original_hp <= 0:
		return 0
	var ratio := float(saved) / float(original_hp)
	var stars := 0
	for threshold in STAR_THRESHOLDS:
		if ratio >= threshold:
			stars += 1
	return stars
