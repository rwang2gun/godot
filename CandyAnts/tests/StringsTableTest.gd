extends Node

# Strings 오토로드(scripts/core/Strings.gd) 스모크 테스트.
# 검증:
#   (1) 평문 key 조회가 기대 문자열 반환
#   (2) format key + args가 `%` 치환 정상
#   (3) skill_label: 등록 id -> 한글, 미등록 id -> id 그대로
#   (4) 미등록 key -> key 자체 반환(fallback)
#   (5) 마이그레이션된 호출부 key가 모두 테이블에 존재(누락 회귀 차단)

const MIGRATED_KEYS := [
	"dialog.title_last_clear", "dialog.title_cleared", "dialog.title_failed",
	"dialog.subtitle_cleared", "dialog.subtitle_failed", "dialog.hero_score",
	"dialog.chip_saved", "dialog.chip_lost", "dialog.chip_time", "dialog.chip_time_value",
	"hint.mouse", "hint.pad", "hint.touch",
	"stage_select.total_stars",
	"stage_card.title", "stage_card.best",
	"title.hint_pad", "title.hint_key",
]

const SKILL_IDS := [
	"climber", "floater", "blocker", "builder", "sand_mound",
	"bridge", "basher", "digger", "distributor", "cutter",
]

func _ready() -> void:
	var failures: Array[String] = []

	# (1) 평문 조회.
	if Strings.t("dialog.title_failed") != "사탕이 부족했어요":
		failures.append("(1) dialog.title_failed got=%s" % Strings.t("dialog.title_failed"))

	# (2) format.
	if Strings.t("dialog.hero_score", [3, 5]) != "3 / 5 조각":
		failures.append("(2) hero_score got=%s" % Strings.t("dialog.hero_score", [3, 5]))
	if Strings.t("dialog.chip_time_value", [12]) != "12s":
		failures.append("(2) chip_time_value got=%s" % Strings.t("dialog.chip_time_value", [12]))
	if Strings.t("stage_card.title", [7]) != "스테이지 7":
		failures.append("(2) stage_card.title got=%s" % Strings.t("stage_card.title", [7]))

	# (3) skill_label.
	if Strings.skill_label("climber") != "등반":
		failures.append("(3) skill_label climber got=%s" % Strings.skill_label("climber"))
	if Strings.skill_label("__nope__") != "__nope__":
		failures.append("(3) skill_label fallback got=%s" % Strings.skill_label("__nope__"))
	for id in SKILL_IDS:
		if not Strings.has_skill_label(id):
			failures.append("(3) has_skill_label missing %s" % id)

	# (4) 미등록 key fallback (경고 1회 발생 — 의도된 동작).
	if Strings.t("__missing__.__key__") != "__missing__.__key__":
		failures.append("(4) missing-key fallback got=%s" % Strings.t("__missing__.__key__"))

	# (5) 마이그레이션 key 존재.
	for key in MIGRATED_KEYS:
		if not Strings.has_key(key):
			failures.append("(5) missing migrated key: %s" % key)

	if failures.size() > 0:
		push_error("StringsTableTest FAIL\n" + "\n".join(failures))
		print("[StringsTableTest] FAIL\n", "\n".join(failures))
		get_tree().quit(1)
	else:
		print("[StringsTableTest] PASS - %d keys + %d skills verified" % [MIGRATED_KEYS.size(), SKILL_IDS.size()])
		get_tree().quit(0)
