extends Node

# skill-tile-surface Phase 1 — Terrain cookie 3-tier surface 스킨 인프라 단위 테스트.
# 검증: (1) StageLayoutBuilder.build()이 cookie surface 텍스처를 Terrain에 등록
#       (2) apply_cookie_surface_overlay가 CookieSurfaceCap sprite를 셀 크기 region으로 추가
#       (3) 멱등 — 중복 호출 시 cap 1장 유지
#       (4) geometry 인자 — narrow 캡(작은 region/offset) 정합
#       (5) null-safe — 미등록 Terrain은 no-op(null 반환, 자식 미추가)

var _failed := false

func _ready() -> void:
	_test_texture_registration()
	_test_overlay_default_cell_sized()
	_test_overlay_idempotent()
	_test_overlay_narrow_cap_geometry()
	_test_overlay_null_safe_when_unregistered()

	if _failed:
		get_tree().quit(1)
		return
	print("[CookieSurfaceOverlayTest] PASS")
	get_tree().quit(0)

func _build_registered_terrain() -> Terrain:
	var world := Node2D.new()
	add_child(world)
	var terrain := Terrain.new()
	terrain.name = "Terrain"
	world.add_child(terrain)
	var layout := StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = {"0,0": "surface", "0,1": "solid", "0,2": "solid"}
	var builder := StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)
	builder.build()
	return terrain

func _test_texture_registration() -> void:
	var terrain := _build_registered_terrain()
	var surf := terrain.get_cookie_surface_texture()
	_expect(surf != null, "cookie surface texture registered after build")
	if surf != null:
		_expect(surf.resource_path.ends_with("cookie_tile_surface.png"), "registered surface is cookie_tile_surface.png")
	_expect(terrain.get_cookie_under_texture() != null, "cookie under texture registered")
	_expect(terrain.get_cookie_background_texture() != null, "cookie background texture registered")
	terrain.get_parent().queue_free()

func _make_body(terrain: Terrain) -> StaticBody2D:
	var body := StaticBody2D.new()
	terrain.add_child(body)
	return body

func _cap_children(body: Node) -> int:
	var n := 0
	for c in body.get_children():
		if c.name == Terrain.COOKIE_SURFACE_CAP_NAME:
			n += 1
	return n

func _test_overlay_default_cell_sized() -> void:
	var terrain := _build_registered_terrain()
	var body := _make_body(terrain)
	var cap := terrain.apply_cookie_surface_overlay(body, Vector2i(0, 0))
	_expect(cap != null, "overlay returns a Sprite2D when registered")
	_expect(body.has_node(Terrain.COOKIE_SURFACE_CAP_NAME), "overlay adds CookieSurfaceCap child")
	if cap != null:
		_expect(cap.region_enabled, "cap uses cookie horizontal atlas region")
		# cell_size=48, surface 텍스처 높이 48 → region 정사각 48.
		_expect(cap.region_rect.size == Vector2(48, 48), "default cap region is cell-sized square")
		_expect(cap.position.is_equal_approx(Vector2.ZERO), "default cap centered on body")
	terrain.get_parent().queue_free()

func _test_overlay_idempotent() -> void:
	var terrain := _build_registered_terrain()
	var body := _make_body(terrain)
	terrain.apply_cookie_surface_overlay(body, Vector2i(0, 0))
	terrain.apply_cookie_surface_overlay(body, Vector2i(0, 0))
	terrain.apply_cookie_surface_overlay(body, Vector2i(0, 0))
	_expect(_cap_children(body) == 1, "repeated overlay keeps exactly 1 cap (idempotent)")
	terrain.get_parent().queue_free()

func _test_overlay_narrow_cap_geometry() -> void:
	var terrain := _build_registered_terrain()
	var body := _make_body(terrain)
	# bridge용 narrow 캡: 윗면 16px만 덮고 위로 올림.
	var cap := terrain.apply_cookie_surface_overlay(body, Vector2i(0, 0), Vector2(48, 16), Vector2(0, -16), 2)
	_expect(cap != null, "narrow cap created")
	if cap != null:
		_expect(cap.region_rect.size == Vector2(48, 16), "narrow cap region reflects requested size")
		_expect(cap.position.is_equal_approx(Vector2(0, -16)), "narrow cap honors local_offset")
		_expect(cap.z_index == 2, "narrow cap honors z_index")
	terrain.get_parent().queue_free()

func _test_overlay_null_safe_when_unregistered() -> void:
	var terrain := Terrain.new()
	add_child(terrain)
	var body := StaticBody2D.new()
	terrain.add_child(body)
	var cap := terrain.apply_cookie_surface_overlay(body, Vector2i(0, 0))
	_expect(cap == null, "unregistered terrain returns null (no-op)")
	_expect(_cap_children(body) == 0, "unregistered terrain adds no cap child")
	terrain.queue_free()

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	print("[CookieSurfaceOverlayTest] FAIL ", message)
