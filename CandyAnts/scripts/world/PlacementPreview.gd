class_name PlacementPreview extends Node2D

# 설치형 스킬(sand_mound / builder / bridge) 선택 시 커서 아래 가장 가까운 ant의
# 첫 배치 결과를 반투명 ghost로 미리보기.
#
# 입력:
#   - SkillToolbar._pending_skill_id (선택된 스킬)
#   - get_global_mouse_position() (커서 world 위치)
#   - "ants" 그룹 (활성 후보)
#   - Terrain (cell_size + 점유 검사)
#
# 출력: 자신 자식으로 Polygon2D ghost들. 매 frame _process에서 toolbar/cursor 상태 polling.
#
# 시뮬레이션 정확도: 첫 tile부터 차례로 add_tile reject 조건(is_cell_occupied)을 검사,
# 첫 차단 셀에서 break. 차단된 셀이 첫 번째일 경우 빨간 1셀로 경고 표시. 그 외엔 녹색.

const PLACEMENT_SKILLS: Array[String] = ["sand_mound", "builder", "bridge"]
const CLICK_RADIUS: float = 48.0  # SkillToolbar.CLICK_RADIUS와 동일 (이중 SoT 회피 위해 향후 통합 고려)
const SAND_MOUND_MAX: int = 5
const BUILDER_MAX: int = 12
const BRIDGE_MAX: int = 8

const COLOR_OK: Color = Color(0.4, 1.0, 0.4, 0.45)
const COLOR_BLOCKED: Color = Color(1.0, 0.35, 0.35, 0.55)

@export var toolbar_path: NodePath
@export var terrain_path: NodePath

var _toolbar: SkillToolbar = null
var _terrain: Terrain = null
var _ghosts: Array[Polygon2D] = []

func _ready() -> void:
	_toolbar = get_node_or_null(toolbar_path) as SkillToolbar
	_terrain = get_node_or_null(terrain_path) as Terrain
	z_index = 100   # 타일 위에 표시

func _process(_delta: float) -> void:
	if _toolbar == null or _terrain == null:
		_hide_all()
		return
	var pending: String = _toolbar._pending_skill_id
	if not PLACEMENT_SKILLS.has(pending):
		_hide_all()
		return
	var cursor_world: Vector2 = get_global_mouse_position()
	var ant: Ant = _find_closest_ant(cursor_world)
	if ant == null:
		_hide_all()
		return
	var cs: int = _terrain.cell_size
	var cells: Array[Vector2i] = _compute_targets(ant, pending, cs)
	var first_blocked: bool = cells.is_empty() and _first_target_blocked(ant, pending, cs)
	if cells.is_empty() and not first_blocked:
		_hide_all()
		return
	if first_blocked:
		var blocked_cell: Vector2i = _first_target_cell(ant, pending, cs)
		_render([blocked_cell], cs, true)
	else:
		_render(cells, cs, false)

func _compute_targets(ant: Ant, skill_id: String, cs: int) -> Array[Vector2i]:
	# add_tile reject 조건(is_cell_occupied)을 차례로 검사. 첫 차단 셀 이전까지만 누적.
	# 빈 배열 반환 = 첫 셀부터 차단(별도 first_blocked 분기로 빨간 경고 표시).
	var body: Vector2i = _body_cell(ant, cs)
	var out: Array[Vector2i] = []
	if skill_id == "sand_mound":
		for i in SAND_MOUND_MAX:
			var cell: Vector2i = body + Vector2i(0, -i)
			if _terrain.is_cell_occupied(cell):
				break
			out.append(cell)
		return out
	if skill_id == "builder" or skill_id == "bridge":
		var max_count: int = BUILDER_MAX if skill_id == "builder" else BRIDGE_MAX
		var cur_body: Vector2i = body
		for i in max_count:
			var tgt: Vector2i = cur_body + Vector2i(ant.direction, 1)
			if _terrain.is_cell_occupied(tgt):
				break
			out.append(tgt)
			cur_body += Vector2i(ant.direction, 0)
		return out
	return out

func _first_target_cell(ant: Ant, skill_id: String, cs: int) -> Vector2i:
	var body: Vector2i = _body_cell(ant, cs)
	if skill_id == "sand_mound":
		return body
	return body + Vector2i(ant.direction, 1)

func _first_target_blocked(ant: Ant, skill_id: String, cs: int) -> bool:
	return _terrain.is_cell_occupied(_first_target_cell(ant, skill_id, cs))

func _body_cell(ant: Ant, cs: int) -> Vector2i:
	# WorkerState 공식 답습 — ant.y - 2.0 보정으로 발 끝이 아닌 body 중심 셀을 잡음.
	return Vector2i(
		int(floor(ant.global_position.x / cs)),
		int(floor((ant.global_position.y - 2.0) / cs))
	)

func _find_closest_ant(world: Vector2) -> Ant:
	# SkillToolbar._find_closest_ant 답습. CLICK_RADIUS 일치 — 동일 후보 풀.
	var ants: Array = get_tree().get_nodes_in_group("ants")
	var closest: Ant = null
	var best: float = CLICK_RADIUS
	for n in ants:
		var a: Ant = n as Ant
		if a == null or not a.is_alive():
			continue
		var d: float = a.global_position.distance_to(world)
		if d < best:
			best = d
			closest = a
	return closest

func _ensure_ghost_count(n: int) -> void:
	while _ghosts.size() < n:
		var p: Polygon2D = Polygon2D.new()
		add_child(p)
		_ghosts.append(p)

func _render(cells: Array[Vector2i], cs: int, blocked: bool) -> void:
	_ensure_ghost_count(cells.size())
	var color: Color = COLOR_BLOCKED if blocked else COLOR_OK
	for i in _ghosts.size():
		if i < cells.size():
			var c: Vector2i = cells[i]
			var p0: Vector2 = Vector2(float(c.x) * cs, float(c.y) * cs)
			_ghosts[i].polygon = PackedVector2Array([
				p0,
				p0 + Vector2(cs, 0),
				p0 + Vector2(cs, cs),
				p0 + Vector2(0, cs),
			])
			_ghosts[i].color = color
			_ghosts[i].visible = true
		else:
			_ghosts[i].visible = false

func _hide_all() -> void:
	for g in _ghosts:
		g.visible = false
