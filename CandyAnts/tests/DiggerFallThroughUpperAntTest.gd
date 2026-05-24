extends Node

# Phase 18 essential test — D1 자연 분기 + D11 void termination 검증.
#
# 시나리오 (plan v10 §6.3):
# - Layout dev_basher_digger_chain_layout — upper floor y=22 + lower floor y=27 with column 10 hole.
# - ant_A: 첫 spawn(AntSpawner spawn order 0). spawn 후 walker로 우측 진행.
# - ant_B: 본 driver가 spawn 후 1.0s 시점에 cell (10,21)에 별도 spawn + **같은 physics frame**에서
#   WorkerState("digger") 즉시 적용 (plan §6.3 Mode A — same-frame spawn + apply, drift window 0 frame).
# - ant_B의 digger가 cell (10,22)을 frame N에 destroy → ant_A가 그 다음 physics tick 이후 (10,22)
#   위 진입 시 is_on_floor=false → WalkerState.update의 `_frame > 1 and not is_on_floor` 분기 →
#   FallerState (D1 자연 분기).
# - ant_B는 falling 중 WorkerState("digger") 유지(Option A). column 10 lower floor (10,27) hole이라
#   ant_B는 _off_floor_frames > DIGGER_OFF_FLOOR_LIMIT(=180) 초과 시 _aborted + FallerState 직접
#   전이 (D11 void termination).
#
# PASS (30s 내) — 5 criteria 모두 충족 시 quit(0). 위반 시 explicit reason _fail() + quit(1):
#  (1) cell_destroy_frame 기록 (대상 cell (10,22) literal — Mode A로 column 10 결정론적 보장)
#  (2) destroy+5 frame 시점 ant_B.state == WorkerState (Option A enforcement — falling 중 유지)
#  (3) ant_b_faller_frame 기록 (D11 void timeout으로 FallerState 전이)
#  (4) ant_b_faller_frame ∈ [destroy + DIGGER_OFF_FLOOR_LIMIT − 5, destroy + DIGGER_OFF_FLOOR_LIMIT + 5]
#      (D11 timing 정확도, ±5 frame)
#  (5) ant_a_faller_frame > cell_destroy_frame (D1 자연 분기 — 위쪽 ant fall-through)

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const PASS_TIMEOUT_FRAMES: int = 1800   # 30s @ 60fps — runner --quit-after 18000(=5min) 보다 짧음
const ANT_B_SPAWN_DELAY_FRAMES: int = 60   # 1.0s @ 60fps
const ANT_B_BODY_CELL: Vector2i = Vector2i(10, 21)
const TARGET_DESTROY_CELL: Vector2i = Vector2i(10, 22)
const FALLER_FRAME_TOLERANCE: int = 5

var _frame: int = 0
var _result_emitted: bool = false
var _stage: Node = null
var _terrain: Terrain = null
var _ant_a: Ant = null
var _ant_b: Ant = null
var _digger_applied: bool = false
var _ant_b_spawned: bool = false
var _cell_destroy_frame: int = -1
var _ant_b_state_at_destroy_plus_5_checked: bool = false
var _ant_b_state_at_destroy_plus_5_ok: bool = false
var _ant_b_faller_frame: int = -1
var _ant_a_faller_frame: int = -1
var _ant_a_prev_state: AntState = null
var _ant_b_prev_state: AntState = null

func _ready() -> void:
	print("[DiggerFallThroughUpperAntTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_spawn_and_apply_ant_b()
	_observe_destroy()
	_observe_state_transitions()
	_poll_pass()
	if _frame > PASS_TIMEOUT_FRAMES:
		_fail("hard timeout (30s) — destroy_frame=%d ant_b_faller=%d ant_a_faller=%d state_check=%s" % [
			_cell_destroy_frame, _ant_b_faller_frame, _ant_a_faller_frame, str(_ant_b_state_at_destroy_plus_5_ok)
		])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../ChainStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	# ant_A = 첫 spawn(spawn order 0). AntSpawner가 자동 spawn — group lookup.
	if _ant_a == null or not is_instance_valid(_ant_a):
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a != null and a != _ant_b:
				_ant_a = a
				break

func _spawn_and_apply_ant_b() -> void:
	# Mode A (plan v10 §6.3 요건 4): same physics frame에서 spawn + add_child + global_position 설정 +
	# state_machine.change_state(WorkerState.new("digger")) 모두 처리. drift window 0 frame 보장.
	# 요건 3 (one-shot, R7 fix): `not _digger_applied AND ant_b.state_machine.current_state is WalkerState`
	# (is_on_floor() 사전 가드 제거 — Mode A same-frame과 충돌하여 R5 drift 재발).
	if _digger_applied:
		return
	if _frame < ANT_B_SPAWN_DELAY_FRAMES:
		return
	if _stage == null or _terrain == null:
		return
	# spawn parent — ChainStage/World 노드(다른 ant들이 spawn된 곳).
	var world: Node = _stage.get_node_or_null("World")
	if world == null:
		return
	# Same physics frame: instantiate + add_child + pos 설정 + change_state.
	_ant_b = ANT_SCENE.instantiate()
	world.add_child(_ant_b)
	# body_cell (10, 21) → x = 10*32+16 = 336, y = 22*32 - 5 = 699 (feet at 22*32 floor top).
	_ant_b.global_position = Vector2(
		float(ANT_B_BODY_CELL.x) * 32.0 + 16.0,
		float(ANT_B_BODY_CELL.y + 1) * 32.0 - 5.0
	)
	_ant_b.direction = 1
	_ant_b_spawned = true
	# Ant._ready()가 state_machine.change_state(WalkerState.new())을 같은 add_child 호출 안에서 실행.
	# 따라서 이 시점 ant_b.state_machine.current_state is WalkerState. 즉시 digger 적용.
	if _ant_b.state_machine == null:
		_fail("ant_b state_machine null after instantiate")
		return
	if not (_ant_b.state_machine.current_state is WalkerState):
		# Ant._ready의 change_state 호출이 add_child 안에서 실행 → current_state 즉시 WalkerState.
		# 만약 그렇지 않다면 framework 가정 깨짐.
		_fail("ant_b not in WalkerState immediately after spawn (Mode A 전제 위반)")
		return
	# Mode B fallback: body_cell explicit assertion (drift 검출). Mode A 권장이지만 안전망.
	var bcx: int = int(floor(_ant_b.global_position.x / 32.0))
	var bcy: int = int(floor((_ant_b.global_position.y - 2.0) / 32.0))
	if bcx != ANT_B_BODY_CELL.x or bcy != ANT_B_BODY_CELL.y:
		_fail("ant_b drifted off (10,21) — H1-R5/R6 guard: body=(%d,%d)" % [bcx, bcy])
		return
	# One-shot digger application (R4 + R7 fix).
	_ant_b.state_machine.change_state(WorkerState.new("digger"))
	_digger_applied = true
	print("[DiggerFallThroughUpperAntTest] ant_b spawned + digger applied at frame=%d body_cell=(%d,%d)" % [_frame, bcx, bcy])

func _observe_destroy() -> void:
	# cell (10,22) destroy frame 추적. terrain.get_cell_kind 사용.
	if _cell_destroy_frame >= 0:
		return
	if _terrain == null:
		return
	if _terrain.get_cell_kind(TARGET_DESTROY_CELL) == "":
		# Destroy 발생 frame은 이 검사가 처음 false→true 전환되는 시점.
		# 정확히 frame N에 destroy됐다면 frame N+1의 _physics_process에서 검출됨.
		# 단순화: 첫 감지 frame을 destroy frame으로 기록 (1-frame 오차 허용 — 후속 검증은 ±5 tolerance).
		_cell_destroy_frame = _frame
		print("[DiggerFallThroughUpperAntTest] cell (10,22) destroy detected at frame=%d" % _frame)

func _observe_state_transitions() -> void:
	# ant_B Option A enforcement — destroy+5 frame 시점 WorkerState 검사.
	if _digger_applied and _cell_destroy_frame >= 0 and not _ant_b_state_at_destroy_plus_5_checked:
		if _frame >= _cell_destroy_frame + 5:
			if _ant_b != null and is_instance_valid(_ant_b) and _ant_b.state_machine != null:
				_ant_b_state_at_destroy_plus_5_ok = (_ant_b.state_machine.current_state is WorkerState)
			_ant_b_state_at_destroy_plus_5_checked = true
			print("[DiggerFallThroughUpperAntTest] destroy+5 ant_b state WorkerState=%s" % str(_ant_b_state_at_destroy_plus_5_ok))

	# ant_B FallerState 진입 frame 추적 (D11 void timeout).
	if _ant_b_faller_frame < 0 and _ant_b != null and is_instance_valid(_ant_b) and _ant_b.state_machine != null:
		var s_b: AntState = _ant_b.state_machine.current_state
		if s_b is FallerState:
			_ant_b_faller_frame = _frame
			print("[DiggerFallThroughUpperAntTest] ant_b → FallerState at frame=%d" % _frame)

	# ant_A FallerState 진입 frame 추적 (D1 자연 분기).
	if _ant_a_faller_frame < 0 and _ant_a != null and is_instance_valid(_ant_a) and _ant_a.state_machine != null:
		var s_a: AntState = _ant_a.state_machine.current_state
		if s_a is FallerState:
			_ant_a_faller_frame = _frame
			print("[DiggerFallThroughUpperAntTest] ant_a → FallerState at frame=%d" % _frame)

func _poll_pass() -> void:
	# 5 criteria 모두 충족 시 PASS.
	if _cell_destroy_frame < 0:
		return
	if not _ant_b_state_at_destroy_plus_5_checked:
		return
	if _ant_b_faller_frame < 0:
		return
	if _ant_a_faller_frame < 0:
		return
	# 모든 데이터 수집 완료 — gate 검사.
	# (2) destroy+5 ant_b WorkerState
	if not _ant_b_state_at_destroy_plus_5_ok:
		_fail("(2) destroy+5 frame 시점 ant_b state != WorkerState — Option A 위반")
		return
	# (4) ant_b_faller_frame ∈ [destroy + LIMIT − 5, destroy + LIMIT + 5]
	var limit_target: int = _cell_destroy_frame + WorkerState.DIGGER_OFF_FLOOR_LIMIT
	if _ant_b_faller_frame < limit_target - FALLER_FRAME_TOLERANCE or _ant_b_faller_frame > limit_target + FALLER_FRAME_TOLERANCE:
		_fail("(4) ant_b_faller_frame=%d outside [%d, %d] (destroy=%d LIMIT=%d) — D11 enforcement 위반" % [
			_ant_b_faller_frame, limit_target - FALLER_FRAME_TOLERANCE, limit_target + FALLER_FRAME_TOLERANCE,
			_cell_destroy_frame, WorkerState.DIGGER_OFF_FLOOR_LIMIT
		])
		return
	# (5) ant_a_faller_frame > cell_destroy_frame
	if _ant_a_faller_frame <= _cell_destroy_frame:
		_fail("(5) ant_a_faller_frame=%d <= cell_destroy_frame=%d — D1 자연 분기 위반" % [
			_ant_a_faller_frame, _cell_destroy_frame
		])
		return
	# 모든 criteria 통과.
	print("[DiggerFallThroughUpperAntTest] PASS destroy=%d ant_b_faller=%d ant_a_faller=%d" % [
		_cell_destroy_frame, _ant_b_faller_frame, _ant_a_faller_frame
	])
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[DiggerFallThroughUpperAntTest] FAIL: " + msg)
	_result_emitted = true
	get_tree().quit(1)
