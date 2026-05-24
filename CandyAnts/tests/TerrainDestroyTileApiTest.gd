extends Node

# Phase 18 unit-style — Terrain의 신규 API(register_static_body / get_cell_kind / destroy_tile_at)
# atomic 불변식을 stage 없이 직접 검증.
#
# PASS criteria (5):
#  (1) destroy_tile_at(static_cell, ["earth"]) true → has_tile=false + kind="" + _static_occupancy 미포함 + body queue_free
#  (2) destroy_tile_at(dynamic_cell, ["earth"]) true → 동일 invariant + _placed 미포함
#  (3) destroy_tile_at(unregistered_cell, ["earth"]) false (변경 0)
#  (4) destroy_tile_at(static_cell, ["plant"]) false (kind 불일치, 변경 0)
#  (5) atomic: false 반환 시 어떤 registry도 변경 0

func _ready() -> void:
	var terrain: Terrain = Terrain.new()
	add_child(terrain)
	terrain.set_cell_size(32)

	# === (1) static cell destroy ===
	var static_cell: Vector2i = Vector2i(10, 20)
	var static_body: StaticBody2D = StaticBody2D.new()
	add_child(static_body)   # 외부 노드 — destroy 시 queue_free 호출됨
	terrain.register_static_body(static_cell, static_body, "earth")
	if terrain.get_cell_kind(static_cell) != "earth":
		_fail("(1a) register_static_body 후 kind != 'earth'")
		return
	if not terrain._static_occupancy.has(static_cell):
		_fail("(1b) register_static_body 후 _static_occupancy 미등록")
		return
	if not terrain.destroy_tile_at(static_cell, ["earth"]):
		_fail("(1c) destroy_tile_at(static, earth) false 반환")
		return
	if terrain.has_tile(static_cell):
		_fail("(1d) destroy 후 has_tile=true")
		return
	if terrain.get_cell_kind(static_cell) != "":
		_fail("(1e) destroy 후 kind != ''")
		return
	if terrain._static_occupancy.has(static_cell):
		_fail("(1f) destroy 후 _static_occupancy 잔존")
		return
	if terrain._static_bodies.has(static_cell):
		_fail("(1g) destroy 후 _static_bodies 잔존")
		return
	# body queue_free — 한 frame 대기 후 is_instance_valid false 검증.
	await get_tree().process_frame
	if is_instance_valid(static_body):
		_fail("(1h) destroy 후 body 노드 valid 잔존")
		return
	print("[TerrainDestroyTileApiTest] PASS (1) static cell destroy")

	# === (2) dynamic cell destroy (add_tile → destroy_tile_at) ===
	var dyn_cell: Vector2i = Vector2i(20, 30)
	if not terrain.add_tile(dyn_cell):
		_fail("(2a) add_tile false 반환")
		return
	if terrain.get_cell_kind(dyn_cell) != "earth":
		_fail("(2b) add_tile 후 kind != 'earth'")
		return
	if not terrain._placed.has(dyn_cell):
		_fail("(2c) add_tile 후 _placed 미등록")
		return
	if not terrain.destroy_tile_at(dyn_cell, ["earth"]):
		_fail("(2d) destroy_tile_at(dyn, earth) false 반환")
		return
	if terrain._placed.has(dyn_cell):
		_fail("(2e) destroy 후 _placed 잔존")
		return
	if terrain.get_cell_kind(dyn_cell) != "":
		_fail("(2f) destroy 후 kind != ''")
		return
	print("[TerrainDestroyTileApiTest] PASS (2) dynamic cell destroy")

	# === (3) unregistered cell destroy → false + atomic 무변경 ===
	var unreg_cell: Vector2i = Vector2i(99, 99)
	# Atomic sentinel — destroy 직전 snapshot 캡처.
	var pre_static_count: int = terrain._static_bodies.size()
	var pre_placed_count: int = terrain._placed.size()
	var pre_occupancy_count: int = terrain._static_occupancy.size()
	var pre_kind_count: int = terrain._cell_kind.size()
	if terrain.destroy_tile_at(unreg_cell, ["earth"]):
		_fail("(3a) unregistered cell destroy true 반환 (false 기대)")
		return
	if terrain._static_bodies.size() != pre_static_count:
		_fail("(3b) atomic 위반 — _static_bodies count 변경")
		return
	if terrain._placed.size() != pre_placed_count:
		_fail("(3c) atomic 위반 — _placed count 변경")
		return
	if terrain._static_occupancy.size() != pre_occupancy_count:
		_fail("(3d) atomic 위반 — _static_occupancy count 변경")
		return
	if terrain._cell_kind.size() != pre_kind_count:
		_fail("(3e) atomic 위반 — _cell_kind count 변경")
		return
	print("[TerrainDestroyTileApiTest] PASS (3) unregistered cell — false + atomic")

	# === (4) kind 불일치 (allowed_kinds=plant, 실제 kind=earth) → false + atomic ===
	var kind_cell: Vector2i = Vector2i(40, 20)
	var kind_body: StaticBody2D = StaticBody2D.new()
	add_child(kind_body)
	terrain.register_static_body(kind_cell, kind_body, "earth")
	var pre_snapshot_static: int = terrain._static_bodies.size()
	var pre_snapshot_placed: int = terrain._placed.size()
	var pre_snapshot_occ: int = terrain._static_occupancy.size()
	var pre_snapshot_kind: int = terrain._cell_kind.size()
	if terrain.destroy_tile_at(kind_cell, ["plant"]):
		_fail("(4a) kind 불일치 destroy true 반환 (false 기대)")
		return
	# atomic — kind 검사 통과 전이라 모든 registry 무변경.
	if terrain._static_bodies.size() != pre_snapshot_static:
		_fail("(4b) atomic 위반 — _static_bodies count 변경")
		return
	if terrain._placed.size() != pre_snapshot_placed:
		_fail("(4c) atomic 위반 — _placed count 변경")
		return
	if terrain._static_occupancy.size() != pre_snapshot_occ:
		_fail("(4d) atomic 위반 — _static_occupancy count 변경")
		return
	if terrain._cell_kind.size() != pre_snapshot_kind:
		_fail("(4e) atomic 위반 — _cell_kind count 변경")
		return
	if terrain.get_cell_kind(kind_cell) != "earth":
		_fail("(4f) atomic 위반 — kind 변경됨")
		return
	if not is_instance_valid(kind_body):
		_fail("(4g) atomic 위반 — body queue_free됨")
		return
	print("[TerrainDestroyTileApiTest] PASS (4) kind 불일치 — false + atomic")

	# === (5) atomic — body stale ref(외부 queue_free 후 destroy 호출) → registry는 erase ===
	var stale_cell: Vector2i = Vector2i(50, 20)
	var stale_body: StaticBody2D = StaticBody2D.new()
	add_child(stale_body)
	terrain.register_static_body(stale_cell, stale_body, "earth")
	# 외부 queue_free.
	stale_body.queue_free()
	await get_tree().process_frame
	# 이제 body는 stale. destroy_tile_at은 registry erase + queue_free skip(이미 free됨).
	if not terrain.destroy_tile_at(stale_cell, ["earth"]):
		_fail("(5a) stale body cell destroy false 반환 (true 기대 — registry erase)")
		return
	if terrain._static_bodies.has(stale_cell):
		_fail("(5b) stale destroy 후 _static_bodies 잔존")
		return
	if terrain._cell_kind.has(stale_cell):
		_fail("(5c) stale destroy 후 _cell_kind 잔존")
		return
	print("[TerrainDestroyTileApiTest] PASS (5) stale body atomic erase")

	print("[TerrainDestroyTileApiTest] PASS")
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("[TerrainDestroyTileApiTest] FAIL: " + reason)
	get_tree().quit(1)
