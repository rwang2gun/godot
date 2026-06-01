extends Node

# skill-tile-surface Phase 3 — basher가 가로 터널을 뚫으면 뚫린 칸 아래(터널 바닥)가 새 walkable 윗면이
# 되어 cookie surface 캡을 받는지, 실제 basher 주행으로 검증 (BasherTunnelThroughWallTest 시나리오 재사용).
# BasherWallTest: 벽 (12..15,21) 위를 개미가 걷다 직면 → basher → 벽 제거. 벽 아래 바닥 (12..15,22)은 solid.
#
# PASS (30s 내):
#  (1) 벽 cell (12..15,21) 4개 제거(kind=="") — basher 동작 회귀
#  (2) 터널 바닥 (12..15,22) 각 static body에 CookieSurfaceCap 정확히 1장 (Phase 3 신계약)

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 11.0 * 32.0

var _ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null
var _stage: Node = null

func _ready() -> void:
	print("[BasherExposedSurfaceTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_poll_pass()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline exceeded — applied=%s" % str(_applied))

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../BasherStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_ant = a
			return

func _apply_when_ready() -> void:
	if _applied or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	var skill: BasherSkill = BasherSkill.new()
	if not skill.can_apply(_ant):
		return
	skill.apply(_ant)
	_applied = true
	print("[BasherExposedSurfaceTest] applied basher at frame=%d" % _frame)

func _poll_pass() -> void:
	if not _applied or _terrain == null:
		return
	# (1) 벽 4개 제거 확인.
	for x in range(12, 16):
		if _terrain.get_cell_kind(Vector2i(x, 21)) != "":
			return   # 아직 다 안 뚫림
	# (2) 터널 바닥 (12..15,22)에 CookieSurfaceCap 1장씩.
	for x in range(12, 16):
		var floor_cell: Vector2i = Vector2i(x, 22)
		var body: Node = null
		if _terrain._static_bodies.has(floor_cell) and is_instance_valid(_terrain._static_bodies[floor_cell]):
			body = _terrain._static_bodies[floor_cell]
		if body == null:
			_fail("tunnel floor body missing at %s" % str(floor_cell))
			return
		var caps: int = 0
		for c in body.get_children():
			if c.name == Terrain.COOKIE_SURFACE_CAP_NAME:
				caps += 1
		if caps != 1:
			_fail("tunnel floor %s has %d surface caps (need 1)" % [str(floor_cell), caps])
			return
	print("[BasherExposedSurfaceTest] PASS frame=%d — tunnel floor capped" % _frame)
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[BasherExposedSurfaceTest] FAIL: " + msg)
	print("[BasherExposedSurfaceTest] FAIL ", msg)
	_result_emitted = true
	get_tree().quit(1)
