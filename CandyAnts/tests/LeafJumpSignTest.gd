extends Node

# 나뭇잎 점프대 검증.
# 끈끈이(셀 15 @ cs=32) 직전 셀 14에 leaf_jump 점프대를 SkillToolbar._place_leaf_jump_pad로 직접 설치 →
# 그 열에 도착한 개미가 LeafJumpPad에서 Ant.leaf_jump_launch(4타일)로
# LeafJumpState 포물선 비행(낙하 모션) → 끈끈이를 공중으로 넘어(면역) 후방 사탕(x=816) 방향으로 착지·통과.
#
# PASS 조건(통과 시점에 즉시 quit): 점프대 설치 성공 AND 포물선 비행(LeafJumpState) 감지 AND 개미가
# 끈끈이 너머(x>=CROSS_X)로 전진 AND 통과 전까지 한 번도 is_stuck()이 아니었음.
# (점프 실패 시 개미가 끈끈이 셀 15를 밟아 is_stuck → 즉시 FAIL로 구분된다.)

const DEADLINE_FRAMES: int = 2400
const CELL_SIZE: int = 32
const TRIGGER_X: float = 464.0   # cell 14 @ cs=32 — 끈끈이(15) 직전, 개미 경로상 전방 셀
const CROSS_X: float = 600.0     # 끈끈이(셀 15, x≈496) 너머 — 4타일 비행 착지(셀 18, x≈592) 후 전진 확인선

var _stage: Node = null
var _terrain: Terrain = null
var _toolbar: SkillToolbar = null
var _ant: Ant = null
var _placed: bool = false
var _jumped: bool = false
var _crossed: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_failed.connect(_on_failed)
	print("[LeafJumpSignTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_place_when_ready()
	_poll()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — placed=%s jumped=%s crossed=%s signs=%d ant_x=%.1f" % [
			str(_placed), str(_jumped), str(_crossed), _pad_count(), _ant_x()])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../LeafJumpStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	if _toolbar == null and _stage != null:
		_toolbar = _stage.get_node_or_null("SkillToolbar") as SkillToolbar
	if _ant == null or not is_instance_valid(_ant):
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a != null:
				_ant = a
				return

func _place_when_ready() -> void:
	if _placed or _toolbar == null or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState) or not _ant.is_on_floor():
		return
	# 개미가 점프대 열에 도달하기 전에 미리 설치 (끈끈이 직전에 점프대를 세워두는 흐름).
	if _ant.global_position.x >= TRIGGER_X:
		return
	var ok: bool = _toolbar._place_leaf_jump_pad(Vector2(TRIGGER_X, _ant.global_position.y))
	if not ok:
		_fail("_place_leaf_jump_pad returned false (cell occupied / no terrain)")
		return
	_placed = true
	print("[LeafJumpSignTest] pad placed at frame=%d ant_x=%.1f pads=%d" % [
		_frame, _ant.global_position.x, _pad_count()])

func _poll() -> void:
	if _ant == null or not is_instance_valid(_ant):
		return
	var x: float = _ant.global_position.x
	# 통과(crossed) 전 끈끈이 정지는 점프 실패 신호 → FAIL.
	if not _crossed and _ant.is_stuck():
		_fail("ant stuck on sticky before crossing — leaf jump failed (x=%.1f frame=%d)" % [x, _frame])
		return
	# 포물선 비행(LeafJumpState) 진입 = 점프대 발동 증거.
	if _ant.state_machine != null and _ant.state_machine.current_state is LeafJumpState:
		if not _jumped:
			print("[LeafJumpSignTest] leaf jump (parabola) started at x=%.1f frame=%d" % [x, _frame])
		_jumped = true
	if x >= CROSS_X:
		_crossed = true
	if _placed and _jumped and _crossed:
		print("[LeafJumpSignTest] PASS — pad placed, parabola jump over sticky, crossed x=%.1f frame=%d" % [x, _frame])
		_done = true
		get_tree().quit(0)

func _ant_x() -> float:
	return _ant.global_position.x if (_ant != null and is_instance_valid(_ant)) else -1.0

func _pad_count() -> int:
	if _stage == null:
		return -1
	return _count_pads(_stage)

func _count_pads(n: Node) -> int:
	var c: int = 1 if n is LeafJumpPad else 0
	for child in n.get_children():
		c += _count_pads(child)
	return c

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	# 점프 성공 흐름이 이미 충족됐는데 stage_failed가 떠도(예: 단일 개미 시간초과) PASS 우선.
	if _placed and _jumped and _crossed:
		print("[LeafJumpSignTest] PASS (post-failed) reason=%s" % result.get("reason", "?"))
		_done = true
		get_tree().quit(0)
		return
	_fail("stage_failed reason=%s placed=%s jumped=%s crossed=%s" % [
		result.get("reason", "?"), str(_placed), str(_jumped), str(_crossed)])

func _fail(msg: String) -> void:
	print("[LeafJumpSignTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
