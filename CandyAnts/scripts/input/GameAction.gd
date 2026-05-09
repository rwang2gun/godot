class_name GameAction
extends RefCounted

# 매직 스트링 차단 SoT. 모든 emit/connect는 본 const만 사용.
# 이름 SoT: docs/INPUT_PLAN.md §4.1+§4.2 / partition SoT: phases/mvp/plans/phase05-plan.md.
# REGISTRY 1차 SoT, GameActionContractTest fixture는 mirror — drift 시 contract test fail.

# === Synthetic (InputMap 미등록, InputRouter가 raw event/poll에서 직접 emit) ===
const CURSOR_MOVE         := &"cursor_move"

# === InputMap-registered (phase 5 KB+Mouse) ===
const SKILL_SELECT_1      := &"skill_select_1"
const SKILL_SELECT_2      := &"skill_select_2"
const SKILL_SELECT_3      := &"skill_select_3"
const SKILL_SELECT_4      := &"skill_select_4"
const SKILL_SELECT_5      := &"skill_select_5"
const SKILL_SELECT_6      := &"skill_select_6"
const SKILL_SELECT_7      := &"skill_select_7"
const SKILL_SELECT_8      := &"skill_select_8"
const SKILL_CYCLE_NEXT    := &"skill_cycle_next"
const SKILL_CYCLE_PREV    := &"skill_cycle_prev"
const SKILL_ASSIGN        := &"skill_assign"
const SKILL_CANCEL        := &"skill_cancel"
const TARGET_NEXT_ANT     := &"target_next_ant"
const TARGET_PREV_ANT     := &"target_prev_ant"
const PAUSE_TOGGLE        := &"pause_toggle"
const STEP_FRAME          := &"step_frame"
const SPEED_TOGGLE        := &"speed_toggle"
const RESTART_STAGE       := &"restart_stage"
const RELEASE_RATE_UP     := &"release_rate_up"
const RELEASE_RATE_DOWN   := &"release_rate_down"
const INFO_TOGGLE         := &"info_toggle"

# === 헬퍼 — slot index → SKILL_SELECT_n ===
const SKILL_SELECT_BY_SLOT: Array[StringName] = [
	SKILL_SELECT_1, SKILL_SELECT_2, SKILL_SELECT_3, SKILL_SELECT_4,
	SKILL_SELECT_5, SKILL_SELECT_6, SKILL_SELECT_7, SKILL_SELECT_8,
]

# === 위치 동반 액션 분류 — payload validity 가드 강제 SoT ===
const POSITIONAL_ACTIONS: Array[StringName] = [
	CURSOR_MOVE, SKILL_ASSIGN, TARGET_NEXT_ANT, TARGET_PREV_ANT,
]

static func is_positional(name: StringName) -> bool:
	return POSITIONAL_ACTIONS.has(name)

# === Contract registry (test_GameAction.gd가 본 표 vs InputMap 정합 검증) ===
# 각 entry: {name, kind, exact_match}
# - kind ∈ {"input_map", "synthetic"}
#   - "input_map" → InputMap.has_action(name) 반드시 true
#   - "synthetic" → InputMap.has_action(name) 반드시 false (router 내부 emit만)
# - exact_match: bool — _dispatch_input_map_action에서 is_action_pressed(name, false, exact_match)로 사용
#   - true: 모디파이어 정확 매치 필요 (target_*_ant Tab/Shift+Tab 분리, restart_stage Ctrl+R 정확)
#   - false: 모디파이어 톨러런트 (Ctrl+click도 skill_assign, Shift+1도 skill_select_1 등)
const REGISTRY: Array[Dictionary] = [
	{"name": CURSOR_MOVE,        "kind": "synthetic", "exact_match": false},
	{"name": SKILL_SELECT_1,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_SELECT_2,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_SELECT_3,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_SELECT_4,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_SELECT_5,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_SELECT_6,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_SELECT_7,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_SELECT_8,     "kind": "input_map", "exact_match": false},
	{"name": SKILL_CYCLE_NEXT,   "kind": "input_map", "exact_match": false},
	{"name": SKILL_CYCLE_PREV,   "kind": "input_map", "exact_match": false},
	{"name": SKILL_ASSIGN,       "kind": "input_map", "exact_match": false},
	{"name": SKILL_CANCEL,       "kind": "input_map", "exact_match": false},
	{"name": TARGET_NEXT_ANT,    "kind": "input_map", "exact_match": true},
	{"name": TARGET_PREV_ANT,    "kind": "input_map", "exact_match": true},
	{"name": PAUSE_TOGGLE,       "kind": "input_map", "exact_match": false},
	{"name": STEP_FRAME,         "kind": "input_map", "exact_match": false},
	{"name": SPEED_TOGGLE,       "kind": "input_map", "exact_match": false},
	{"name": RESTART_STAGE,      "kind": "input_map", "exact_match": true},
	{"name": RELEASE_RATE_UP,    "kind": "input_map", "exact_match": false},
	{"name": RELEASE_RATE_DOWN,  "kind": "input_map", "exact_match": false},
	{"name": INFO_TOGGLE,        "kind": "input_map", "exact_match": false},
]
