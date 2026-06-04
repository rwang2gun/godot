class_name StageLayoutData extends Resource

@export var cell_size: int = 32
@export var platform_cells: Array[Vector2i] = []
@export var tile_map: Dictionary = {}
# 레벨 에디터(map-editor 트랙) — 해저드 배치 SoT. key="x,y" → "water" | "sticky".
# StageLayoutBuilder 런타임은 사용하지 않고, 에디터가 씬 생성 시 Water/Sticky 인스턴스를 굽는 데 쓴다.
# 에디터로 저작한 스테이지의 해저드 라운드트립(재로드)을 위한 필드 — 레거시 씬-only 해저드는 여기에 없다.
@export var hazard_map: Dictionary = {}
@export var home_cell: Vector2i = Vector2i(12, 27)
@export var candy_cell: Vector2i = Vector2i(44, 27)
@export var camera_cell: Vector2i = Vector2i(30, 17)
@export var spawn_direction: int = 1
@export var spawn_direction_alternate: bool = false
@export var theme: String = "cookie_crust"
# Phase 15 — 정착 마커 cell. SettlementMarker가 layout.cell_to_world로 위치 매핑.
# Vector2i(-1, -1) = "settlement 미설정" 센티넬 (stage가 정착 메커니즘 미사용).
@export var settlement_cell: Vector2i = Vector2i(-1, -1)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		float(cell.x * cell_size + cell_size / 2),
		float(cell.y * cell_size + cell_size / 2)
	)
