extends Node2D
# codex 2026-06-03 MEDIUM 회귀 — StairClimbState가 글라이드 중 _dest 셀이 점유되면 스냅하지 않도록
# 하는 _dest_blocked 가드 검증(터레인 변형 레이스로 solid에 박힘 방지). 가드 술어를 결정론적으로 단위 검증.
#
# 검증: 점유된 셀을 _dest로 가리키면 _dest_blocked==true, 빈 셀을 가리키면 false.

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const CS: int = 48

func _ready() -> void:
	var terrain: Terrain = Terrain.new()
	terrain.name = "Terrain"
	terrain.set_cell_size(CS)
	add_child(terrain)
	var ant: Ant = ANT_SCENE.instantiate() as Ant
	add_child(ant)   # _find_terrain가 ant.get_parent()(=self)의 "Terrain" 자식을 찾음.

	var occupied: Vector2i = Vector2i(5, 5)
	terrain.add_tile(occupied, Terrain.DYNAMIC_TILE_BRIDGE)   # 점유

	var s: StairClimbState = StairClimbState.new()
	s.ant = ant

	# _dest를 점유 셀 중심으로 → floor(x/cs)=col, floor((y-2)/cs)=row 가 점유 셀과 일치.
	s._dest = Vector2(float(occupied.x) * CS + 24.0, float(occupied.y) * CS + 26.0)
	var blocked: bool = s._dest_blocked(ant)

	# 빈 셀로 → false 기대.
	var empty: Vector2i = Vector2i(9, 9)
	s._dest = Vector2(float(empty.x) * CS + 24.0, float(empty.y) * CS + 26.0)
	var clear: bool = s._dest_blocked(ant)

	if blocked and not clear:
		print("[StairClimbDestGuardTest] PASS _dest_blocked: occupied=true empty=false")
		get_tree().quit(0)
	else:
		print("[StairClimbDestGuardTest] FAIL _dest_blocked occupied=%s empty=%s (기대 true/false)" % [blocked, clear])
		get_tree().quit(1)
