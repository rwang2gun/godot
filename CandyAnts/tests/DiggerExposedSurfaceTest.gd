extends Node

# skill-tile-surface Phase 2 — digger가 파낸 칸 아래(새 윗면)에 cookie surface 캡을 입히는지 검증.
# 핵심:
#   (A) opt-in=true 경로(digger 등) → 아래 칸 solid earth면 surface 캡 1장 추가
#   (B) opt-in=false 경로(cutter 등 캡 비대상 호출처) → 아래 칸에 캡 미추가
#       (NOTE: basher는 Phase 3에서 opt-in=true로 캡함 — basher positive 계약은 BasherExposedSurfaceTest가 검증)
#   (C) 아래가 공기/비-earth면 no-op (크래시 없음)
#   (D) 멱등 — 같은 아래 칸에 재적용해도 캡 1장 유지

var _failed := false

func _ready() -> void:
	_test_digger_caps_below()
	_test_no_cap_when_optin_false()
	_test_air_below_is_noop()
	_test_cap_idempotent()
	_test_no_double_cap_over_existing_surface_sprite()
	_test_slope_below_not_capped()

	if _failed:
		get_tree().quit(1)
		return
	print("[DiggerExposedSurfaceTest] PASS")
	get_tree().quit(0)

# x=0 컬럼: (0,0) surface(visual-only), (0,1)(0,2)(0,3) solid earth.
func _build_column_terrain() -> Terrain:
	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = {"0,0": "surface", "0,1": "solid", "0,2": "solid", "0,3": "solid"}
	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()
	return terrain

func _below_body(terrain: Terrain, cell: Vector2i) -> Node2D:
	if terrain._static_bodies.has(cell):
		return terrain._static_bodies[cell] as Node2D
	if terrain._placed.has(cell):
		return terrain._placed[cell] as Node2D
	return null

func _cap_count(body: Node) -> int:
	if body == null:
		return -1
	var n := 0
	for c in body.get_children():
		if c.name == Terrain.COOKIE_SURFACE_CAP_NAME:
			n += 1
	return n

func _test_digger_caps_below() -> void:
	var terrain := _build_column_terrain()
	var ok := terrain.destroy_tile_at(Vector2i(0, 1), ["earth"], true)
	_expect(ok, "digger destroy of solid earth succeeds")
	var below := _below_body(terrain, Vector2i(0, 2))
	_expect(below != null, "below cell (0,2) body still present after destroying (0,1)")
	_expect(_cap_count(below) == 1, "digger adds exactly 1 surface cap to exposed below cell")
	terrain.get_parent().queue_free()

# opt-in=false 경로(cutter 등 캡 비대상 호출처) → 아래 칸에 캡 미추가. (Phase 3: basher는 이제 true로 캡함 —
# 이 케이스는 "false면 캡 안 함" 계약을 지킨다. basher positive 계약은 BasherExposedSurfaceTest가 검증.)
func _test_no_cap_when_optin_false() -> void:
	var terrain := _build_column_terrain()
	var ok := terrain.destroy_tile_at(Vector2i(0, 1), ["earth"])   # apply_below_surface_cap 생략 = false
	_expect(ok, "destroy with opt-in false succeeds")
	var below := _below_body(terrain, Vector2i(0, 2))
	_expect(below != null, "below cell present after opt-in-false destroy")
	_expect(_cap_count(below) == 0, "opt-in=false destroy must NOT cap below cell")
	terrain.get_parent().queue_free()

func _test_air_below_is_noop() -> void:
	var terrain := _build_column_terrain()
	# (0,3) 파괴 → 아래 (0,4)는 미등록(공기). 캡 미적용 + 크래시 없음.
	var ok := terrain.destroy_tile_at(Vector2i(0, 3), ["earth"], true)
	_expect(ok, "destroy of bottom earth cell succeeds")
	_expect(_below_body(terrain, Vector2i(0, 4)) == null, "no body below bottom cell")
	_expect(terrain.get_cell_kind(Vector2i(0, 4)) == "", "(0,4) is air — no cap target")
	terrain.get_parent().queue_free()

func _test_cap_idempotent() -> void:
	var terrain := _build_column_terrain()
	terrain.destroy_tile_at(Vector2i(0, 1), ["earth"], true)
	# 같은 아래 칸 재캡 — 멱등 헬퍼 경유. cap은 1장 유지.
	terrain._cap_exposed_below(Vector2i(0, 1))
	terrain._cap_exposed_below(Vector2i(0, 1))
	var below := _below_body(terrain, Vector2i(0, 2))
	_expect(_cap_count(below) == 1, "repeated cap on same exposed cell stays at 1 (idempotent)")
	terrain.get_parent().queue_free()

# codex Phase2 MEDIUM 1 — 빌드타임 SurfaceSprite가 이미 있는 정적 solid 위에 동적 bridge를 얹고
# 그 bridge를 digger로 파괴 → 아래 정적 solid는 이미 surface 시각이 있으므로 CookieSurfaceCap 미추가.
func _test_no_double_cap_over_existing_surface_sprite() -> void:
	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	var layout := StageLayoutData.new()
	layout.cell_size = 48
	# (5,5) 솔리드만 → 위(5,4) 비어 build 시 노출 → SurfaceSprite 부여.
	layout.tile_map = {"5,5": "solid"}
	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()
	var solid := terrain._static_bodies[Vector2i(5, 5)] as Node2D
	_expect(solid != null and solid.has_node("SurfaceSprite"), "build-time exposed solid has SurfaceSprite")
	# 동적 bridge를 (5,4)에 얹고 digger로 파괴.
	_expect(terrain.add_tile(Vector2i(5, 4)), "dynamic earth tile placed above exposed solid")
	terrain.destroy_tile_at(Vector2i(5, 4), ["earth"], true)
	_expect(_cap_count(solid) == 0, "no CookieSurfaceCap added when SurfaceSprite already present (no double-cap)")
	_expect(solid.has_node("SurfaceSprite"), "existing SurfaceSprite preserved")
	world.queue_free()

# codex Phase2 MEDIUM 2 — 아래 칸이 slope면(kind=earth여도) 사각 cookie 캡 미적용(범위 밖).
func _test_slope_below_not_capped() -> void:
	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = {"7,0": "solid", "7,1": "slope_left"}
	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()
	var slope := terrain._static_bodies[Vector2i(7, 1)] as Node2D
	_expect(slope != null, "slope body registered below")
	_expect(terrain.get_cell_kind(Vector2i(7, 1)) == "earth", "slope registers as earth kind")
	terrain.destroy_tile_at(Vector2i(7, 0), ["earth"], true)
	_expect(_cap_count(slope) == 0, "slope below destroyed cell must NOT receive a square cookie cap")
	world.queue_free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	print("[DiggerExposedSurfaceTest] FAIL ", message)
