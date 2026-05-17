class_name StageLayoutData extends Resource

@export var cell_size: int = 32
@export var platform_cells: Array[Vector2i] = []
@export var tile_map: Dictionary = {}
@export var home_cell: Vector2i = Vector2i(12, 27)
@export var candy_cell: Vector2i = Vector2i(44, 27)
@export var camera_cell: Vector2i = Vector2i(30, 17)
@export var spawn_direction: int = 1
@export var spawn_direction_alternate: bool = false

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * cell_size + cell_size / 2),
		float(cell.y * cell_size + cell_size / 2)
	)
