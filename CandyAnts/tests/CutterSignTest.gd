extends Node

# 발동 표지판 프로토타입 검증 — cutter (2026-06-05).
# 개미를 직접 탭하지 않고 SkillToolbar._place_sign로 "식물벽 앞 셀"(11,21)에 cutter 표지판 설치 →
# 도착 개미가 CutterSkill.apply(전방 식물벽 직면이면 즉시 절단, 열림이면 armed 후 벽 도달 시 자동 절단) →
# 식물벽 4칸(12,21)..(15,21) 제거 + 표지판 소비(queue_free).
# PASS: 표지판 설치 성공 AND 식물벽 4칸 모두 비점유 AND 잔존 SkillSign 0.

const DEADLINE_FRAMES: int = 2400
const SIGN_X: float = 11.0 * 32.0 + 16.0   # cell 11 중앙 — 식물벽(cell 12) 직전
const WALL_CELLS: Array[Vector2i] = [Vector2i(12, 21), Vector2i(13, 21), Vector2i(14, 21), Vector2i(15, 21)]

var _stage: Node = null
var _terrain: Terrain = null
var _toolbar: SkillToolbar = null
var _ant: Ant = null
var _placed: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_failed.connect(_on_failed)
	print("[CutterSignTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_place_when_ready()
	_poll_cut()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — frame=%d wall_open=%d signs=%d placed=%s" % [_frame, _walls_open(), _sign_count(), str(_placed)])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../CutterStage")
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
	# 개미가 벽 앞에 도달하기 전에 표지판을 미리 세워둔다.
	if _ant.global_position.x >= SIGN_X:
		return
	var ok: bool = _toolbar._place_sign("cutter", Vector2(SIGN_X, _ant.global_position.y))
	if not ok:
		_fail("_place_sign returned false (cell occupied / no terrain)")
		return
	_placed = true
	print("[CutterSignTest] sign placed at frame=%d ant_x=%.1f signs=%d" % [_frame, _ant.global_position.x, _sign_count()])

func _poll_cut() -> void:
	if not _placed:
		return
	if _walls_open() == WALL_CELLS.size() and _sign_count() == 0:
		print("[CutterSignTest] PASS walls removed + sign consumed frame=%d" % _frame)
		_done = true
		get_tree().quit(0)

# 제거된(비점유) 식물벽 셀 수.
func _walls_open() -> int:
	if _terrain == null:
		return -1
	var n: int = 0
	for c in WALL_CELLS:
		if not _terrain.is_cell_occupied(c):
			n += 1
	return n

func _sign_count() -> int:
	if _stage == null:
		return -1
	return _count_signs(_stage)

func _count_signs(n: Node) -> int:
	var c: int = 1 if n is SkillSign else 0
	for child in n.get_children():
		c += _count_signs(child)
	return c

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	if _walls_open() == WALL_CELLS.size() and _sign_count() == 0:
		print("[CutterSignTest] PASS (post-failed) reason=%s" % result["reason"])
		_done = true
		get_tree().quit(0)
		return
	_fail("stage_failed reason=%s wall_open=%d signs=%d" % [result["reason"], _walls_open(), _sign_count()])

func _fail(msg: String) -> void:
	print("[CutterSignTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
