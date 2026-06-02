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
const DYNAMIC_TILE_STAIR: String = "stair"
const DYNAMIC_TILE_SAND_MOUND: String = "sand_mound"

# biscuit-ladder reskin (2026-06-02): 막대과자 사다리(구 sand_mound)는 "지형 통합" 모델.
# 동적 rung 타일은 전부 middle. 아래/위 지형 면(walkable surface)은 reskin_cell_to_ladder로
# root/top 텍스처만 교체(충돌/점유 불변). tier 3단 강등(구 surface/under/background) 시스템은 폐기.
const LADDER_TIER_ROOT: String = "root"
const LADDER_TIER_MIDDLE: String = "middle"
const LADDER_TIER_TOP: String = "top"

var _bridge_tile_texture: Texture2D = null
var _stair_tile_texture: Texture2D = null
# 모래 동적 타일 한정 cell→Sprite2D (destroy 시 정리용).
var _sand_mound_sprites: Dictionary = {}
var _ladder_tex_cache: Dictionary = {}   # tier(String) → Texture2D
# 테스트 전용 — tier(String)→true면 _ladder_texture가 그 tier를 null로 취급(asset 누락 시뮬). 평상시 빈 dict라 무영향.
# (codex 2026-06-02 R7) missing-texture atomic 거부를 결정적으로 회귀 테스트하기 위한 seam.
var _ladder_tex_forced_missing: Dictionary = {}

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
func destroy_tile_at(
	cell: Vector2i,
	allowed_kinds: Array[String] = ["earth"]
) -> bool:
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

func add_tile(cell: Vector2i, visual_style: String = DYNAMIC_TILE_BRIDGE, visual_direction: int = 1) -> bool:
	# D8 first-place wins — 동적/정적 어느 쪽이든 점유면 reject.
	if _placed.has(cell) or _static_occupancy.has(cell):
		return false
	# (codex 2026-06-02 R7) sand-mound rung은 MIDDLE 텍스처 없이 "보이지 않는 solid"가 되면 안 된다.
	# 텍스처 미가용(asset 누락/미import/export 누락)이면 **어떤 상태도 만들기 전에** 거부 — empty-growth/cap
	# 양쪽에서 invisible-solid rung을 원천 차단(상태 변경 전 preflight라 rollback 불필요). bridge/stair는 무관.
	if visual_style == DYNAMIC_TILE_SAND_MOUND and not has_ladder_texture(LADDER_TIER_MIDDLE):
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
	_configure_dynamic_tile_sprite(sprite, visual_style, visual_direction)
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
		# biscuit-ladder: 동적 rung은 전부 middle. (아래/위 지형 면의 root/top은 reskin_cell_to_ladder가 담당.)
		_sand_mound_sprites[cell] = sprite
	return true

func _configure_dynamic_tile_sprite(sprite: Sprite2D, visual_style: String, visual_direction: int = 1) -> void:
	if visual_style == DYNAMIC_TILE_SAND_MOUND:
		# biscuit-ladder: 동적 rung 타일은 전부 middle. root/top은 지형 면 reskin이 담당.
		_apply_ladder_tex(sprite, LADDER_TIER_MIDDLE)
		return
	if visual_style == DYNAMIC_TILE_STAIR:
		if _stair_tile_texture == null:
			_stair_tile_texture = load("res://assets/sprites/terrain/cookie_stair_tile.png") as Texture2D
		sprite.texture = _stair_tile_texture
		sprite.flip_h = visual_direction < 0
		var stair_scale: float = float(cell_size) / 48.0
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2(stair_scale, stair_scale)
		return
	if _bridge_tile_texture == null:
		_bridge_tile_texture = load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D
	sprite.texture = _bridge_tile_texture
	# v5: 16px native sprite → cell_size에 비례 scale. cs=16이면 scale_factor=1.0 (회귀 0건).
	var scale_factor: float = float(cell_size) / 16.0
	sprite.position = Vector2(0, -13.0 * scale_factor)
	sprite.scale = Vector2(scale_factor, scale_factor)

# biscuit-ladder 지형 통합 (2026-06-02): 셀의 시각 sprite 텍스처만 biscuit_ladder tier로 교체한다.
# 충돌/점유/cell_kind 불변 — 사다리가 아래/위 기존 **일반 정적 지형 면**(earth surface)을 root/top으로 통합할 때 호출.
# 적격 조건(전부 만족해야 reskin): (1) kind == "earth" (2) 정적 _static_bodies 등록 셀 (3) 직접 Sprite2D 자식 보유.
# 하나라도 불충족이면 no-op(false) → 호출부는 cap 불가로 처리.
# (codex 2026-06-02 HIGH ×2) cross-mechanic 스프라이트 오염 차단:
#   - 동적 _placed 타일(bridge/stair/rung)은 _cell_sprite가 static-only라 제외.
#   - plant 정적 셀(kind="plant", PlantVisual Sprite2D 보유)은 kind 게이트로 제외.
#   - 슬로프(kind="earth"이나 Polygon2D 비주얼·Sprite2D 없음)는 _cell_sprite null로 제외.
func reskin_cell_to_ladder(cell: Vector2i, tier: String) -> bool:
	if not can_reskin_cell_to_ladder(cell):
		return false
	# 텍스처 적용 성공 여부를 정직하게 반환 — tier 텍스처 load 실패 시 false (codex 2026-06-02 R5).
	return _apply_ladder_tex(_cell_sprite(cell), tier)

# reskin_cell_to_ladder가 성공할 셀인지 **부작용 없이** 미리 검사한다 — cap atomic preflight용.
# 적격 조건은 reskin과 동일: kind=="earth" + 정적 등록 + 직접 Sprite2D 자식.
# (텍스처 가용성은 tier별이므로 별도 has_ladder_texture로 검사 — cap preflight가 함께 사용.)
func can_reskin_cell_to_ladder(cell: Vector2i) -> bool:
	return get_cell_kind(cell) == "earth" and _cell_sprite(cell) != null

# tier 텍스처가 실제 load 가능한지 — cap atomic preflight가 사용(없으면 capped가 거짓 성공이 되는 것 차단).
# (codex 2026-06-02 R5) game-state 부작용 없음(텍스처 캐시 memoization만).
func has_ladder_texture(tier: String) -> bool:
	return _ladder_texture(tier) != null

# biscuit_ladder tier 텍스처 load+cache. asset 누락/미import/export 누락이면 null(에러 스팸 없이 exists 선검사).
func _ladder_texture(tier: String) -> Texture2D:
	if _ladder_tex_forced_missing.has(tier):
		return null   # 테스트 seam — asset 누락 시뮬 (평상시 미사용)
	var cached: Texture2D = _ladder_tex_cache.get(tier)
	if cached != null:
		return cached
	var path: String = "res://assets/sprites/terrain/usable_square/biscuit_ladder_%s_square.png" % tier
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return null
	_ladder_tex_cache[tier] = tex
	return tex

# 정적 지형 셀(_static_bodies)의 직접 Sprite2D 자식만 반환. 동적 _placed는 의도적으로 제외(위 reskin 주석 참조).
func _cell_sprite(cell: Vector2i) -> Sprite2D:
	var body: Object = _static_bodies.get(cell)
	if not is_instance_valid(body):
		return null
	for ch in (body as Node).get_children():
		if ch is Sprite2D:
			return ch as Sprite2D
	return null

# biscuit_ladder 타일(root/middle/top) whole-tile 렌더 — region 없이 cell_size에 맞춰 균일 scale, 중앙.
# 48×48 단일 정사각이라 cell_size가 달라도(16/32/48) 잘리지 않는다.
# 반환: 텍스처를 실제 적용했으면 true, tier 텍스처 load 실패면 false(스프라이트 무변경) — reskin atomic 보장용.
func _apply_ladder_tex(sprite: Sprite2D, tier: String) -> bool:
	var tex: Texture2D = _ladder_texture(tier)
	if tex == null:
		return false
	sprite.region_enabled = false
	sprite.texture = tex
	sprite.position = Vector2.ZERO
	var ts: Vector2 = tex.get_size()
	if ts.x > 0.0 and ts.y > 0.0:
		sprite.scale = Vector2(float(cell_size) / ts.x, float(cell_size) / ts.y)
	return true

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
