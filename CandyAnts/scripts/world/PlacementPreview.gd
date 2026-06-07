class_name PlacementPreview extends Node2D

# 장치(④) 스킬 선택 시 커서 아래 "설치 셀"에 결과 ghost 미리보기 (Phase 3 재작성).
# 대상은 카테고리 SoT 파생 — PLACEMENT_SKILLS 하드코딩 리스트 제거:
#   - ANT_ARMED(③ climber/bridge/builder): 무장이라 발동 위치가 나중 결정 → 탭-타임 ghost 없음.
#   - ANT_SETTLE(②): 정착폼 ghost(아트 Phase 7) → 현재 없음.
#   - SIGN(① sand_mound/basher/cutter/digger): **deferred 푯말 — 결과 ghost 없음**. 푯말은 열(x)에 설치되고
#     실제 작업은 그 열에 처음 도착한 개미의 body_cell에서 일어나(SkillSign._ant_at_cell + WorkerState),
#     설치 셀 ≠ 빌드 셀이 될 수 있다(다중 표면 컬럼). 설치 위치는 surface 글로우(Phase 2)가, 종류는
#     SIGN 커서가 표시하므로 결과 ghost는 오히려 위치를 오도 → 폐지(codex R1 MEDIUM, plan §0.8.2 "옵션").
#   - DEVICE(④ leaf_jump): SignPlacement.resolve_surface_install_cell 셀에 점프대 ghost 1칸. 장치는 그
#     셀에 결정적으로 설치되어(LeafJumpPad) 설치=빌드 셀이 항상 일치 → ghost 정확.

const COLOR_OK: Color = Color(0.4, 1.0, 0.4, 0.45)

@export var toolbar_path: NodePath
@export var terrain_path: NodePath

var _toolbar: SkillToolbar = null
var _terrain: Terrain = null
var _ghosts: Array[Polygon2D] = []

func _ready() -> void:
	_toolbar = get_node_or_null(toolbar_path) as SkillToolbar
	_terrain = get_node_or_null(terrain_path) as Terrain
	z_index = 100

func _process(_delta: float) -> void:
	if _toolbar == null or _terrain == null:
		_hide_all()
		return
	var pending: String = _toolbar._pending_skill_id
	if pending == "" or not SkillAffordance.SKILL_CATEGORY.has(pending):
		_hide_all()
		return
	var cells: Array[Vector2i] = _preview_cells(pending, get_global_mouse_position())
	if cells.is_empty():
		_hide_all()
		return
	_render(cells, _terrain.cell_size)

# 커서 위치 기준 결과 ghost 셀들. ghost 없는 카테고리/스킬은 빈 배열.
# 현재 결과 ghost를 그리는 카테고리는 DEVICE(④, 결정적 장치 설치)뿐. ①SIGN은 deferred라 폐지(상단 주석),
# ②③은 탭-타임 위치 미확정이라 없음.
func _preview_cells(skill_id: String, cursor_world: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _terrain == null:
		return out
	# DEVICE(④)만 결과 ghost. 그 외(ANT_ARMED③/ANT_SETTLE②/SIGN①)는 ghost 없음.
	if SkillAffordance.category_of(skill_id) != SkillAffordance.Category.DEVICE:
		return out
	var parent: Node = _terrain.get_parent()
	var res: Dictionary = SignPlacement.resolve_surface_install_cell(_terrain, skill_id, cursor_world, parent)
	if not res.get("valid", false):
		return out
	# 점프대 ghost 1칸 — 장치는 이 셀에 결정적으로 설치(설치=빌드 셀 일치).
	out.append(res["cell"])
	return out

func _ensure_ghost_count(n: int) -> void:
	while _ghosts.size() < n:
		var p: Polygon2D = Polygon2D.new()
		add_child(p)
		_ghosts.append(p)

func _render(cells: Array[Vector2i], cs: int) -> void:
	_ensure_ghost_count(cells.size())
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
			_ghosts[i].color = COLOR_OK
			_ghosts[i].visible = true
		else:
			_ghosts[i].visible = false

func _hide_all() -> void:
	for g in _ghosts:
		g.visible = false
