extends Node

# skill-tile-surface Phase 4 — basher 2칸 높이 터널(머리공간) + 바닥 2-tier 검증.
# 두 축:
#   [UNIT] (_ready) Terrain 신규 메서드 계약:
#     - destroy_static_cookie_cell: 정적 사각 cookie만 제거(true), 동적/slope/공기는 보존(false).
#     - apply_under_surface_at: 정적 cookie BaseSprite를 under-surface로 재스킨(멱등), 비대상 no-op.
#   [INTEGRATION] (_physics_process) 실제 basher 주행 (2칸 벽 BasherStage):
#     - 벽 몸통행(12..15,21) + 머리행(12..15,20) 모두 제거(2칸 터널)
#     - 터널 바닥(12..15,22)에 CookieSurfaceCap
#     - 바닥 아래(12..15,23) BaseSprite = under-surface

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 11.0 * 32.0

var _ant: Ant = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null
var _stage: Node = null
var _unit_ok: bool = false

func _ready() -> void:
	_unit_ok = _run_unit_checks()
	if not _unit_ok:
		_fail("unit checks failed")
		return
	print("[BasherHeadroomTierTest] unit checks PASS; driver ready")

# ---------------- UNIT ----------------
func _build_terrain(tile_map: Dictionary) -> Terrain:
	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = tile_map
	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()
	return terrain

func _base_tex_path(terrain: Terrain, cell: Vector2i) -> String:
	if not terrain._static_bodies.has(cell):
		return ""
	var base: Sprite2D = (terrain._static_bodies[cell] as Node).get_node_or_null("BaseSprite") as Sprite2D
	if base == null or base.texture == null:
		return ""
	return String(base.texture.resource_path)

func _run_unit_checks() -> bool:
	var ok := true
	# --- destroy_static_cookie_cell ---
	var t := _build_terrain({"0,0": "solid", "1,0": "slope_left", "2,0": "solid"})
	t.add_tile(Vector2i(5, 0))   # 동적 타일
	if not t.destroy_static_cookie_cell(Vector2i(0, 0)):
		ok = _u("static cookie cell should be destroyed (true)");
	if t.get_cell_kind(Vector2i(0, 0)) != "":
		ok = _u("destroyed static cookie cell kind should be ''")
	if t.destroy_static_cookie_cell(Vector2i(1, 0)):
		ok = _u("slope cell must be preserved (false)")
	if t.get_cell_kind(Vector2i(1, 0)) != "earth":
		ok = _u("slope cell must remain after preserve")
	if t.destroy_static_cookie_cell(Vector2i(5, 0)):
		ok = _u("dynamic tile must be preserved (false)")
	if not t.has_tile(Vector2i(5, 0)):
		ok = _u("dynamic tile must remain after preserve")
	if t.destroy_static_cookie_cell(Vector2i(9, 9)):
		ok = _u("air cell must return false")
	t.get_parent().queue_free()

	# --- apply_under_surface_at ---
	# (0,0) 단독 solid → 위 비어 노출. base는 interior(background). under-surface로 재스킨되는지.
	var t2 := _build_terrain({"0,0": "solid", "1,0": "slope_left"})
	var before := _base_tex_path(t2, Vector2i(0, 0))
	t2.apply_under_surface_at(Vector2i(0, 0))
	var after := _base_tex_path(t2, Vector2i(0, 0))
	if not after.ends_with("cookie_tile_under_surface.png"):
		ok = _u("apply_under_surface_at should reskin BaseSprite to under-surface (got %s, was %s)" % [after, before])
	t2.apply_under_surface_at(Vector2i(0, 0))   # 멱등
	if _base_tex_path(t2, Vector2i(0, 0)) != after:
		ok = _u("apply_under_surface_at must be idempotent")
	# slope → no-op (no BaseSprite, no crash)
	t2.apply_under_surface_at(Vector2i(1, 0))
	t2.get_parent().queue_free()
	return ok

func _u(msg: String) -> bool:
	print("[BasherHeadroomTierTest] UNIT FAIL ", msg)
	return false

# ---------------- INTEGRATION ----------------
func _physics_process(_delta: float) -> void:
	if _result_emitted or not _unit_ok:
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
	print("[BasherHeadroomTierTest] applied basher at frame=%d" % _frame)

func _cap_count(body: Node) -> int:
	var n := 0
	for c in body.get_children():
		if c.name == Terrain.COOKIE_SURFACE_CAP_NAME:
			n += 1
	return n

func _poll_pass() -> void:
	if not _applied or _terrain == null:
		return
	# 벽 몸통행(12..15,21) 다 제거됐는지 먼저 확인.
	for x in range(12, 16):
		if _terrain.get_cell_kind(Vector2i(x, 21)) != "":
			return
	# (1) 머리행(12..15,20)도 제거(2칸 터널).
	for x in range(12, 16):
		if _terrain.get_cell_kind(Vector2i(x, 20)) != "":
			_fail("headroom cell (%d,20) not removed (2-tall tunnel expected)" % x)
			return
	# (2) 터널 바닥(12..15,22) surface 캡.
	for x in range(12, 16):
		var fcell := Vector2i(x, 22)
		if not _terrain._static_bodies.has(fcell):
			_fail("floor body missing at %s" % str(fcell)); return
		if _cap_count(_terrain._static_bodies[fcell]) != 1:
			_fail("floor %s surface cap count != 1" % str(fcell)); return
	# (3) 바닥 아래(12..15,23) BaseSprite = under-surface.
	for x in range(12, 16):
		var ucell := Vector2i(x, 23)
		if not _terrain._static_bodies.has(ucell):
			_fail("under body missing at %s" % str(ucell)); return
		var base: Sprite2D = (_terrain._static_bodies[ucell] as Node).get_node_or_null("BaseSprite") as Sprite2D
		if base == null or base.texture == null or not String(base.texture.resource_path).ends_with("cookie_tile_under_surface.png"):
			_fail("under cell %s BaseSprite not under-surface" % str(ucell)); return
	print("[BasherHeadroomTierTest] PASS frame=%d — 2-tall tunnel + floor surface + under under-surface" % _frame)
	_result_emitted = true
	get_tree().quit(0)

func _fail(msg: String) -> void:
	push_error("[BasherHeadroomTierTest] FAIL: " + msg)
	print("[BasherHeadroomTierTest] FAIL ", msg)
	_result_emitted = true
	get_tree().quit(1)
