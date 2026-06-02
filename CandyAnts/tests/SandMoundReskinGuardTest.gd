extends Node

# biscuit-ladder reskin 가드 회귀 (codex 2026-06-02) —
# (HIGH R1) reskin_cell_to_ladder는 동적 _placed 타일(bridge/stair/rung)을 절대 root/top으로 덮어쓰면 안 된다.
#           개미가 동적 타일 위/안에서 시전해도 그 스프라이트가 오염되지 않아야 한다.
# (HIGH R2) plant 정적 셀(kind="plant", PlantVisual Sprite2D 보유)도 reskin 대상이 아니다 → false, 오염 금지.
# (MEDIUM R1) Sprite2D 자식이 없는 정적 셀(슬로프 Polygon2D 등)은 cap 불가 → reskin false.
# (MEDIUM R3) cap atomicity — WorkerState._can_cap_ledge는 (a)레지 점유 (b)위 빈칸 (c)body_cell 비어있음
#             (d)above가 earth cap 가능, 4조건 전부일 때만 true. body_cell 점유 시 false(반쪽 cap 방지).
# (MEDIUM R4) 실패한 cast는 root를 안 남긴다 — cap 불가 레지 아래서 시전 → 즉시 abort → 발밑 floor 무변경.
# (MEDIUM R5/R6) tier 텍스처 가용성 — 누락 tier는 has_ladder_texture false + reskin honest false(무변경).
#             cap preflight(_can_cap_ledge)는 MIDDLE+TOP 텍스처 둘 다 가용해야 진입(없으면 반쪽 commit 차단).
# (positive) kind="earth" + 직접 Sprite2D 자식을 가진 정적 지형 셀만 reskin 성공.
#
# 대부분 유닛 스타일(Terrain만) — R4만 실제 Ant 인스턴스로 _place_sand_mound_tile 1회 구동.

const ROOT_TEX: String = "biscuit_ladder_root_square.png"
const MIDDLE_TEX: String = "biscuit_ladder_middle_square.png"
const TOP_TEX: String = "biscuit_ladder_top_square.png"
const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")

func _ready() -> void:
	print("[SandMoundReskinGuardTest] driver ready")
	var terrain: Terrain = Terrain.new()
	terrain.name = "Terrain"   # _find_terrain(ant)가 이름으로 조회 (R4 케이스).
	terrain.set_cell_size(48)
	add_child(terrain)

	# --- (HIGH) 동적 bridge 타일은 reskin 대상 아님 ---
	var bridge_cell: Vector2i = Vector2i(0, 0)
	if not terrain.add_tile(bridge_cell, Terrain.DYNAMIC_TILE_BRIDGE):
		_fail("add_tile(bridge) 실패 — 사전조건 불충족")
		return
	var bridge_sprite: Sprite2D = _dyn_sprite(terrain, bridge_cell)
	if bridge_sprite == null:
		_fail("bridge 동적 타일에 Sprite2D 없음 — 사전조건 불충족")
		return
	var bridge_path_before: String = _tex_path(bridge_sprite)
	if terrain.reskin_cell_to_ladder(bridge_cell, Terrain.LADDER_TIER_ROOT):
		_fail("reskin이 동적 bridge 타일에 성공(true) — cross-mechanic 오염 가드 실패")
		return
	if _tex_path(bridge_sprite).ends_with(ROOT_TEX):
		_fail("동적 bridge 스프라이트가 root로 오염됨")
		return
	if _tex_path(bridge_sprite) != bridge_path_before:
		_fail("동적 bridge 스프라이트 텍스처가 변경됨: %s" % _tex_path(bridge_sprite))
		return

	# --- (positive) 직접 Sprite2D 자식을 가진 정적 지형 셀은 reskin 성공 ---
	var surf_cell: Vector2i = Vector2i(2, 0)
	var surf_body: StaticBody2D = _make_static_with_sprite()
	add_child(surf_body)
	terrain.register_static_body(surf_cell, surf_body, "earth")
	if not terrain.reskin_cell_to_ladder(surf_cell, Terrain.LADDER_TIER_TOP):
		_fail("정적 지형 셀 reskin 실패(false) — top cap 불가")
		return
	var surf_sprite: Sprite2D = _first_sprite(surf_body)
	if surf_sprite == null or not _tex_path(surf_sprite).ends_with(TOP_TEX):
		_fail("정적 지형 셀이 top으로 reskin되지 않음: %s" % _tex_path(surf_sprite))
		return

	# --- (HIGH R2) plant 정적 셀(kind="plant" + Sprite2D)은 reskin 대상 아님 ---
	var plant_cell: Vector2i = Vector2i(6, 0)
	var plant_body: StaticBody2D = _make_static_with_sprite()
	add_child(plant_body)
	terrain.register_static_body(plant_cell, plant_body, "plant")
	var plant_sprite: Sprite2D = _first_sprite(plant_body)
	var plant_path_before: String = _tex_path(plant_sprite)
	if terrain.reskin_cell_to_ladder(plant_cell, Terrain.LADDER_TIER_TOP):
		_fail("plant 정적 셀 reskin이 성공(true) — kind 게이트 실패 (cross-mechanic 오염)")
		return
	if _tex_path(plant_sprite).ends_with(TOP_TEX) or _tex_path(plant_sprite).ends_with(ROOT_TEX):
		_fail("plant 스프라이트가 사다리 텍스처로 오염됨: %s" % _tex_path(plant_sprite))
		return
	if _tex_path(plant_sprite) != plant_path_before:
		_fail("plant 스프라이트 텍스처가 변경됨: %s" % _tex_path(plant_sprite))
		return

	# --- (MEDIUM) Sprite2D 자식이 없는 정적 셀(슬로프류)은 cap 불가 ---
	var slope_cell: Vector2i = Vector2i(4, 0)
	var slope_body: StaticBody2D = _make_static_polygon_only()
	add_child(slope_body)
	terrain.register_static_body(slope_cell, slope_body, "earth")
	if terrain.reskin_cell_to_ladder(slope_cell, Terrain.LADDER_TIER_TOP):
		_fail("Sprite2D 없는 정적 셀 reskin이 성공(true) — slope cap 가드 실패")
		return

	# --- (predicate) can_reskin_cell_to_ladder는 부작용 없이 적격성만 반환 ---
	var probe_cell: Vector2i = Vector2i(8, 0)
	var probe_body: StaticBody2D = _make_static_with_sprite()
	add_child(probe_body)
	terrain.register_static_body(probe_cell, probe_body, "earth")
	var probe_before: String = _tex_path(_first_sprite(probe_body))
	if not terrain.can_reskin_cell_to_ladder(probe_cell):
		_fail("can_reskin_cell_to_ladder false on earth+Sprite 셀")
		return
	if _tex_path(_first_sprite(probe_body)) != probe_before:
		_fail("can_reskin_cell_to_ladder가 텍스처를 변경함 — 부작용 있음")
		return

	# --- (MEDIUM R3) cap atomicity: WorkerState._can_cap_ledge 4조건 ---
	# (A) 적격: 레지 earth+Sprite + 위 빈칸 + body_cell 비어있음 → true.
	_setup_ledge(terrain, Vector2i(10, 4), "earth")
	if not WorkerState._can_cap_ledge(terrain, Vector2i(10, 5)):
		_fail("_can_cap_ledge false on eligible ledge (body_cell free, earth top)")
		return
	# (B) body_cell 점유 → false (codex R3: rung 없는 반쪽 cap + 개미 텔레포트 방지).
	_setup_ledge(terrain, Vector2i(12, 4), "earth")
	if not terrain.add_tile(Vector2i(12, 5), Terrain.DYNAMIC_TILE_BRIDGE):
		_fail("setup: body_cell 점유 실패")
		return
	if WorkerState._can_cap_ledge(terrain, Vector2i(12, 5)):
		_fail("_can_cap_ledge true while body_cell occupied — 반쪽 cap 위험")
		return
	# (C) 위도 막힌 solid 벽(above-above 점유) → false.
	_setup_ledge(terrain, Vector2i(14, 4), "earth")
	_setup_ledge(terrain, Vector2i(14, 3), "earth")
	if WorkerState._can_cap_ledge(terrain, Vector2i(14, 5)):
		_fail("_can_cap_ledge true on solid wall (above-above occupied)")
		return
	# (D) plant 레지 → false (cap 불가, cross-mechanic).
	_setup_ledge(terrain, Vector2i(16, 4), "plant")
	if WorkerState._can_cap_ledge(terrain, Vector2i(16, 5)):
		_fail("_can_cap_ledge true on plant ledge — cross-mechanic cap 위험")
		return

	# --- (MEDIUM R5) tier 텍스처 가용성: 누락 tier는 정직하게 false + 스프라이트 무변경 ---
	for tier in ["root", "middle", "top"]:
		if not terrain.has_ladder_texture(tier):
			_fail("has_ladder_texture(%s) false — biscuit_ladder asset 누락/미import" % tier)
			return
	if terrain.has_ladder_texture("__missing_tier__"):
		_fail("has_ladder_texture(__missing_tier__) true — 누락 tier 검출 실패")
		return
	var tex_cell: Vector2i = Vector2i(18, 0)
	var tex_body: StaticBody2D = _make_static_with_sprite()
	add_child(tex_body)
	terrain.register_static_body(tex_cell, tex_body, "earth")
	var tex_before: String = _tex_path(_first_sprite(tex_body))
	if terrain.reskin_cell_to_ladder(tex_cell, "__missing_tier__"):
		_fail("reskin_cell_to_ladder가 누락 tier에 true 반환 — 거짓 성공")
		return
	if _tex_path(_first_sprite(tex_body)) != tex_before:
		_fail("누락 tier reskin이 스프라이트 텍스처를 변경함: %s" % _tex_path(_first_sprite(tex_body)))
		return

	# --- (MEDIUM R6/R7) MIDDLE 텍스처 누락 시 sand-mound rung을 만들지 않는다 (invisible-solid 원천 차단) ---
	# test seam으로 MIDDLE을 누락 처리 → empty-growth add_tile 거부(상태 무생성) + cap preflight false.
	terrain._ladder_tex_forced_missing["middle"] = true
	var miss_cell: Vector2i = Vector2i(20, 0)
	if terrain.add_tile(miss_cell, Terrain.DYNAMIC_TILE_SAND_MOUND):
		_fail("MIDDLE 누락인데 add_tile(SAND_MOUND) 성공 — invisible solid rung")
		return
	if terrain.has_tile(miss_cell) or terrain.get_cell_kind(miss_cell) != "":
		_fail("거부된 sand-mound add_tile이 _placed/_cell_kind 상태를 남김")
		return
	# bridge는 MIDDLE 게이트와 무관 — 정상 배치되어야 한다(cross-mechanic 영향 없음).
	if not terrain.add_tile(Vector2i(20, 2), Terrain.DYNAMIC_TILE_BRIDGE):
		_fail("MIDDLE 누락이 bridge add_tile까지 막음 — 과잉 게이트")
		return
	# cap도 MIDDLE 누락이면 진입 불가.
	_setup_ledge(terrain, Vector2i(22, 4), "earth")
	if WorkerState._can_cap_ledge(terrain, Vector2i(22, 5)):
		_fail("MIDDLE 누락인데 _can_cap_ledge true — invisible rung cap 위험")
		return
	terrain._ladder_tex_forced_missing.erase("middle")
	# TOP 누락이면 cap 진입 불가(거짓 top).
	terrain._ladder_tex_forced_missing["top"] = true
	if WorkerState._can_cap_ledge(terrain, Vector2i(22, 5)):
		_fail("TOP 누락인데 _can_cap_ledge true — 거짓 top cap 위험")
		return
	terrain._ladder_tex_forced_missing.erase("top")
	# 복구 후 정상 cap 가능(seam 원복 확인).
	if not WorkerState._can_cap_ledge(terrain, Vector2i(22, 5)):
		_fail("텍스처 복구 후에도 _can_cap_ledge false — seam 원복 실패")
		return

	# --- (MEDIUM R4) 실패한 cast는 root를 남기지 않는다 (root reskin이 commit 경계 안) ---
	# body_cell=(5,5): 위(5,4)=plant 레지(cap 불가), 위의 위(5,3)=빈칸(solid 아님), 발밑(5,6)=earth floor.
	# 즉시 cap 불가 abort → 발밑 floor가 root로 reskin되면 안 되고, rung도 안 생겨야 한다.
	var rc_floor: StaticBody2D = _make_static_with_sprite()
	add_child(rc_floor)
	terrain.register_static_body(Vector2i(5, 6), rc_floor, "earth")
	var rc_ledge: StaticBody2D = _make_static_with_sprite()
	add_child(rc_ledge)
	terrain.register_static_body(Vector2i(5, 4), rc_ledge, "plant")
	var floor_before: String = _tex_path(_first_sprite(rc_floor))
	var ledge_before: String = _tex_path(_first_sprite(rc_ledge))
	var tc_before: int = terrain.tile_count()
	var ant: Ant = ANT_SCENE.instantiate() as Ant
	add_child(ant)
	ant.global_position = Vector2(5 * 48 + 24, 5 * 48 + 24)   # body_cell=(5,5)
	var ws: WorkerState = WorkerState.new()
	ws._ladder_root_done = false
	ws._aborted = false
	ws._place_sand_mound_tile(ant)
	if not ws._aborted:
		_fail("cap 불가(plant) 레지 아래 시전인데 abort되지 않음")
		return
	if terrain.tile_count() != tc_before:
		_fail("실패한 cast가 rung을 배치함 — tile_count %d→%d" % [tc_before, terrain.tile_count()])
		return
	var floor_after: String = _tex_path(_first_sprite(rc_floor))
	if floor_after.ends_with(ROOT_TEX) or floor_after != floor_before:
		_fail("실패한 cast가 발밑 floor를 root로 reskin함(잔존 artifact): %s" % floor_after)
		return
	if _tex_path(_first_sprite(rc_ledge)).ends_with(TOP_TEX) or _tex_path(_first_sprite(rc_ledge)) != ledge_before:
		_fail("실패한 cast가 plant 레지를 reskin함: %s" % _tex_path(_first_sprite(rc_ledge)))
		return

	print("[SandMoundReskinGuardTest] PASS (bridge/plant/slope no-reskin · earth reskin=top · can_reskin no-side-effect · cap atomicity A/B/C/D · missing-tier honest-false · missing-MIDDLE refuses rung+cap · failed-cast no-root)")
	get_tree().quit(0)

# 레지 셀에 정적 바디(직접 Sprite2D 자식) 등록 — _can_cap_ledge 시나리오 setup용.
func _setup_ledge(terrain: Terrain, cell: Vector2i, kind: String) -> void:
	var body: StaticBody2D = _make_static_with_sprite()
	add_child(body)
	terrain.register_static_body(cell, body, kind)

func _make_static_with_sprite() -> StaticBody2D:
	# StageLayoutBuilder의 solid 셀 구조 모사 — StaticBody2D 직접 자식으로 Sprite2D 1개.
	var body: StaticBody2D = StaticBody2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(48, 48)
	shape.shape = rect
	body.add_child(shape)
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/terrain/usable_square/biscuit_ladder_middle_square.png") as Texture2D
	body.add_child(sprite)
	return body

func _make_static_polygon_only() -> StaticBody2D:
	# 슬로프 셀 구조 모사 — collision/visual 모두 Polygon 계열, Sprite2D 없음 → reskin 대상 없음.
	var body: StaticBody2D = StaticBody2D.new()
	var poly: CollisionPolygon2D = CollisionPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(0, 0), Vector2(48, 48), Vector2(0, 48)])
	body.add_child(poly)
	var vis: Polygon2D = Polygon2D.new()
	vis.polygon = PackedVector2Array([Vector2(0, 0), Vector2(48, 48), Vector2(0, 48)])
	body.add_child(vis)
	return body

func _dyn_sprite(terrain: Terrain, cell: Vector2i) -> Sprite2D:
	if not terrain._placed.has(cell):
		return null
	return _first_sprite(terrain._placed[cell])

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

func _fail(msg: String) -> void:
	print("[SandMoundReskinGuardTest] FAIL %s" % msg)
	get_tree().quit(1)
