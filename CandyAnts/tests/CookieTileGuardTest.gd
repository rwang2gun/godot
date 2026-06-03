extends Node

# S6 "땅굴" 코어 — TILE_COOKIE_SOLID(kind="cookie") 불괴 검증.
# Stage06 layout을 빌드한 뒤 Terrain registry를 직접 조회:
#   (1) 흙 캡 cell(earth)은 get_cell_kind=="earth" + destroy_tile_at(["earth"])==true → 굴착 가능.
#   (2) 챔버/벽 cell(cookie)은 get_cell_kind=="cookie" + destroy_tile_at(["earth"])==false → 불괴,
#       호출 후에도 점유 유지(구조 무결성). cutter(["plant"])로도 거부.
# PASS: 위 단언 전부 통과. FAIL: 하나라도 어긋나면 즉시 quit(1).

const EARTH_CELL := Vector2i(10, 4)    # 흙 캡(cols1-22, rows2-5) 내부.
const COOKIE_FLOOR_CELL := Vector2i(10, 13)  # 챔버 바닥(cookie).
const COOKIE_WALL_CELL := Vector2i(0, 8)     # 좌측 벽(cookie).

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame  # StageLayoutBuilder.build() + register_static_body 완료 대기
	var terrain: Terrain = _find_terrain(get_tree().get_root())
	if terrain == null:
		return _fail("Terrain not found")

	# (1) earth — 굴착 가능.
	if terrain.get_cell_kind(EARTH_CELL) != "earth":
		return _fail("earth cell kind=%s (expected earth)" % terrain.get_cell_kind(EARTH_CELL))

	# (2) cookie floor — 불괴.
	if terrain.get_cell_kind(COOKIE_FLOOR_CELL) != "cookie":
		return _fail("cookie floor kind=%s (expected cookie)" % terrain.get_cell_kind(COOKIE_FLOOR_CELL))
	if terrain.get_cell_kind(COOKIE_WALL_CELL) != "cookie":
		return _fail("cookie wall kind=%s (expected cookie)" % terrain.get_cell_kind(COOKIE_WALL_CELL))

	# cookie는 digger(["earth"])·cutter(["plant"]) 둘 다 거부 + 호출 후 점유 유지.
	if terrain.destroy_tile_at(COOKIE_FLOOR_CELL, ["earth"]):
		return _fail("destroy_tile_at(cookie, [earth]) returned true — cookie was destroyed")
	if terrain.destroy_tile_at(COOKIE_WALL_CELL, ["plant"]):
		return _fail("destroy_tile_at(cookie wall, [plant]) returned true")
	if not terrain.is_cell_occupied(COOKIE_FLOOR_CELL):
		return _fail("cookie floor no longer occupied after rejected destroy")
	if not terrain.is_cell_occupied(COOKIE_WALL_CELL):
		return _fail("cookie wall no longer occupied after rejected destroy")

	# earth는 굴착 성공 + 점유 해제(이 단언이 cookie 거부의 대조군).
	if not terrain.destroy_tile_at(EARTH_CELL, ["earth"]):
		return _fail("destroy_tile_at(earth, [earth]) returned false — earth not diggable")
	if terrain.is_cell_occupied(EARTH_CELL):
		return _fail("earth cell still occupied after successful destroy")

	print("[CookieTileGuardTest] PASS (earth diggable, cookie indestructible)")
	get_tree().quit(0)

func _find_terrain(n: Node) -> Terrain:
	for c in n.get_children():
		if c is Terrain:
			return c as Terrain
		var found: Terrain = _find_terrain(c)
		if found != null:
			return found
	return null

func _fail(msg: String) -> void:
	print("[CookieTileGuardTest] FAIL ", msg)
	get_tree().quit(1)
