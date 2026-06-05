extends Node

# 발동 표지판 프로토타입 검증 (2026-06-05).
# 개미를 직접 탭하지 않고 SkillToolbar._place_sign로 타일에 sand_mound 표지판을 설치 →
# 그 열(column)에 처음 도착한 적격 개미가 SkillSign._physics_process에서 자동 발동 →
# 5칸 막대과자 사다리(mound) 건설 + 표지판 소비(queue_free).
# PASS: 표지판 설치 성공 AND tile_count==5 AND 잔존 SkillSign 0.

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 330.0   # cell 10 @ cs=32 — 개미 경로상 전방 셀

var _stage: Node = null
var _terrain: Terrain = null
var _toolbar: SkillToolbar = null
var _ant: Ant = null
var _placed: bool = false
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_failed.connect(_on_failed)
	print("[SandMoundSignTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_place_when_ready()
	_poll_built()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — frame=%d tile_count=%d signs=%d placed=%s" % [_frame, _tile_count(), _sign_count(), str(_placed)])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../SandMoundStage")
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
	# 개미가 표지판 열에 도달하기 전에 미리 설치 (전방에 표지판을 세워두는 흐름).
	if _ant.global_position.x >= TRIGGER_X:
		return
	var ok: bool = _toolbar._place_sign("sand_mound", Vector2(TRIGGER_X, _ant.global_position.y))
	if not ok:
		_fail("_place_sign returned false (cell occupied / no terrain)")
		return
	_placed = true
	print("[SandMoundSignTest] sign placed at frame=%d ant_x=%.1f signs=%d" % [_frame, _ant.global_position.x, _sign_count()])

func _poll_built() -> void:
	if not _placed:
		return
	if _tile_count() == 5 and _sign_count() == 0:
		print("[SandMoundSignTest] PASS tile_count=5 sign consumed frame=%d" % _frame)
		_done = true
		get_tree().quit(0)

func _tile_count() -> int:
	return _terrain.tile_count() if _terrain != null else -1

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
	if _tile_count() == 5 and _sign_count() == 0:
		print("[SandMoundSignTest] PASS (post-failed) reason=%s" % result["reason"])
		_done = true
		get_tree().quit(0)
		return
	_fail("stage_failed reason=%s tile_count=%d signs=%d" % [result["reason"], _tile_count(), _sign_count()])

func _fail(msg: String) -> void:
	print("[SandMoundSignTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
