extends Node

# Phase 20 — R1-H4 회귀 가드. SceneFlow._on_stage_result에서 `stage_id` 비교가
# `==`(등치)로 유지되어야 함. 미래 STAGE_SCENES 확장 시 last-stage 오인 회피.
#
# 정적 검증: SceneFlow.gd 소스에 `result["stage_id"] == LAST_STAGE_ID` 정확히 존재.
# `>=` 비교가 다시 도입되면 FAIL.

const SCENE_FLOW_PATH := "res://scripts/core/SceneFlow.gd"

func _ready() -> void:
	var content := FileAccess.get_file_as_string(SCENE_FLOW_PATH)
	if content.is_empty():
		_fail("cannot read %s" % SCENE_FLOW_PATH)
		return
	# (1) 정확히 `== LAST_STAGE_ID` 표현 1개 이상 존재 (overlay.show_result 호출부).
	if not content.contains("result[\"stage_id\"] == LAST_STAGE_ID"):
		_fail("expected `result[\"stage_id\"] == LAST_STAGE_ID` literal in SceneFlow.gd (R1-H4 regression)")
		return
	# (2) `>=` 비교는 stage_id에 대해 사용되지 않아야 함.
	if content.contains("result[\"stage_id\"] >= LAST_STAGE_ID"):
		_fail("forbidden `result[\"stage_id\"] >= LAST_STAGE_ID` found in SceneFlow.gd (R1-H4)")
		return
	# (3) 다른 stage_id 비교 패턴(`>=`, `>`)이 last-stage predicate에 쓰이지 않아야 함.
	# show_result 호출부의 두 번째 인자가 위 패턴 외에 다른 비교를 쓰는지 grep.
	var idx := content.find("show_result(result,")
	if idx < 0:
		_fail("show_result(result, ...) call not found")
		return
	# 동일 호출 라인에서 `>=` 또는 `>` 사용 금지 (`==`만 허용).
	var end_idx := content.find(")", idx)
	var call_substr := content.substr(idx, end_idx - idx)
	if call_substr.contains(">=") or call_substr.contains(" > "):
		_fail("show_result(...) 라인에 `>=`/`>` 비교가 잔존: %s" % call_substr)
		return
	print("[SceneFlowLastStagePredicateTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SceneFlowLastStagePredicateTest] FAIL ", msg)
	get_tree().quit(1)
