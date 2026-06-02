extends Node

# Basher 2칸 통로 굴착 + 단면 reskin 계약 검증 (2026-06-02).
# WorkerState._destroy_basher_cell이 전방 열(body_cell + (dir, ·))에 대해:
#   R   body  → 제거(필수)       R-1 위 → 제거(best-effort, earth면)
#   R+1 floor → basher root reskin   R-2 ceiling → basher top reskin (둘 다 시각만, kind 불변)
# 그리고 ant.x += dir*cs로 1칸 전진.
#
# 검증:
#  A. 통합 — 전방 4셀(body/위/floor/ceiling) 모두 earth+Sprite2D → body·위 제거, floor=root, ceiling=top, 전진.
#  B. best-effort — 위/floor/ceiling이 공기면 body만 제거+전진, reskin no-op, crash·잔존 없음.
#  C. reskin_cell_to_basher 오염 가드 — 동적 _placed 타일(bridge)에는 false + 무변경.
#  D. 오염 가드 — plant 정적 셀(kind="plant")에는 false + 무변경.
#  E. 오염 가드 — Sprite2D 없는 정적 셀(슬로프류)에는 false.
#  F. has_basher_texture — root/top 가용 true, 누락 face false.
#  G. 누락 텍스처 seam — _basher_tex_forced_missing이면 reskin honest false + 스프라이트 무변경.
#
# 대부분 유닛 스타일(Terrain만). A/B만 실제 Ant 인스턴스로 _destroy_basher_cell 1회 구동.

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const ROOT_TEX: String = "basher_root_square.png"
const TOP_TEX: String = "basher_top_square.png"
const BEFORE_TEX_PATH: String = "res://assets/sprites/terrain/usable_square/cookie_solid_rotatable_square_01.png"
const CS: int = 48

var _terrain: Terrain = null

func _ready() -> void:
	print("[BasherTwoTallReskinTest] driver ready")
	_terrain = Terrain.new()
	_terrain.name = "Terrain"   # _find_terrain(ant)가 이름으로 조회 (A/B).
	_terrain.set_cell_size(CS)
	add_child(_terrain)

	if not _test_full_two_tall():
		return
	if not _test_best_effort_air_neighbors():
		return
	if not _test_reskin_guard_dynamic():
		return
	if not _test_reskin_guard_plant():
		return
	if not _test_reskin_guard_no_sprite():
		return
	if not _test_texture_availability():
		return
	if not _test_missing_texture_seam():
		return

	print("[BasherTwoTallReskinTest] PASS (full 2-tall reskin · best-effort air · dynamic/plant/no-sprite no-reskin · texture availability · missing-texture honest-false)")
	get_tree().quit(0)

# A. 전방 4셀 모두 earth+Sprite2D — body·위 제거 / floor=root / ceiling=top / ant 1칸 전진.
func _test_full_two_tall() -> bool:
	var body_fwd: Vector2i = Vector2i(6, 5)
	var above_fwd: Vector2i = Vector2i(6, 4)
	var floor_fwd: Vector2i = Vector2i(6, 6)
	var ceil_fwd: Vector2i = Vector2i(6, 3)
	var floor_body: StaticBody2D = _register_earth_sprite(floor_fwd)
	var ceil_body: StaticBody2D = _register_earth_sprite(ceil_fwd)
	_register_earth_sprite(body_fwd)
	_register_earth_sprite(above_fwd)

	# body_cell (5,5), direction +1 → forward 열 x=6.
	var ant: Ant = ANT_SCENE.instantiate() as Ant
	add_child(ant)
	ant.global_position = Vector2(5 * CS + 24, 5 * CS + 24)
	ant.direction = 1
	var ws: WorkerState = WorkerState.new()
	ws._aborted = false
	ws._remaining = 12
	var x_before: float = ant.global_position.x
	ws._destroy_basher_cell(ant)

	if ws._aborted:
		return _fail("A: 정상 earth 전방인데 _aborted=true")
	if _terrain.get_cell_kind(body_fwd) != "" or _terrain.has_tile(body_fwd):
		return _fail("A: body 전방 %s 미제거 (kind=%s)" % [str(body_fwd), _terrain.get_cell_kind(body_fwd)])
	if _terrain.get_cell_kind(above_fwd) != "":
		return _fail("A: 위 전방 %s 미제거 (kind=%s)" % [str(above_fwd), _terrain.get_cell_kind(above_fwd)])
	# floor/ceiling: kind는 earth 유지(reskin은 시각만), 텍스처만 교체.
	if _terrain.get_cell_kind(floor_fwd) != "earth":
		return _fail("A: floor %s kind가 earth가 아님 (reskin이 점유/kind를 바꿈): %s" % [str(floor_fwd), _terrain.get_cell_kind(floor_fwd)])
	if not _tex_path(_first_sprite(floor_body)).ends_with(ROOT_TEX):
		return _fail("A: floor %s가 root로 reskin 안 됨: %s" % [str(floor_fwd), _tex_path(_first_sprite(floor_body))])
	if _terrain.get_cell_kind(ceil_fwd) != "earth":
		return _fail("A: ceiling %s kind가 earth가 아님: %s" % [str(ceil_fwd), _terrain.get_cell_kind(ceil_fwd)])
	if not _tex_path(_first_sprite(ceil_body)).ends_with(TOP_TEX):
		return _fail("A: ceiling %s가 top으로 reskin 안 됨: %s" % [str(ceil_fwd), _tex_path(_first_sprite(ceil_body))])
	if not is_equal_approx(ant.global_position.x, x_before + CS):
		return _fail("A: ant 전진 어긋남 — %f → %f (기대 +%d)" % [x_before, ant.global_position.x, CS])
	if ws._remaining != 11:
		return _fail("A: _remaining 12→%d (기대 11)" % ws._remaining)
	ant.queue_free()
	return true

# B. 위/floor/ceiling 공기 — body만 제거+전진, reskin no-op, crash·잔존 없음.
func _test_best_effort_air_neighbors() -> bool:
	var body_fwd: Vector2i = Vector2i(6, 10)
	var floor_fwd: Vector2i = Vector2i(6, 11)   # 등록 안 함 = 공기
	_register_earth_sprite(body_fwd)

	var ant: Ant = ANT_SCENE.instantiate() as Ant
	add_child(ant)
	ant.global_position = Vector2(5 * CS + 24, 10 * CS + 24)
	ant.direction = 1
	var ws: WorkerState = WorkerState.new()
	ws._aborted = false
	ws._remaining = 12
	var x_before: float = ant.global_position.x
	ws._destroy_basher_cell(ant)

	if ws._aborted:
		return _fail("B: body earth 전방인데 _aborted=true (best-effort 이웃 공기에 영향받음)")
	if _terrain.get_cell_kind(body_fwd) != "":
		return _fail("B: body 전방 %s 미제거" % str(body_fwd))
	if _terrain.get_cell_kind(floor_fwd) != "" or _terrain.has_tile(floor_fwd):
		return _fail("B: 공기 floor %s에 reskin이 셀을 생성함 (kind=%s)" % [str(floor_fwd), _terrain.get_cell_kind(floor_fwd)])
	if not is_equal_approx(ant.global_position.x, x_before + CS):
		return _fail("B: ant 전진 어긋남 — %f → %f" % [x_before, ant.global_position.x])
	ant.queue_free()
	return true

# C. 동적 _placed 타일(bridge)은 basher reskin 대상 아님 — false + 텍스처 무변경.
func _test_reskin_guard_dynamic() -> bool:
	var cell: Vector2i = Vector2i(20, 0)
	if not _terrain.add_tile(cell, Terrain.DYNAMIC_TILE_BRIDGE):
		return _fail("C: add_tile(bridge) 실패 — 사전조건 불충족")
	var sprite: Sprite2D = _dyn_sprite(cell)
	if sprite == null:
		return _fail("C: 동적 bridge 타일에 Sprite2D 없음 — 사전조건 불충족")
	var before: String = _tex_path(sprite)
	if _terrain.reskin_cell_to_basher(cell, Terrain.BASHER_FACE_ROOT):
		return _fail("C: 동적 bridge 타일 reskin이 true — cross-mechanic 오염")
	if _tex_path(sprite) != before or _tex_path(sprite).ends_with(ROOT_TEX):
		return _fail("C: 동적 bridge 스프라이트가 오염됨: %s" % _tex_path(sprite))
	return true

# D. plant 정적 셀(kind="plant")은 basher reskin 대상 아님 — false + 무변경.
func _test_reskin_guard_plant() -> bool:
	var cell: Vector2i = Vector2i(22, 0)
	var body: StaticBody2D = _make_static_with_sprite()
	add_child(body)
	_terrain.register_static_body(cell, body, "plant")
	var sprite: Sprite2D = _first_sprite(body)
	var before: String = _tex_path(sprite)
	if _terrain.reskin_cell_to_basher(cell, Terrain.BASHER_FACE_TOP):
		return _fail("D: plant 셀 reskin이 true — kind 게이트 실패")
	if _tex_path(sprite) != before or _tex_path(sprite).ends_with(TOP_TEX):
		return _fail("D: plant 스프라이트가 오염됨: %s" % _tex_path(sprite))
	return true

# E. Sprite2D 없는 정적 셀(슬로프류)은 reskin 대상 없음 — false.
func _test_reskin_guard_no_sprite() -> bool:
	var cell: Vector2i = Vector2i(24, 0)
	var body: StaticBody2D = _make_static_polygon_only()
	add_child(body)
	_terrain.register_static_body(cell, body, "earth")
	if _terrain.reskin_cell_to_basher(cell, Terrain.BASHER_FACE_ROOT):
		return _fail("E: Sprite2D 없는 정적 셀 reskin이 true — no-sprite 가드 실패")
	return true

# F. has_basher_texture — root/top 가용, 누락 face false.
func _test_texture_availability() -> bool:
	for face in [Terrain.BASHER_FACE_ROOT, Terrain.BASHER_FACE_TOP]:
		if not _terrain.has_basher_texture(face):
			return _fail("F: has_basher_texture(%s) false — basher asset 누락/미import" % face)
	if _terrain.has_basher_texture("__missing_face__"):
		return _fail("F: has_basher_texture(__missing_face__) true — 누락 face 검출 실패")
	return true

# G. 누락 텍스처 seam — reskin honest false + 스프라이트 무변경.
func _test_missing_texture_seam() -> bool:
	var cell: Vector2i = Vector2i(26, 0)
	var body: StaticBody2D = _make_static_with_sprite()
	add_child(body)
	_terrain.register_static_body(cell, body, "earth")
	var before: String = _tex_path(_first_sprite(body))
	_terrain._basher_tex_forced_missing["root"] = true
	if _terrain.reskin_cell_to_basher(cell, Terrain.BASHER_FACE_ROOT):
		return _fail("G: 누락 텍스처인데 reskin true — 거짓 성공")
	if _tex_path(_first_sprite(body)) != before:
		return _fail("G: 누락 텍스처 reskin이 스프라이트를 변경함: %s" % _tex_path(_first_sprite(body)))
	_terrain._basher_tex_forced_missing.erase("root")
	# seam 원복 후 정상 reskin 성공(원복 확인).
	if not _terrain.reskin_cell_to_basher(cell, Terrain.BASHER_FACE_ROOT):
		return _fail("G: seam 원복 후에도 reskin false — 원복 실패")
	return true

# --- helpers ---

func _register_earth_sprite(cell: Vector2i) -> StaticBody2D:
	var body: StaticBody2D = _make_static_with_sprite()
	add_child(body)
	_terrain.register_static_body(cell, body, "earth")
	return body

func _make_static_with_sprite() -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(CS, CS)
	shape.shape = rect
	body.add_child(shape)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load(BEFORE_TEX_PATH) as Texture2D
	body.add_child(sprite)
	return body

func _make_static_polygon_only() -> StaticBody2D:
	var body: StaticBody2D = StaticBody2D.new()
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(CS, CS), Vector2(0, CS)])
	body.add_child(poly)
	var vis: Polygon2D = Polygon2D.new()
	vis.polygon = PackedVector2Array([Vector2(0, 0), Vector2(CS, CS), Vector2(0, CS)])
	body.add_child(vis)
	return body

func _dyn_sprite(cell: Vector2i) -> Sprite2D:
	if not _terrain._placed.has(cell):
		return null
	return _first_sprite(_terrain._placed[cell])

func _first_sprite(body_v: Variant) -> Sprite2D:
	var body: Node = body_v as Node
	if body == null:
		return null
	for ch in body.get_children():
		if ch is Sprite2D:
			return ch as Sprite2D
	return null

func _tex_path(sprite: Sprite2D) -> String:
	if sprite == null or sprite.texture == null:
		return ""
	return String(sprite.texture.resource_path)

func _fail(msg: String) -> bool:
	print("[BasherTwoTallReskinTest] FAIL %s" % msg)
	get_tree().quit(1)
	return false
