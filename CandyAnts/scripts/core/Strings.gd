extends Node

# CandyAnts UI 스트링 테이블 — 가벼운 오토로드 (2026-06-02 신설).
# Godot tr()/CSV translation 파이프라인을 쓰지 않는 단일 dict 중앙화 SoT.
#
# 사용:
#   Strings.t("dialog.title_failed")              -> "사탕이 부족했어요"
#   Strings.t("dialog.hero_score", [saved, hp])   -> "3 / 5 조각"  (format % args)
#   Strings.skill_label("climber")                -> "등반"  (미등록 id면 id 그대로)
#
# 범위(2026-06-02): 런타임 .gd 호출부만 이 테이블을 참조한다.
#   씬(.tscn) 고정 text는 의도적으로 미연결 — 일부 라벨("귀가"/"잃음"/"남은 시간" 등)은
#   HUD.tscn Counter의 bottom_label_ko에 정적 중복으로 남아있다.
# key 네임스페이스는 소비 스크립트 기준. 새 문자열 추가 시 해당 섹션에 1줄 추가.

const _TABLE: Dictionary = {
	# StageDialog — scripts/ui/StageDialog.gd
	"dialog.title_last_clear": "마지막 단계 클리어!",
	"dialog.title_cleared": "사탕을 무사히 옮겼어요!",
	"dialog.title_failed": "사탕이 부족했어요",
	"dialog.subtitle_cleared": "Stage cleared",
	"dialog.subtitle_failed": "Stage failed",
	"dialog.hero_score": "%d / %d 조각",
	"dialog.chip_saved": "귀가",
	"dialog.chip_lost": "잃음",
	"dialog.chip_time": "남은 시간",
	"dialog.chip_time_value": "%ds",

	# InputHintLabel — scripts/ui/InputHintLabel.gd
	"hint.mouse": "클릭/드래그: 적용  ·  1~8: 스킬  ·  Space: 일시정지",
	"hint.pad": "A: 적용  ·  LB/RB: 전환  ·  View: 일시정지",
	"hint.touch": "탭/드래그: 적용",

	# StageSelect — scripts/ui/StageSelect.gd
	"stage_select.total_stars": "수확한 별 ★ %d / 30",

	# StageSlotCard — scripts/ui/atoms/StageSlotCard.gd
	"stage_card.title": "스테이지 %d",
	"stage_card.best": "최고 %d",

	# TitleScene — scripts/ui/TitleScene.gd
	"title.hint_pad": "버튼을 눌러 주세요",
	"title.hint_key": "아무 키나 눌러 주세요",
}

# 스킬 id -> 한글 라벨. 구 SkillToolbar.KO_LABELS를 이관.
# 미등록 id는 skill_label()이 영문 id를 그대로 반환(구 `.get(id, id)` 동작 보존).
const _SKILL_NAMES: Dictionary = {
	"climber": "등반",
	"floater": "낙하산",
	"blocker": "차단",
	"builder": "계단",
	"sand_mound": "모래",
	"bridge": "다리",
	"basher": "굴착",
	"digger": "땅파기",
	"distributor": "분배자",
	"cutter": "절단",
}

# key로 문자열 조회. args 비어있지 않으면 `%` format 적용.
# 미등록 key는 경고 후 key 자체를 반환(렌더 깨짐 없이 누락 노출).
func t(key: String, args: Array = []) -> String:
	if not _TABLE.has(key):
		push_warning("[Strings] missing key: %s" % key)
		return key
	var s: String = _TABLE[key]
	if args.is_empty():
		return s
	return s % args

# 스킬 한글 라벨. 미등록 id는 id 그대로(영문 fallback, 경고 없음).
func skill_label(id: String) -> String:
	return _SKILL_NAMES.get(id, id)

# 스킬 라벨이 명시 등록돼 있는지(영문 fallback과 구분). 스모크 테스트용.
func has_skill_label(id: String) -> bool:
	return _SKILL_NAMES.has(id)

func has_key(key: String) -> bool:
	return _TABLE.has(key)
