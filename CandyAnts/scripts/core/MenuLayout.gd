class_name MenuLayout
extends Resource

# Phase 13 — StageSelect 슬롯 메타데이터. UI_GUIDE §3.6 + plan §3.8.
# slots[i] = {stage_id: int, display_name: String, available: bool}
# stage4~10 phase는 available을 true로 toggle + display_name 갱신만 (1줄).

const EXPECTED_LENGTH := 10

@export var slots: Array[Dictionary] = []

func is_valid() -> bool:
	if slots.size() != EXPECTED_LENGTH:
		return false
	for i in slots.size():
		var s: Dictionary = slots[i]
		if not s.has("stage_id") or not s.has("display_name") or not s.has("available"):
			return false
		# Codex R8 MED fix: type 검증 추가. "available": "false" String 통과 → 잘못된 bool 추출 차단.
		if typeof(s["stage_id"]) != TYPE_INT:
			return false
		if typeof(s["display_name"]) != TYPE_STRING:
			return false
		if typeof(s["available"]) != TYPE_BOOL:
			return false
		if int(s["stage_id"]) != i + 1:
			return false
	return true
