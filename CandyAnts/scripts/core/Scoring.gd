class_name Scoring
extends RefCounted

# 별 규칙 (2026-06-08 전역 고정 — 스테이지별 임계값 override 폐지).
#   - saved >= 1   (조각수 기준, 사탕 HP 무관)   → 1성  (= 스테이지 클리어 조건)
#   - 비율 >= 50%                                → 2성
#   - 비율 >= 80%                                → 3성
#   - 비율 == 100% (saved == original_hp)        → is_perfect (UI가 보라색 별로 표시)
# 비율 = saved / original_hp. UI_GUIDE §5.3 단일 SoT.
# SaveData.record_clear / StageDialog / StageSlotCard / StageRunner 모두 본 함수만 호출 (자체 계산 금지).

const SECOND_STAR_RATIO := 0.50
const THIRD_STAR_RATIO := 0.80

static func compute_stars(saved: int, original_hp: int) -> int:
	if original_hp <= 0 or saved <= 0:
		return 0
	return compute_stars_from_ratio(float(saved) / float(original_hp))

# 비율(이미 saved/original_hp로 계산된 값)만으로 별 산정. SaveData 마이그레이션이 best_score(저장된 비율)로
# original_hp 없이 stars를 재계산할 때 사용. saved >= 1 ⟺ ratio > 0 이므로 1성 경계도 비율로 표현 가능.
static func compute_stars_from_ratio(ratio: float) -> int:
	if ratio <= 0.0:
		return 0
	var stars := 1
	if ratio >= SECOND_STAR_RATIO:
		stars = 2
	if ratio >= THIRD_STAR_RATIO:
		stars = 3
	return stars

# 100% 회수(완벽 클리어) 여부. UI가 보라색 별 토글에 사용.
static func is_perfect(saved: int, original_hp: int) -> bool:
	return original_hp > 0 and saved >= original_hp
