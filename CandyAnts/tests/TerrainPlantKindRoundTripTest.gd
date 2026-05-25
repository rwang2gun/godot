extends Node

# Phase 19 unit-style — Terrain의 plant kind round-trip invariant 검증 (phase 18 earth invariant의 plant 확장).
#
# PASS criteria (4):
#  (1) register_static_body(cell, body, "plant") 후 kind="plant" + _static_occupancy 등록 + _static_bodies 등록
#  (2) destroy_tile_at(cell, ["plant"]) true → has_tile=false + kind="" + 4 registry erase + body queue_free
#  (3) register 후 destroy_tile_at(cell, ["earth"]) false (kind 불일치 atomic)
#  (4) plant cell 등록 상태에서 add_tile(plant_cell) false (D5 자연 차단 — first-place wins)

func _ready() -> void:
	var terrain: Terrain = Terrain.new()
	add_child(terrain)
	terrain.set_cell_size(32)

	# === (1) register_static_body("plant") ===
	var plant_cell: Vector2i = Vector2i(10, 20)
	var plant_body: StaticBody2D = StaticBody2D.new()
	add_child(plant_body)
	terrain.register_static_body(plant_cell, plant_body, "plant")
	if terrain.get_cell_kind(plant_cell) != "plant":
		_fail("(1a) register 후 kind != 'plant' (got=%s)" % terrain.get_cell_kind(plant_cell))
		return
	if not terrain._static_occupancy.has(plant_cell):
		_fail("(1b) register 후 _static_occupancy 미등록")
		return
	if not terrain._static_bodies.has(plant_cell):
		_fail("(1c) register 후 _static_bodies 미등록")
		return
	print("[TerrainPlantKindRoundTripTest] PASS (1) register plant cell")

	# === (3) kind 불일치 — destroy_tile_at(plant_cell, ["earth"]) false ===
	# (2)보다 먼저 — atomic 검증을 위해 body alive 상태에서 호출.
	var pre_static: int = terrain._static_bodies.size()
	var pre_occ: int = terrain._static_occupancy.size()
	var pre_kind: int = terrain._cell_kind.size()
	if terrain.destroy_tile_at(plant_cell, ["earth"]):
		_fail("(3a) destroy(plant, ['earth']) true 반환 (false 기대)")
		return
	if terrain._static_bodies.size() != pre_static or terrain._static_occupancy.size() != pre_occ or terrain._cell_kind.size() != pre_kind:
		_fail("(3b) atomic 위반 — kind 불일치 false 반환 후 registry 변동")
		return
	if terrain.get_cell_kind(plant_cell) != "plant":
		_fail("(3c) kind 불일치 false 반환 후 kind 변경")
		return
	if not is_instance_valid(plant_body):
		_fail("(3d) kind 불일치 false 반환 후 body queue_free")
		return
	print("[TerrainPlantKindRoundTripTest] PASS (3) cross-kind atomic block")

	# === (4) add_tile reject (D5 자연 차단) ===
	if terrain.add_tile(plant_cell):
		_fail("(4a) add_tile(plant_cell) true 반환 — D5 자연 차단 위반")
		return
	print("[TerrainPlantKindRoundTripTest] PASS (4) add_tile reject on plant cell")

	# === (2) destroy_tile_at(plant_cell, ["plant"]) true ===
	if not terrain.destroy_tile_at(plant_cell, ["plant"]):
		_fail("(2a) destroy(plant, ['plant']) false 반환 (true 기대)")
		return
	if terrain.has_tile(plant_cell):
		_fail("(2b) destroy 후 has_tile=true")
		return
	if terrain.get_cell_kind(plant_cell) != "":
		_fail("(2c) destroy 후 kind != '' (got=%s)" % terrain.get_cell_kind(plant_cell))
		return
	if terrain._static_occupancy.has(plant_cell):
		_fail("(2d) destroy 후 _static_occupancy 잔존")
		return
	if terrain._static_bodies.has(plant_cell):
		_fail("(2e) destroy 후 _static_bodies 잔존")
		return
	await get_tree().process_frame
	if is_instance_valid(plant_body):
		_fail("(2f) destroy 후 body 노드 valid 잔존")
		return
	print("[TerrainPlantKindRoundTripTest] PASS (2) plant destroy round-trip")

	print("[TerrainPlantKindRoundTripTest] PASS")
	get_tree().quit(0)

func _fail(reason: String) -> void:
	push_error("[TerrainPlantKindRoundTripTest] FAIL: " + reason)
	get_tree().quit(1)
