extends Node

# Phase 5 contract test — REGISTRY ↔ canonical fixture ↔ InputMap 정합 검증.
#
# Canonical fixture는 plan partition SoT의 mirror. 이름 SoT는 docs/INPUT_PLAN.md §4.1+§4.2.
# REGISTRY 1차 SoT, 본 fixture는 mirror — drift 시 contract test fail.
#
# 검증 6단계:
#   1. REGISTRY → fixture 정확 set equality (synthetic + input_map 분리)
#   2. GameAction const → REGISTRY 누락 검출
#   3. REGISTRY size 일치 (1+21=22)
#   4. InputMap → fixture 정확 set equality (ui_* godot 내장 액션 필터링)
#   5. Negative fixture (legacy 이름 회귀 가드)
#   6. Deferred 가드 (phase 6/12/post-MVP 액션이 phase 5 InputMap에 leak 안 됨)
#   7. Union size 자기검증 (= CANONICAL_TOTAL_SIZE = 31)

const GameAction := preload("res://scripts/input/GameAction.gd")

# === Phase 5 등록 대상 (synthetic 1 + InputMap 21 = 22) ===
const CANONICAL_PHASE5_SYNTHETIC: Array[StringName] = [
	&"cursor_move",
]
const CANONICAL_PHASE5_INPUT_MAP: Array[StringName] = [
	&"skill_select_1", &"skill_select_2", &"skill_select_3", &"skill_select_4",
	&"skill_select_5", &"skill_select_6", &"skill_select_7", &"skill_select_8",
	&"skill_cycle_next", &"skill_cycle_prev",
	&"skill_assign", &"skill_cancel",
	&"target_next_ant", &"target_prev_ant",
	&"pause_toggle", &"step_frame", &"speed_toggle",
	&"restart_stage", &"release_rate_up", &"release_rate_down",
	&"info_toggle",
]
# === Phase 6 도입 예정 (CameraController 합류 시 KB InputMap + 패드 synthetic poll) ===
const CANONICAL_PHASE6_DEFERRED: Array[StringName] = [
	&"camera_pan", &"camera_zoom",
]
# === Phase 12 도입 예정 (메뉴 game state 분기) ===
const CANONICAL_PHASE12_DEFERRED: Array[StringName] = [
	&"back_menu",
]
# === Post-MVP (phase 21~22) — INPUT_PLAN §4.2 ===
const CANONICAL_POSTMVP_DEFERRED: Array[StringName] = [
	&"tap_drag_skill", &"pinch_zoom",
	&"rewind_hold", &"command_wheel_open", &"overlay_toggle", &"nuke",
]
const CANONICAL_TOTAL_SIZE: int = 31

# === Negative fixture (legacy 이름 회귀 가드) ===
const LEGACY_NAMES: Array[StringName] = [
	&"skill_select_next", &"skill_select_prev",
	&"cursor_target_next_ant", &"cursor_target_prev_ant",
	&"speed_up", &"speed_normal",
	&"cursor_move_to",
]

# === Internal InputMap actions (Phase 7+) — Input.get_vector polling only, NOT GameAction.
# Phase 7: 패드 좌 스틱 polling용 4개. GameAction.REGISTRY에 등록하지 않으며,
# emit/connect 경로에 들어가지도 않음. case4/case6 검증에서 whitelist 처리. ===
const INTERNAL_INPUT_MAP_ACTIONS: Array[StringName] = [
	&"pad_cursor_left", &"pad_cursor_right",
	&"pad_cursor_up", &"pad_cursor_down",
]

# === GameAction 명시 const 리스트 (헬퍼/registry 제외, REGISTRY 누락 검출용) ===
const ALL_EMITTABLE_CONSTS: Array[StringName] = [
	GameAction.CURSOR_MOVE,
	GameAction.SKILL_SELECT_1, GameAction.SKILL_SELECT_2, GameAction.SKILL_SELECT_3, GameAction.SKILL_SELECT_4,
	GameAction.SKILL_SELECT_5, GameAction.SKILL_SELECT_6, GameAction.SKILL_SELECT_7, GameAction.SKILL_SELECT_8,
	GameAction.SKILL_CYCLE_NEXT, GameAction.SKILL_CYCLE_PREV,
	GameAction.SKILL_ASSIGN, GameAction.SKILL_CANCEL,
	GameAction.TARGET_NEXT_ANT, GameAction.TARGET_PREV_ANT,
	GameAction.PAUSE_TOGGLE, GameAction.STEP_FRAME, GameAction.SPEED_TOGGLE,
	GameAction.RESTART_STAGE, GameAction.RELEASE_RATE_UP, GameAction.RELEASE_RATE_DOWN,
	GameAction.INFO_TOGGLE,
]


func _ready() -> void:
	if not _case1_registry_to_fixture():
		_fail("case1: REGISTRY → fixture set equality")
		return
	if not _case2_const_to_registry():
		_fail("case2: GameAction const → REGISTRY 누락 검출")
		return
	if not _case3_registry_size():
		_fail("case3: REGISTRY size 일치")
		return
	if not _case4_inputmap_to_fixture():
		_fail("case4: InputMap → fixture set equality")
		return
	if not _case5_negative_legacy():
		_fail("case5: Negative fixture (legacy 이름 회귀 가드)")
		return
	if not _case6_deferred_guard():
		_fail("case6: Deferred 가드")
		return
	if not _case7_union_size():
		_fail("case7: Union size 자기검증")
		return
	print("[GameActionContract] PASS")
	get_tree().quit(0)


func _case1_registry_to_fixture() -> bool:
	var registry_synthetic: Array[StringName] = []
	var registry_input_map: Array[StringName] = []
	for entry: Dictionary in GameAction.REGISTRY:
		var name: StringName = entry["name"]
		var kind: String = entry["kind"]
		if kind == "synthetic":
			registry_synthetic.append(name)
		elif kind == "input_map":
			registry_input_map.append(name)
		else:
			push_error("[GameActionContract] unknown kind: %s" % kind)
			return false
	return _set_equal(registry_synthetic, CANONICAL_PHASE5_SYNTHETIC) \
		and _set_equal(registry_input_map, CANONICAL_PHASE5_INPUT_MAP)


func _case2_const_to_registry() -> bool:
	var registry_names: Array[StringName] = []
	for entry: Dictionary in GameAction.REGISTRY:
		registry_names.append(entry["name"])
	for c: StringName in ALL_EMITTABLE_CONSTS:
		if not registry_names.has(c):
			push_error("[GameActionContract] const %s missing from REGISTRY" % c)
			return false
	return true


func _case3_registry_size() -> bool:
	var expected: int = CANONICAL_PHASE5_SYNTHETIC.size() + CANONICAL_PHASE5_INPUT_MAP.size()
	if GameAction.REGISTRY.size() != expected:
		push_error("[GameActionContract] REGISTRY size %d != expected %d" % [GameAction.REGISTRY.size(), expected])
		return false
	if expected != 22:
		push_error("[GameActionContract] expected size 22, got %d" % expected)
		return false
	return true


func _case4_inputmap_to_fixture() -> bool:
	var actual: Array[StringName] = []
	for action_name: StringName in InputMap.get_actions():
		var s: String = String(action_name)
		if s.begins_with("ui_"):
			continue
		# Phase 7 internal binding (Input.get_vector polling only) — REGISTRY 외 허용.
		if INTERNAL_INPUT_MAP_ACTIONS.has(action_name):
			continue
		actual.append(action_name)
	return _set_equal(actual, CANONICAL_PHASE5_INPUT_MAP)


func _case5_negative_legacy() -> bool:
	for legacy: StringName in LEGACY_NAMES:
		if InputMap.has_action(legacy):
			push_error("[GameActionContract] legacy action registered: %s" % legacy)
			return false
	return true


func _case6_deferred_guard() -> bool:
	var deferred: Array[StringName] = []
	deferred.append_array(CANONICAL_PHASE6_DEFERRED)
	deferred.append_array(CANONICAL_PHASE12_DEFERRED)
	deferred.append_array(CANONICAL_POSTMVP_DEFERRED)
	for d: StringName in deferred:
		if InputMap.has_action(d):
			push_error("[GameActionContract] deferred action leaked into phase 5 InputMap: %s" % d)
			return false
	return true


func _case7_union_size() -> bool:
	var total: int = CANONICAL_PHASE5_SYNTHETIC.size() \
		+ CANONICAL_PHASE5_INPUT_MAP.size() \
		+ CANONICAL_PHASE6_DEFERRED.size() \
		+ CANONICAL_PHASE12_DEFERRED.size() \
		+ CANONICAL_POSTMVP_DEFERRED.size()
	if total != CANONICAL_TOTAL_SIZE:
		push_error("[GameActionContract] union size %d != CANONICAL_TOTAL_SIZE %d" % [total, CANONICAL_TOTAL_SIZE])
		return false
	return true


func _set_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		push_error("[GameActionContract] size mismatch %d vs %d (a=%s b=%s)" % [a.size(), b.size(), a, b])
		return false
	for x in a:
		if not b.has(x):
			push_error("[GameActionContract] %s in a but not in b" % x)
			return false
	for x in b:
		if not a.has(x):
			push_error("[GameActionContract] %s in b but not in a" % x)
			return false
	return true


func _fail(case_label: String) -> void:
	push_error("[GameActionContract] FAIL %s" % case_label)
	print("[GameActionContract] FAIL %s" % case_label)
	get_tree().quit(1)
