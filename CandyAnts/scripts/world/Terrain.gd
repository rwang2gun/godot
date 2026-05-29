class_name Terrain extends Node2D

# Phase 16 v4: const CELL_SIZE 제거 — StageLayoutBuilder.build()이 layout.cell_size로 set_cell_size 호출.
# layout 미사용 stage(Stage 02/03 등)는 default 16 유지 → Builder backward-compat.
# _static_occupancy: StageLayoutBuilder가 생성한 정적 cell. add_tile은 정적/동적 둘 다 점유 시 reject (D8).
var cell_size: int = 16
var _placed: Dictionary = {}              # Vector2i → StaticBody2D (동적 cell)
var _static_occupancy: Dictionary = {}    # Vector2i → true (정적 stage cell)
# Phase 17 — hazard 노드들 cell 매핑. Bridge × hazard 통합점.
# v3: Array 저장으로 same-cell overlap(Water+Sticky 등) 지원 → deactivate 시 모든 hazard 일괄 set_active(false).
# registration 순서 무관 D8 정책 robust (codex R1-H1 대응).
var _hazards_by_cell: Dictionary = {}     # Vector2i → Array[HazardBase]
# Phase 18 — 정적 cell StaticBody2D registry. StageLayoutBuilder가 register_static_body로 등록.
# destroy_tile_at 시 dynamic _placed + 정적 _static_bodies 둘 다 queue_free 대상.
var _static_bodies: Dictionary = {}       # Vector2i → StaticBody2D
# Phase 18 — cell 종류 분류. "earth"(default) / "plant"(phase 19) / "" (미등록).
# destroy_tile_at의 allowed_kinds로 cross-mechanic 침범 차단.
var _cell_kind: Dictionary = {}           # Vector2i → String
const DYNAMIC_TILE_BRIDGE: String = "bridge"
const DYNAMIC_TILE_SAND_MOUND: String = "sand_mound"

# 모래 쌓기 3단 렌더 — 정적 쿠키 지형(StageLayoutBuilder)과 동일하게 column을 위→아래로
# surface / under_surface / background로 표현. 동적 column이라 타일이 위로 쌓일 때마다
# _reskin_sand_column이 아래 칸을 surface→under_surface→background로 강등한다.
const SAND_TIER_SURFACE: String = "surface"
const SAND_TIER_UNDER: String = "under_surface"
const SAND_TIER_BACKGROUND: String = "background"

var _bridge_tile_texture: Texture2D = null
# 모래 동적 타일 한정 cell→Sprite2D. bridge 타일은 미포함 → 재스킨 시 cross-contamination 차단.
var _sand_mound_sprites: Dictionary = {}
var _sand_surface_tex: Texture2D = null
var _sand_under_tex: Texture2D = null
var _sand_background_tex: Texture2D = null

func set_cell_size(s: int) -> void:
	if s > 0:
		cell_size = s

func register_static_cell(cell: Vector2i) -> void:
	# idempotent — 중복 register OK (StageLayoutBuilder가 rebuild 시 다시 부를 수 있음).
	_static_occupancy[cell] = true

# Phase 18 — 정적 cell의 StaticBody2D를 cell-keyed registry에 등록.
# StageLayoutBuilder.build()가 cell 생성 직후 호출 → destroy_tile_at 시 body 직접 queue_free 가능.
# Dynamic _placed와 별도 — atomic destruction에서 둘 다 검사.
func register_static_body(cell: Vector2i, body: StaticBody2D, kind: String = "earth") -> void:
	if body == null:
		return
	_static_bodies[cell] = body
	_cell_kind[cell] = kind
	register_static_cell(cell)   # _static_occupancy 등록 — D8 first-place wins 자연 정합

# Phase 18 — cell 종류. "" = 미등록(공기 또는 hazard). "earth"/"plant" 등 명시 kind가 있을 때만 destroy 후보.
func get_cell_kind(cell: Vector2i) -> String:
	return _cell_kind.get(cell, "")

# Phase 18 — cell 단위 파괴. dynamic + static body queue_free + 4개 registry atomic erase.
# atomic invariant: kind 검사 전 무변경. kind 통과 후 registry 4종은 무조건 erase + body는 valid일 때만 queue_free.
# stale body ref(이미 free된 노드)는 queue_free skip + registry는 정상 erase.
func destroy_tile_at(cell: Vector2i, allowed_kinds: Array[String] = ["earth"]) -> bool:
	var kind: String = get_cell_kind(cell)
	if kind == "" or not allowed_kinds.has(kind):
		return false
	# dynamic 먼저 — D8 first-place wins로 같은 cell이 dynamic + static 둘 다 점유될 수 없지만,
	# 방어적으로 둘 다 검사하여 stale ref 제거.
	# stale(이미 free된) body ref는 Variant로 받아 is_instance_valid 검사 후 typed cast 회피.
	if _placed.has(cell):
		var body_dyn: Variant = _placed[cell]
		if is_instance_valid(body_dyn):
			(body_dyn as StaticBody2D).queue_free()
		_placed.erase(cell)
	if _static_bodies.has(cell):
		var body_static: Variant = _static_bodies[cell]
		if is_instance_valid(body_static):
			(body_static as StaticBody2D).queue_free()
		_static_bodies.erase(cell)
	_static_occupancy.erase(cell)
	_cell_kind.erase(cell)
	_sand_mound_sprites.erase(cell)   # 모래 타일이면 tier registry도 정리 (아니면 no-op)
	return true

func add_tile(cell: Vector2i, visual_style: String = DYNAMIC_TILE_BRIDGE) -> bool:
	# D8 first-place wins — 동적/정적 어느 쪽이든 점유면 reject.
	if _placed.has(cell) or _static_occupancy.has(cell):
		return false
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(cell_size, cell_size)
	shape.shape = rect
	body.add_child(shape)
	var sprite: Sprite2D = Sprite2D.new()
	_configure_dynamic_tile_sprite(sprite, visual_style)
	body.add_child(sprite)
	body.global_position = Vector2(
		float(cell.x) * cell_size + cell_size / 2.0,
		float(cell.y) * cell_size + cell_size / 2.0
	)
	add_child(body)
	_placed[cell] = body
	# Phase 18 — 동적 placement도 destructible. Basher/Digger의 destroy 대상에 포함.
	_cell_kind[cell] = "earth"
	if visual_style == DYNAMIC_TILE_SAND_MOUND:
		# 갓 쌓은 타일은 항상 column 맨 위 → surface. _reskin이 아래 칸을 강등한다.
		_sand_mound_sprites[cell] = sprite
		_reskin_sand_column(cell)
	return true

func _configure_dynamic_tile_sprite(sprite: Sprite2D, visual_style: String) -> void:
	if visual_style == DYNAMIC_TILE_SAND_MOUND:
		# 초기값 surface (방금 쌓은 = 맨 위). add_tile의 _reskin_sand_column이 아래 칸을 강등.
		_apply_sand_tier(sprite, SAND_TIER_SURFACE)
		return
	if _bridge_tile_texture == null:
		_bridge_tile_texture = load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D
	sprite.texture = _bridge_tile_texture
	# v5: 16px native sprite → cell_size에 비례 scale. cs=16이면 scale_factor=1.0 (회귀 0건).
	var scale_factor: float = float(cell_size) / 16.0
	sprite.position = Vector2(0, -13.0 * scale_factor)
	sprite.scale = Vector2(scale_factor, scale_factor)

# 모래 column 재스킨 — 새 타일을 쌓을 때마다 호출(top_cell = 방금 쌓은 맨 위 칸).
# +Y(화면상 아래)로 내려가며 surface → under_surface → background로 강등. 3번째 이하는 이미
# background이고 다시 바뀌지 않으므로 상위 3칸만 갱신해도 invariant가 유지된다.
func _reskin_sand_column(top_cell: Vector2i) -> void:
	_set_sand_tier_if_present(top_cell, SAND_TIER_SURFACE)
	_set_sand_tier_if_present(top_cell + Vector2i(0, 1), SAND_TIER_UNDER)
	_set_sand_tier_if_present(top_cell + Vector2i(0, 2), SAND_TIER_BACKGROUND)

func _set_sand_tier_if_present(cell: Vector2i, tier: String) -> void:
	var sprite_v: Variant = _sand_mound_sprites.get(cell)
	if sprite_v == null or not is_instance_valid(sprite_v):
		return
	_apply_sand_tier(sprite_v as Sprite2D, tier)

func _apply_sand_tier(sprite: Sprite2D, tier: String) -> void:
	var tex: Texture2D = _sand_tier_texture(tier)
	if tex == null:
		return
	# 모래 타일은 가로 아틀라스가 아니라 독립 정사각형 1장(§TERRAIN_TILE_RULES.11). region 샘플링 없이
	# 텍스처 전체를 cell_size에 맞춰 균일 scale → 어디에 쌓아도 동일, cell_size가 달라도 그림이 잘리지 않음.
	sprite.region_enabled = false
	sprite.texture = tex
	sprite.position = Vector2.ZERO
	var ts: Vector2 = tex.get_size()
	if ts.x > 0.0 and ts.y > 0.0:
		sprite.scale = Vector2(float(cell_size) / ts.x, float(cell_size) / ts.y)

func _sand_tier_texture(tier: String) -> Texture2D:
	if tier == SAND_TIER_SURFACE:
		if _sand_surface_tex == null:
			_sand_surface_tex = load("res://assets/sprites/terrain/sand_tile_surface.png") as Texture2D
		return _sand_surface_tex
	elif tier == SAND_TIER_UNDER:
		if _sand_under_tex == null:
			_sand_under_tex = load("res://assets/sprites/terrain/sand_tile_under_surface.png") as Texture2D
		return _sand_under_tex
	if _sand_background_tex == null:
		_sand_background_tex = load("res://assets/sprites/terrain/sand_tile_background.png") as Texture2D
	return _sand_background_tex

func has_tile(cell: Vector2i) -> bool:
	return _placed.has(cell)

# PlacementPreview용 — dynamic + static 점유 통합 검사. add_tile reject 조건과 동일 기준을
# 외부에 노출해 ghost 미리보기가 정확히 예측 가능.
func is_cell_occupied(cell: Vector2i) -> bool:
	return _placed.has(cell) or _static_occupancy.has(cell)

func tile_count() -> int:
	return _placed.size()

# Phase 17 — hazard 노드가 _ready에서 자체 호출. 같은 cell의 hazard들이 Array로 누적.
func register_hazard_at_cell(cell: Vector2i, hazard: HazardBase) -> void:
	if hazard == null:
		return
	var arr: Array = _hazards_by_cell.get(cell, [])
	if arr.has(hazard):
		return   # idempotent — 같은 instance 중복 register 무효
	arr.append(hazard)
	_hazards_by_cell[cell] = arr

# Phase 17 — cell의 모든 hazard에 set_active(false) 일괄. registration 순서 무관 (codex R1-H1).
func deactivate_hazards_at(cell: Vector2i) -> void:
	var arr: Array = _hazards_by_cell.get(cell, [])
	for h in arr:
		var hazard: HazardBase = h as HazardBase
		if hazard != null and is_instance_valid(hazard):
			hazard.set_active(false)

# Phase 17 — Bridge/Sand-mound/Builder의 add_tile 직후 호출 (WorkerState._place_*_tile).
# target은 floor row(Bridge/Builder) 또는 body row(Sand-mound). hazard는 항상 body row 컨벤션.
# 따라서 target + target-1 두 cell 모두 비활성 → floor-row placement도 body-row hazard 매칭.
func deactivate_hazards_for_placement(target: Vector2i) -> void:
	deactivate_hazards_at(target)
	deactivate_hazards_at(target + Vector2i(0, -1))
