@tool
extends VBoxContainer

class GridPreview:
	extends Control

	signal tile_map_changed(tile_map: Dictionary)
	signal hazard_map_changed(hazard_map: Dictionary)

	# 게임 뷰포트 (project.godot window/size). 카메라 프레임 오버레이 환산용.
	const VIEW_W := 1920
	const VIEW_H := 1080
	# 카메라 프레임/콘텐츠 둘레 여유 칸 (좌측 배경 등 레벨 바깥도 보이도록).
	const MARGIN := 3
	# 폭주 방지 캔버스 상한 (cell).
	const MAX_SPAN := 400
	const TILE_SOLID := "solid"
	const TILE_SLOPE_RIGHT := "slope_right"
	const TILE_SLOPE_LEFT := "slope_left"
	# 실제 캠페인 터레인 — StageLayoutBuilder의 kind 문자열과 1:1 일치해야 함.
	const TILE_BACKGROUND := "background"  # 시각 채움(무충돌)
	const TILE_PLANT := "plant"            # 식물벽 (cutter 전용 파괴, S8)
	const TILE_COOKIE := "cookie"          # 불괴 구조 (S6)
	const TILE_SAND_MOUND := "sand_mound"  # 정적 막대과자 사다리 (스킬 없이 등반)
	const TILE_ERASE := "erase"
	# 해저드 브러시 — tile_map이 아니라 hazard_map에 칠해진다.
	const TILE_WATER := "water"
	const TILE_STICKY := "sticky"

	var tile_map: Dictionary = {}
	var hazard_map: Dictionary = {}
	var home_cell := Vector2i(2, 9)
	var candy_cell := Vector2i(18, 9)
	var camera_cell := Vector2i(11, 6)
	var settlement_cell := Vector2i(-1, -1)
	var preview_cell_size := 16
	# 실제 월드 cell_size (layout.cell_size). 카메라 프레임 = VIEW_W/H를 이 단위로 환산.
	var world_cell_size := 48
	var brush_tile_type := TILE_SOLID
	# 보이는 캔버스 영역. origin_cell은 음수 가능(= 레벨 경계 바깥 배경 포함).
	var origin_cell := Vector2i(0, 0)
	var cols := 48
	var rows := 30
	var _paint_button := 0

	func _init(next_preview_cell_size: int = 16) -> void:
		preview_cell_size = next_preview_cell_size
		mouse_filter = Control.MOUSE_FILTER_STOP
		_recompute_bounds()

	func set_platform_cells(cells: Array[Vector2i]) -> void:
		tile_map = {}
		for cell: Vector2i in cells:
			tile_map[_cell_key(cell)] = TILE_SOLID
		_recompute_bounds()
		queue_redraw()

	func set_tile_map(next_tile_map: Dictionary) -> void:
		tile_map = next_tile_map.duplicate()
		_recompute_bounds()
		queue_redraw()

	func set_hazard_map(next_hazard_map: Dictionary) -> void:
		hazard_map = next_hazard_map.duplicate()
		_recompute_bounds()
		queue_redraw()

	func set_brush_tile_type(next_tile_type: String) -> void:
		brush_tile_type = next_tile_type
		queue_redraw()

	func set_world_cell_size(next_world_cell_size: int) -> void:
		world_cell_size = maxi(1, next_world_cell_size)
		_recompute_bounds()
		queue_redraw()

	func set_markers(next_home_cell: Vector2i, next_candy_cell: Vector2i, next_camera_cell: Vector2i, next_settlement_cell: Vector2i = Vector2i(-1, -1)) -> void:
		home_cell = next_home_cell
		candy_cell = next_candy_cell
		camera_cell = next_camera_cell
		settlement_cell = next_settlement_cell
		_recompute_bounds()
		queue_redraw()

	# 카메라 월드 중심에서 화면(VIEW_W×VIEW_H)의 좌상단~우하단을 cell 인덱스 Rect으로 환산.
	func _camera_frame_cells() -> Rect2i:
		var cx := camera_cell.x * world_cell_size + world_cell_size / 2
		var cy := camera_cell.y * world_cell_size + world_cell_size / 2
		var left := floori(float(cx - VIEW_W / 2) / float(world_cell_size))
		var top := floori(float(cy - VIEW_H / 2) / float(world_cell_size))
		var right := floori(float(cx + VIEW_W / 2 - 1) / float(world_cell_size))
		var bottom := floori(float(cy + VIEW_H / 2 - 1) / float(world_cell_size))
		return Rect2i(left, top, right - left + 1, bottom - top + 1)

	# 캔버스 = 카메라 프레임 ∪ 모든 콘텐츠(타일·해저드·마커) + 여유. origin_cell은 음수 가능.
	func _recompute_bounds() -> void:
		var frame := _camera_frame_cells()
		var min_x := frame.position.x
		var min_y := frame.position.y
		var max_x := frame.position.x + frame.size.x - 1
		var max_y := frame.position.y + frame.size.y - 1
		var consider: Array[Vector2i] = [home_cell, candy_cell, camera_cell]
		if settlement_cell.x >= 0:
			consider.append(settlement_cell)
		for key in tile_map.keys():
			consider.append(_cell_from_key(str(key)))
		for key in hazard_map.keys():
			consider.append(_cell_from_key(str(key)))
		for c: Vector2i in consider:
			min_x = mini(min_x, c.x)
			min_y = mini(min_y, c.y)
			max_x = maxi(max_x, c.x)
			max_y = maxi(max_y, c.y)
		origin_cell = Vector2i(min_x - MARGIN, min_y - MARGIN)
		cols = clampi((max_x - min_x + 1) + MARGIN * 2, 1, MAX_SPAN)
		rows = clampi((max_y - min_y + 1) + MARGIN * 2, 1, MAX_SPAN)
		custom_minimum_size = Vector2(cols * preview_cell_size, rows * preview_cell_size)
		size = custom_minimum_size

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var button_event := event as InputEventMouseButton
			if button_event.button_index == MOUSE_BUTTON_LEFT or button_event.button_index == MOUSE_BUTTON_RIGHT:
				if button_event.pressed:
					_paint_button = button_event.button_index
					_apply_paint_at(button_event.position)
				else:
					_paint_button = 0
				accept_event()
		elif event is InputEventMouseMotion and _paint_button != 0:
			_apply_paint_at((event as InputEventMouseMotion).position)
			accept_event()

	func _draw() -> void:
		var canvas_px := Vector2(cols * preview_cell_size, rows * preview_cell_size)
		# 레벨 바깥(카메라 프레임 밖) = 어둡게.
		draw_rect(Rect2(Vector2.ZERO, canvas_px), Color(0.06, 0.06, 0.07, 1.0), true)
		# 카메라 프레임 내부 = 약간 밝게 (플레이어가 실제 보는 영역).
		var frame := _camera_frame_cells()
		var frame_rect := _cells_to_px_rect(frame)
		draw_rect(frame_rect, Color(0.13, 0.14, 0.17, 1.0), true)

		for key in tile_map.keys():
			var cell := _cell_from_key(str(key))
			if _is_cell_in_bounds(cell):
				_draw_tile(_cell_rect(cell).grow(-1.0), str(tile_map[key]))

		for hazard_key in hazard_map.keys():
			var hazard_cell := _cell_from_key(str(hazard_key))
			if _is_cell_in_bounds(hazard_cell):
				_draw_hazard(_cell_rect(hazard_cell).grow(-1.0), str(hazard_map[hazard_key]), hazard_cell)

		for x in range(cols + 1):
			var x_pos := float(x * preview_cell_size)
			var col_index := origin_cell.x + x
			var color := Color(1, 1, 1, 0.28) if col_index % 5 == 0 else Color(1, 1, 1, 0.10)
			draw_line(Vector2(x_pos, 0), Vector2(x_pos, canvas_px.y), color, 1.0)
		for y in range(rows + 1):
			var y_pos := float(y * preview_cell_size)
			var row_index := origin_cell.y + y
			var color := Color(1, 1, 1, 0.28) if row_index % 5 == 0 else Color(1, 1, 1, 0.10)
			draw_line(Vector2(0, y_pos), Vector2(canvas_px.x, y_pos), color, 1.0)

		# 레벨 원점(col 0 = 월드 x 0)을 초록 세로선으로 표시 → 어디가 보드 왼쪽 끝인지.
		var origin_x_px := float((0 - origin_cell.x) * preview_cell_size)
		if origin_x_px >= 0.0 and origin_x_px <= canvas_px.x:
			draw_line(Vector2(origin_x_px, 0), Vector2(origin_x_px, canvas_px.y), Color(0.3, 0.9, 0.5, 0.6), 2.0)

		_draw_marker(home_cell, Color(0.18, 0.85, 0.36), "H")
		_draw_marker(candy_cell, Color(1.0, 0.28, 0.62), "C")
		_draw_marker(camera_cell, Color(0.35, 0.65, 1.0), "K")
		if settlement_cell.x >= 0:
			_draw_marker(settlement_cell, Color(0.85, 0.75, 0.2), "S")

		# 카메라 프레임 외곽선 (= 플레이어 화면, 시안).
		draw_rect(frame_rect, Color(0.30, 0.85, 1.0, 0.95), false, 2.0)
		draw_rect(Rect2(Vector2.ZERO, canvas_px), Color(1, 1, 1, 0.20), false, 2.0)

	func _cells_to_px_rect(cell_rect: Rect2i) -> Rect2:
		var tl := Vector2(
			float((cell_rect.position.x - origin_cell.x) * preview_cell_size),
			float((cell_rect.position.y - origin_cell.y) * preview_cell_size)
		)
		return Rect2(tl, Vector2(cell_rect.size.x * preview_cell_size, cell_rect.size.y * preview_cell_size))

	func _apply_paint_at(position: Vector2) -> void:
		var cell := origin_cell + Vector2i(floori(position.x / preview_cell_size), floori(position.y / preview_cell_size))
		if not _is_cell_in_bounds(cell):
			return
		var key := _cell_key(cell)
		# 우클릭 또는 Erase 브러시 = 타일·해저드 모두 지움.
		if _paint_button == MOUSE_BUTTON_RIGHT or brush_tile_type == TILE_ERASE:
			var tile_erased := tile_map.erase(key)
			var hazard_erased := hazard_map.erase(key)
			if tile_erased or hazard_erased:
				queue_redraw()
			if tile_erased:
				tile_map_changed.emit(tile_map.duplicate())
			if hazard_erased:
				hazard_map_changed.emit(hazard_map.duplicate())
			return
		# 해저드 브러시 = hazard_map에 칠함.
		if brush_tile_type == TILE_WATER or brush_tile_type == TILE_STICKY:
			if hazard_map.get(key, "") != brush_tile_type:
				hazard_map[key] = brush_tile_type
				queue_redraw()
				hazard_map_changed.emit(hazard_map.duplicate())
			return
		# 일반 타일 브러시.
		if tile_map.get(key, "") != brush_tile_type:
			tile_map[key] = brush_tile_type
			queue_redraw()
			tile_map_changed.emit(tile_map.duplicate())

	func _draw_tile(rect: Rect2, tile_type: String) -> void:
		if tile_type == TILE_SLOPE_RIGHT:
			var points := PackedVector2Array([
				rect.position + Vector2(0, rect.size.y),
				rect.position + rect.size,
				rect.position + Vector2(rect.size.x, 0),
			])
			draw_colored_polygon(points, Color(0.94, 0.64, 0.28, 1.0))
			draw_polyline(points + PackedVector2Array([points[0]]), Color(0.45, 0.24, 0.12, 1.0), 1.0)
		elif tile_type == TILE_SLOPE_LEFT:
			var points := PackedVector2Array([
				rect.position,
				rect.position + Vector2(0, rect.size.y),
				rect.position + rect.size,
			])
			draw_colored_polygon(points, Color(0.94, 0.64, 0.28, 1.0))
			draw_polyline(points + PackedVector2Array([points[0]]), Color(0.45, 0.24, 0.12, 1.0), 1.0)
		else:
			# 타일 종류별 색 — builder 비주얼과 대략 일치(plant=녹색, cookie=차가운 청회색, background=어두운 채움).
			var fill := Color(0.92, 0.60, 0.28, 1.0)   # solid (걷는 면)
			var border := Color(0.45, 0.24, 0.12, 1.0)
			match tile_type:
				TILE_BACKGROUND:
					fill = Color(0.40, 0.26, 0.16, 1.0)
					border = Color(0.24, 0.15, 0.09, 1.0)
				TILE_PLANT:
					fill = Color(0.30, 0.66, 0.30, 1.0)
					border = Color(0.16, 0.38, 0.16, 1.0)
				TILE_COOKIE:
					fill = Color(0.60, 0.70, 0.95, 1.0)
					border = Color(0.32, 0.40, 0.62, 1.0)
				TILE_SAND_MOUND:
					fill = Color(0.85, 0.66, 0.35, 1.0)
					border = Color(0.54, 0.42, 0.18, 1.0)
			draw_rect(rect, fill, true)
			draw_rect(rect, border, false, 1.0)

	func _draw_hazard(rect: Rect2, hazard_type: String, cell: Vector2i) -> void:
		if hazard_type == TILE_STICKY:
			draw_rect(rect, Color(0.82, 0.52, 0.16, 0.55), true)
			draw_rect(rect, Color(0.55, 0.32, 0.08, 0.9), false, 1.0)
		else:
			# 수면(surface)=밝게 / 심부(deep, 바로 위도 물)=어둡게 — 런타임 soda surface/inner 구분과 일치.
			var above_is_water := str(hazard_map.get(_cell_key(Vector2i(cell.x, cell.y - 1)), "")) == TILE_WATER
			if above_is_water:
				draw_rect(rect, Color(0.10, 0.34, 0.78, 0.55), true)
				draw_rect(rect, Color(0.08, 0.22, 0.55, 0.9), false, 1.0)
			else:
				draw_rect(rect, Color(0.30, 0.62, 1.0, 0.5), true)
				draw_rect(rect, Color(0.12, 0.32, 0.7, 0.9), false, 1.0)

	func _draw_marker(cell: Vector2i, color: Color, label: String) -> void:
		if not _is_cell_in_bounds(cell):
			return
		var rect := _cell_rect(cell).grow(-2.0)
		draw_rect(rect, color, false, 2.0)
		var font := get_theme_default_font()
		var font_size := 11
		var text_pos := rect.position + Vector2(4, 12)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

	func _cell_rect(cell: Vector2i) -> Rect2:
		return Rect2(
			Vector2((cell.x - origin_cell.x) * preview_cell_size, (cell.y - origin_cell.y) * preview_cell_size),
			Vector2(preview_cell_size, preview_cell_size)
		)

	func _is_cell_in_bounds(cell: Vector2i) -> bool:
		return (
			cell.x >= origin_cell.x and cell.x < origin_cell.x + cols
			and cell.y >= origin_cell.y and cell.y < origin_cell.y + rows
		)

	func _cell_key(cell: Vector2i) -> String:
		return "%d,%d" % [cell.x, cell.y]

	func _cell_from_key(key: String) -> Vector2i:
		var parts := key.split(",", false)
		if parts.size() < 2:
			return Vector2i.ZERO
		return Vector2i(int(parts[0]), int(parts[1]))

var editor_interface: EditorInterface = null

# 미저장 변경(dirty) 추적. 제목/하단 패널 버튼에 `*` 표시.
signal dirty_changed(is_dirty: bool)
const BASE_TITLE := "CandyAnts Level"
var _dirty := false
var _suppress_dirty := true  # _ready/로드 중 프로그램적 값 변경이 dirty로 오인되지 않도록.
var _title_label: Label

# SkillRegistry.SKILL_SCRIPTS에 등록된 10종(= validate_stage 통과). distributor는 미등록이라 제외.
# leaf_jump(나뭇잎 점프대)은 설치형(SkillSign.SIGN_SKILLS)이지만 인벤토리 지급 방식은 일반 스킬과 동일 —
# Count>0이면 available_skills+skill_inventory에 등록되고 에디터 저장 시에도 보존된다.
const SKILL_IDS: Array[String] = [
	"builder", "blocker", "climber", "floater", "sand_mound",
	"bridge", "basher", "digger", "cutter", "leaf_jump",
]
const THEME_NAMES: Array[String] = [
	"cookie_crust", "cookie_segment", "thin_floor", "cookie_bridge_tile", "thin_bridge",
]
# 브러시 항목 — 도크/그리드 창 두 OptionButton이 동일 순서·id를 쓰도록 단일 SoT.
# id는 _selected_brush_tile_type() match와 일치. 창 동기화는 select(index) 기반이라
# 두 OptionButton의 표시 순서가 같아야 하므로 한 곳에서 채운다.
const BRUSH_ITEMS: Array = [
	["흙 타일", 0],
	["배경 (충돌 안함)", 6],
	["덩굴", 7],
	["파괴 불가 벽", 8],
	["사다리", 9],
	["물", 4],
	["점착 타일", 5],
	["지우기", 3],
]

func _populate_brush_option(option: OptionButton) -> void:
	for item in BRUSH_ITEMS:
		option.add_item(str(item[0]), int(item[1]))

var _id_spin: SpinBox
var _name_edit: LineEdit
var _total_ants_spin: SpinBox
var _candy_hp_spin: SpinBox
var _time_limit_spin: SpinBox
var _release_rate_spin: SpinBox
var _skill_spins: Dictionary = {}
var _theme_option: OptionButton
var _spawn_dir_option: OptionButton
var _spawn_alt_check: CheckBox
var _settlement_check: CheckBox
var _settlement_x_spin: SpinBox
var _settlement_y_spin: SpinBox
var _star_override_check: CheckBox
var _star_spins: Array[SpinBox] = []
var _hazard_map: Dictionary = {}
var _water_line_spin: SpinBox
var _cell_size_spin: SpinBox
var _home_cell_x_spin: SpinBox
var _home_cell_y_spin: SpinBox
var _candy_cell_x_spin: SpinBox
var _candy_cell_y_spin: SpinBox
var _camera_cell_x_spin: SpinBox
var _camera_cell_y_spin: SpinBox
var _platform_text: TextEdit
var _draft_text: TextEdit
var _brush_option: OptionButton
var _grid_preview: GridPreview
var _grid_window: Window
var _grid_window_preview: GridPreview
var _template_option: OptionButton
var _status_label: Label
var _syncing_grid := false
# 직전 저장에서 빈 스핀으로 인한 스킬 전멸을 막아 디스크 인벤토리를 보존했는지.
var _skills_preserved_on_save := false
# 스킬 편집의 진실원천(SoT)은 "Load한 스테이지의 스냅샷 + 스핀 편집"이다.
# 스핀 위젯은 _ready에서 0으로 초기화되므로, Load 없이 저장하면 스핀이 스테이지의 스킬을
# 대표하지 못한다. 어떤 스테이지를 Load했는지(_loaded_stage_id)와 그때의 전체 인벤토리
# 스냅샷(_loaded_skill_inventory: SKILL_IDS 밖 미지 스킬 포함)·표시 순서(_loaded_available_skills)를
# 보관해, 저장 시 스냅샷 위에 스핀 편집만 머지한다. -1 = 아직 아무 스테이지도 Load 안 함.
var _loaded_stage_id := -1
var _loaded_skill_inventory: Dictionary = {}
var _loaded_available_skills: Array = []
# 사용자가 직접 값을 바꾼 스킬 id 집합(skill_id -> true). Load 시 비움.
# 저장 시 이 집합에 든 스킬만 스핀 값으로 갱신/제거하고, 나머지는 스냅샷 값을 유지한다.
var _skill_user_edited: Dictionary = {}

func _ready() -> void:
	name = "CandyAnts Level"
	custom_minimum_size = Vector2(300, 0)

	_title_label = Label.new()
	_title_label.text = BASE_TITLE
	_title_label.add_theme_font_size_override("font_size", 18)
	add_child(_title_label)

	_id_spin = _add_spin("Stage ID", 4, 1, 99, 1)
	_name_edit = _add_line_edit("Name", "새 스테이지")
	var stage_actions := HBoxContainer.new()
	var load_button := Button.new()
	load_button.text = "Load Stage"
	load_button.pressed.connect(_load_stage)
	stage_actions.add_child(load_button)
	var save_button := Button.new()
	save_button.text = "Save Stage"
	save_button.pressed.connect(_save_existing_stage)
	stage_actions.add_child(save_button)
	add_child(stage_actions)

	_add_section("웹 드래프트 (아이패드 → 가져오기)")
	var draft_hint := Label.new()
	draft_hint.text = "tools/level_editor.html에서 '드래프트 내보내기'한 JSON을 붙여넣고 가져오기. 가져온 뒤 Stage ID 확인 → 씬 실행으로 클리어 검증 → Save Stage."
	draft_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(draft_hint)
	_draft_text = TextEdit.new()
	_draft_text.custom_minimum_size = Vector2(0, 90)
	_draft_text.placeholder_text = "candyants-level-draft JSON 붙여넣기"
	add_child(_draft_text)
	var import_draft_button := Button.new()
	import_draft_button.text = "웹 드래프트 가져오기"
	import_draft_button.pressed.connect(_import_web_draft_from_text)
	add_child(import_draft_button)

	_total_ants_spin = _add_spin("Ants", 10, 1, 200, 1)
	_candy_hp_spin = _add_spin("Candy HP", 10, 1, 999, 1)
	_time_limit_spin = _add_spin("Time Limit", 180, 10, 999, 5)
	_release_rate_spin = _add_spin("Release Rate", 30, 1, 99, 1)

	_add_section("Skills")
	var skills_hint := Label.new()
	skills_hint.text = "Count 0 = 미사용. Count > 0 = available_skills + skill_inventory에 등록."
	skills_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(skills_hint)
	for skill_id: String in SKILL_IDS:
		_skill_spins[skill_id] = _add_spin(skill_id, 0, 0, 99, 1)

	_add_section("Stage Meta")
	_spawn_dir_option = OptionButton.new()
	_spawn_dir_option.add_item("Right (+1)", 1)
	_spawn_dir_option.add_item("Left (-1)", 0)
	add_child(_labeled_control("Spawn Dir", _spawn_dir_option))
	_spawn_alt_check = CheckBox.new()
	_spawn_alt_check.text = "Alternate spawn direction"
	add_child(_spawn_alt_check)

	_theme_option = OptionButton.new()
	for theme_index in range(THEME_NAMES.size()):
		_theme_option.add_item(THEME_NAMES[theme_index], theme_index)
	add_child(_labeled_control("Theme", _theme_option))

	_settlement_check = CheckBox.new()
	_settlement_check.text = "Use settlement marker (분배자)"
	_settlement_check.toggled.connect(_on_settlement_toggled)
	add_child(_settlement_check)
	_settlement_x_spin = _add_spin("Settle Cell X", 30, -200, 200, 1)
	_settlement_y_spin = _add_spin("Settle Cell Y", 27, -200, 200, 1)
	_settlement_x_spin.editable = false
	_settlement_y_spin.editable = false
	_settlement_x_spin.value_changed.connect(_on_marker_spin_changed)
	_settlement_y_spin.value_changed.connect(_on_marker_spin_changed)

	_star_override_check = CheckBox.new()
	_star_override_check.text = "Override star thresholds (off = 글로벌 fallback)"
	_star_override_check.toggled.connect(_on_star_override_toggled)
	add_child(_star_override_check)
	var star_defaults := [0.6, 0.8, 1.0]
	for star_index in range(3):
		var star_spin := _add_spin("Star %d" % (star_index + 1), star_defaults[star_index], 0.0, 1.0, 0.05)
		star_spin.editable = false
		_star_spins.append(star_spin)

	_add_section("Layout")
	_cell_size_spin = _add_spin("Cell Size", 32, 8, 128, 8)
	_home_cell_x_spin = _add_spin("Home Cell X", 12, -200, 200, 1)
	_home_cell_y_spin = _add_spin("Home Cell Y", 27, -200, 200, 1)
	_candy_cell_x_spin = _add_spin("Candy Cell X", 44, -200, 200, 1)
	_candy_cell_y_spin = _add_spin("Candy Cell Y", 27, -200, 200, 1)
	_camera_cell_x_spin = _add_spin("Camera Cell X", 30, -200, 200, 1)
	_camera_cell_y_spin = _add_spin("Camera Cell Y", 17, -200, 200, 1)

	_template_option = OptionButton.new()
	_template_option.add_item("Flat ground", 0)
	_template_option.add_item("Two platforms", 1)
	_template_option.add_item("Reverse long platform", 2)
	_template_option.item_selected.connect(_on_template_selected)
	add_child(_labeled_control("Template", _template_option))

	_platform_text = TextEdit.new()
	_platform_text.custom_minimum_size = Vector2(0, 160)
	_platform_text.placeholder_text = "x,y,length per line. Example: 8,27,45"
	_platform_text.text = _template_text(0)
	_platform_text.text_changed.connect(_sync_grid_from_controls)
	add_child(_labeled_control("Platform Runs", _platform_text))

	_brush_option = OptionButton.new()
	_populate_brush_option(_brush_option)
	_brush_option.item_selected.connect(_on_brush_selected)
	add_child(_labeled_control("Brush", _brush_option))

	_add_section("Auto Water (수위선)")
	var water_fill_hint := Label.new()
	water_fill_hint.text = "수위선 y 이하 ~ 레벨 바닥까지, 지면/해저드가 없는 빈 칸을 물로 채웁니다. (좌우·하단 범위 = 지면 경계 상자, Home/Candy/분배자 셀 제외)"
	water_fill_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(water_fill_hint)
	_water_line_spin = _add_spin("Water Line Y", 10, -200, 200, 1)
	var fill_water_button := Button.new()
	fill_water_button.text = "수위선 아래 빈 공간 물 채우기"
	fill_water_button.pressed.connect(_fill_water_below_line)
	add_child(fill_water_button)

	_add_section("Grid Preview")
	var grid_hint := Label.new()
	grid_hint.text = "좌클릭=칠 / 우클릭=지움. 시안 사각형 = 플레이어 화면(카메라). 초록 세로선 = 레벨 원점(col 0). 그 왼쪽(음수 칸)도 칠할 수 있음."
	grid_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(grid_hint)

	var open_grid_button := Button.new()
	open_grid_button.text = "Open Grid Editor"
	open_grid_button.pressed.connect(_open_grid_editor)
	add_child(open_grid_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_grid_preview = GridPreview.new(12)
	_grid_preview.tile_map_changed.connect(_on_grid_tile_map_changed)
	_grid_preview.hazard_map_changed.connect(_on_grid_hazard_map_changed)
	scroll.add_child(_grid_preview)
	add_child(scroll)

	_create_grid_window()

	var create_button := Button.new()
	create_button.text = "Create Stage"
	create_button.pressed.connect(func() -> void:
		_save_stage(false)
	)
	add_child(create_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Creates stage data, grid layout data, and a stage scene."
	add_child(_status_label)

	_connect_layout_spins()
	_sync_grid_from_controls()
	_connect_dirty_tracking()
	_suppress_dirty = false
	_set_dirty(false)

func _add_section(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	add_child(label)

func _add_line_edit(label_text: String, default_text: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = default_text
	add_child(_labeled_control(label_text, edit))
	return edit

func _add_spin(label_text: String, value: float, min_value: float, max_value: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	# CRITICAL: 기본값(false)이면 타이핑한 숫자가 Enter/포커스이탈 전까지 .value 에 반영되지 않는다.
	# Save 가 .value 를 직접 읽으므로, 사용자가 스킬/파라미터를 타이핑한 뒤 곧바로 Save 를 누르면
	# 미커밋 값(직전 값, 흔히 0)이 저장돼 스킬 인벤토리가 통째로 비워진다(=스킬 HUD 사라짐).
	# true 로 켜서 키 입력마다 즉시 .value 갱신.
	spin.update_on_text_changed = true
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_labeled_control(label_text, spin))
	return spin

func _labeled_control(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 100
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row

# Save 직전, 아직 커밋되지 않은 SpinBox 타이핑(포커스가 spin 안에 남아 있는 경우)을 강제 반영.
# update_on_text_changed=true 와 중복이지만, 어떤 경로로든 미커밋 값이 .value 로 새지 않도록 이중 방어.
func _commit_pending_spins(node: Node) -> void:
	for child in node.get_children():
		if child is SpinBox:
			(child as SpinBox).apply()
		_commit_pending_spins(child)

func _save_stage(overwrite: bool) -> void:
	_commit_pending_spins(self)
	var stage_id := int(_id_spin.value)
	var stage_name := _name_edit.text.strip_edges()
	if stage_name.is_empty():
		_set_status("Name is required.", true)
		return

	var data_path := "res://data/stages/stage%02d.tres" % stage_id
	var layout_path := "res://data/stage_layouts/stage%02d_layout.tres" % stage_id
	var scene_path := "res://scenes/stages/Stage%02d.tscn" % stage_id
	if not overwrite and (ResourceLoader.exists(data_path) or ResourceLoader.exists(layout_path) or ResourceLoader.exists(scene_path)):
		_set_status("Stage %02d already exists." % stage_id, true)
		return

	# 사전검증: Load하지 않은 기존 stage를 덮어쓸 때(= 저장 시 스킬을 디스크에서 보존해야 하는 (B) 경로),
	# 그 파일이 손상돼 읽을 수 없으면 스킬을 안전하게 보존할 수 없다. 어떤 파일도 쓰기 전에 중단해
	# layout만 갱신되는 부분 저장을 막는다. (_build_stage_data 의 null 반환은 방어선으로 유지.)
	if (_loaded_stage_id != stage_id) and ResourceLoader.exists(data_path):
		if ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_IGNORE) == null:
			_set_status("기존 Stage%02d 데이터를 읽을 수 없어 저장을 중단했습니다(스킬 손실 방지). 파일을 확인하거나 먼저 Load 하세요." % stage_id, true)
			return

	var layout_data := _build_layout_data()
	if layout_data.platform_cells.is_empty():
		_set_status("At least one platform cell is required.", true)
		return

	var layout_result := _save_resource(layout_data, layout_path)
	if layout_result != OK:
		_set_status("Failed to save %s: %s" % [layout_path, error_string(layout_result)], true)
		return

	var stage_data := _build_stage_data(stage_id, stage_name, scene_path, layout_path, data_path)
	if stage_data == null:
		# 기존 Stage 파일을 못 읽어 스킬을 안전하게 보존할 수 없음 → 빈 값 덮어쓰기 방지로 중단.
		_set_status("기존 Stage%02d 데이터를 읽을 수 없어 저장을 중단했습니다(스킬 손실 방지). 파일을 확인하거나 먼저 Load 하세요." % stage_id, true)
		return
	var data_result := _save_resource(stage_data, data_path)
	if data_result != OK:
		_set_status("Failed to save %s: %s" % [data_path, error_string(data_result)], true)
		return

	var scene_root := _build_stage_scene(stage_data)
	var packed := PackedScene.new()
	var pack_result := packed.pack(scene_root)
	scene_root.queue_free()
	if pack_result != OK:
		_set_status("Failed to pack scene: %s" % error_string(pack_result), true)
		return

	var scene_result := _save_resource(packed, scene_path)
	if scene_result != OK:
		_set_status("Failed to save %s: %s" % [scene_path, error_string(scene_result)], true)
		return

	if editor_interface != null:
		editor_interface.get_resource_filesystem().scan()
		editor_interface.open_scene_from_path(scene_path)

	var status_text := "%s Stage%02d." % ["Saved" if overwrite else "Created", stage_id]
	if _skills_preserved_on_save:
		status_text += " (이 스테이지를 Load하지 않아 기존 스킬 인벤토리를 그대로 보존함 — 스킬을 편집하려면 먼저 Load Stage 후 저장하세요.)"
	_set_status(status_text, false)
	_set_dirty(false)

func _save_resource(resource: Resource, path: String) -> int:
	resource.take_over_path(path)
	return ResourceSaver.save(resource)

func _save_existing_stage() -> void:
	_save_stage(true)

func _load_stage() -> void:
	var stage_id := int(_id_spin.value)
	var data_path := "res://data/stages/stage%02d.tres" % stage_id
	if not ResourceLoader.exists(data_path):
		_set_status("Missing %s." % data_path, true)
		return
	var stage_data := ResourceLoader.load(data_path)
	if stage_data == null:
		_set_status("Failed to load %s." % data_path, true)
		return

	# 로드 중 프로그램적 값 변경이 dirty로 오인되지 않도록 억제.
	_suppress_dirty = true
	_name_edit.text = stage_data.display_name if "display_name" in stage_data else ""
	_total_ants_spin.value = stage_data.total_ants if "total_ants" in stage_data else 10
	_candy_hp_spin.value = stage_data.candy_hp if "candy_hp" in stage_data else 10
	_time_limit_spin.value = stage_data.time_limit_seconds if "time_limit_seconds" in stage_data else 180
	_release_rate_spin.value = stage_data.release_rate_initial if "release_rate_initial" in stage_data else 30
	var inventory: Dictionary = stage_data.skill_inventory if "skill_inventory" in stage_data else {}
	for skill_id: String in SKILL_IDS:
		_skill_spins[skill_id].value = int(inventory.get(skill_id, 0))
	# 저장 시 머지 기준이 될 로드-시점 스냅샷. 캐시 리소스가 이후 손상돼도 이 값은 불변.
	# 전체 인벤토리(미지 스킬 포함)와 표시 순서를 깊은 복사로 분리 보관한다.
	_loaded_stage_id = stage_id
	_loaded_skill_inventory = inventory.duplicate(true)
	var loaded_skills: Array = stage_data.available_skills if "available_skills" in stage_data else []
	_loaded_available_skills = loaded_skills.duplicate()
	# 방금 Load한 값은 사용자 편집이 아니므로 편집 추적을 리셋한다.
	_skill_user_edited.clear()

	var stars: Array = stage_data.star_thresholds if "star_thresholds" in stage_data else []
	_star_override_check.button_pressed = not stars.is_empty()
	for star_index in range(_star_spins.size()):
		if star_index < stars.size():
			_star_spins[star_index].value = float(stars[star_index])
		_star_spins[star_index].editable = not stars.is_empty()

	var layout_data := _load_or_default_layout(stage_id)
	_apply_layout_data(layout_data)
	_suppress_dirty = false
	_set_dirty(false)
	_set_status("Loaded Stage%02d. Use Save Stage to overwrite existing files." % stage_id, false)

# 웹 레벨 에디터(tools/level_editor.html)의 "드래프트(레퍼런스 JSON)"를 가져온다.
# HTML 툴은 개미 물리·클리어를 검증할 수 없어 실 스테이지를 만들지 않고 드래프트만 내보낸다 —
# 여기서 받아 필드를 채운 뒤, 사용자가 씬을 실행해 클리어를 확인하고 Save Stage 해야 실 스테이지가 된다.
func _import_web_draft_from_text() -> void:
	var text := _draft_text.text.strip_edges()
	if text.is_empty():
		_set_status("드래프트 JSON을 붙여넣으세요.", true)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_set_status("JSON 파싱 실패 — candyants-level-draft 형식인지 확인하세요.", true)
		return
	var draft: Dictionary = parsed
	if str(draft.get("format", "")) != "candyants-level-draft":
		_set_status("형식이 candyants-level-draft가 아닙니다('드래프트 내보내기'로 받은 JSON인지 확인).", true)
		return
	_apply_web_draft(draft)

func _apply_web_draft(draft: Dictionary) -> void:
	_suppress_dirty = true
	var script := load("res://scripts/core/StageLayoutData.gd") as Script
	var layout: Resource = script.new()
	layout.cell_size = int(draft.get("cellSize", 48))
	layout.home_cell = _draft_cell(draft.get("homeCell"))
	layout.candy_cell = _draft_cell(draft.get("candyCell"))
	layout.camera_cell = _draft_cell(draft.get("cameraCell"))
	layout.tile_map = _draft_string_map(draft.get("tileMap"))
	layout.hazard_map = _draft_string_map(draft.get("hazardMap"))
	layout.spawn_direction = int(draft.get("spawnDirection", 1))
	layout.spawn_direction_alternate = bool(draft.get("spawnAlternate", false))
	layout.theme = str(draft.get("theme", "cookie_crust"))
	var settle_on := bool(draft.get("settlementOn", false))
	layout.settlement_cell = _draft_cell(draft.get("settlementCell")) if settle_on else Vector2i(-1, -1)
	_apply_layout_data(layout)
	# 스테이지 파라미터.
	_id_spin.value = int(draft.get("stageId", 1))
	_name_edit.text = str(draft.get("name", ""))
	_total_ants_spin.value = int(draft.get("totalAnts", 10))
	_candy_hp_spin.value = int(draft.get("candyHp", 10))
	_time_limit_spin.value = float(draft.get("timeLimit", 120.0))
	_release_rate_spin.value = int(draft.get("releaseRate", 30))
	# 스킬 — 드래프트 값을 스핀에 반영하고, 저장 시 권위가 되도록 '로드한 스테이지' 스냅샷으로 등록한다
	# (_build_stage_data (A) 경로: 같은 ID로 Save 시 스냅샷=드래프트 스킬이 그대로 기록).
	var skills: Dictionary = draft.get("skills", {}) if draft.get("skills") is Dictionary else {}
	var inventory := {}
	var order: Array[String] = []
	for skill_id: String in SKILL_IDS:
		var count := int(skills.get(skill_id, 0))
		_skill_spins[skill_id].value = count
		if count > 0:
			inventory[skill_id] = count
			order.append(skill_id)
	_loaded_stage_id = int(draft.get("stageId", -1))
	_loaded_skill_inventory = inventory.duplicate(true)
	_loaded_available_skills = order.duplicate()
	_skill_user_edited.clear()
	_suppress_dirty = false
	_set_dirty(true)
	_set_status("웹 드래프트를 가져왔습니다. Stage ID 확인 → 씬 실행으로 클리어 검증 후 Save Stage 하세요.", false)

func _draft_cell(raw: Variant) -> Vector2i:
	if raw is Dictionary:
		return Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
	return Vector2i.ZERO

func _draft_string_map(raw: Variant) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for key in raw.keys():
			out[str(key)] = str(raw[key])
	return out

func _build_stage_data(stage_id: int, stage_name: String, _scene_path: String, layout_path: String, data_path: String) -> Resource:
	var stage_data: Resource = ResourceLoader.load(data_path) if ResourceLoader.exists(data_path) else null
	if stage_data == null:
		var script := load("res://scripts/core/StageData.gd") as Script
		stage_data = script.new()
	stage_data.id = stage_id
	stage_data.display_name = stage_name
	var layout_ref: Resource = ResourceLoader.load(layout_path) if ResourceLoader.exists(layout_path) else null
	stage_data.layout = layout_ref if layout_ref != null else _build_layout_data()
	stage_data.total_ants = int(_total_ants_spin.value)
	stage_data.candy_hp = int(_candy_hp_spin.value)
	stage_data.time_limit_seconds = float(_time_limit_spin.value)
	stage_data.release_rate_initial = int(_release_rate_spin.value)
	stage_data.release_rate_min = 1
	# 스킬 인벤토리 — 데이터 손실 방지가 최우선. 판정 기준 = "이 stage 를 Load했는가 + 대상 파일이 존재하는가".
	# 스킬 스핀/스냅샷/편집추적은 '마지막에 Load한 스테이지'에 대해서만 유효하다(다른 ID로 저장 시 무의미).
	# (A) 이 stage_id 를 Load했으면 → 로드 스냅샷 위에 '사용자가 실제 건드린' 스킬만 머지.
	#     스냅샷 시작점이라 SKILL_IDS 밖 미지 스킬(은퇴 distributor·미래 스킬) 보존, 안 건드린 스킬은 스냅샷 유지
	#     (허위 0으로 인한 오삭제 방지). 건드린 스킬은 >0 갱신 / 0 제거(= '스킬 없는 스테이지'도 정상 저작).
	#     순서 = 기존 순서 우선 + 새 known 스킬 append + 잔여 미지 스킬 append.
	# (B) Load 안 한 기존 파일(target_exists) → 디스크의 스킬 필드를 통째로 보존(스핀·스냅샷 전부 무시).
	#     '로드하지 않은 스테이지를 다른 ID로 덮어쓰기'가 디스크 스킬을 오염·전멸시키는 사고를 막는다.
	# (C) Load 안 한 신규 파일 → raw 스핀 값(>0)을 그대로 기록(보존할 디스크 데이터가 없음).
	_skills_preserved_on_save = false
	var loaded_this_stage := (_loaded_stage_id == stage_id)
	var target_exists := ResourceLoader.exists(data_path)
	if loaded_this_stage:
		# (A) 스냅샷 + 편집 머지.
		var base_inventory: Dictionary = _loaded_skill_inventory.duplicate(true)
		var base_order: Array = _loaded_available_skills.duplicate()
		for skill_id: String in SKILL_IDS:
			if not _skill_user_edited.get(skill_id, false):
				continue  # 안 건드린 스킬은 스냅샷 값 유지.
			var count := int(_skill_spins[skill_id].value)
			if count > 0:
				base_inventory[skill_id] = count
			else:
				base_inventory.erase(skill_id)
		var ordered_skills: Array[String] = []
		for raw in base_order:  # 기존 표시 순서 유지(보존된 스킬만).
			var sid := str(raw)
			if base_inventory.has(sid) and not ordered_skills.has(sid):
				ordered_skills.append(sid)
		for skill_id: String in SKILL_IDS:  # 새로 추가된 known 스킬.
			if base_inventory.has(skill_id) and not ordered_skills.has(skill_id):
				ordered_skills.append(skill_id)
		for raw_key in base_inventory.keys():  # 순서에 없던 미지 스킬도 누락 없이 보존.
			var kid := str(raw_key)
			if not ordered_skills.has(kid):
				ordered_skills.append(kid)
		stage_data.skill_inventory = base_inventory
		stage_data.available_skills = ordered_skills
	elif target_exists:
		# (B) 보존 — 캐시가 아닌 디스크 원본을 다시 읽어(CACHE_MODE_IGNORE) 스킬 필드를 신뢰성 있게 보존한다.
		# (캐시된 stage_data 는 직전 손상 저장으로 빈 값일 수 있어 디스크 진실과 다를 수 있음.)
		# 기존 파일이 손상돼 못 읽으면 빈 값으로 덮어써 데이터를 잃으므로 저장을 중단한다(null 반환).
		var disk_copy: Resource = ResourceLoader.load(data_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if disk_copy == null:
			return null
		var disk_inventory: Dictionary = (disk_copy.skill_inventory.duplicate(true)
			if ("skill_inventory" in disk_copy and disk_copy.skill_inventory is Dictionary) else {})
		var disk_order: Array = (disk_copy.available_skills
			if ("available_skills" in disk_copy and disk_copy.available_skills is Array) else [])
		# 인벤토리 기준으로 순서를 정규화(디스크 순서 우선 + 누락 키 append) → 손상/불일치 데이터도 유효하게 보존.
		var preserved_skills: Array[String] = []
		for raw in disk_order:
			var sid := str(raw)
			if disk_inventory.has(sid) and not preserved_skills.has(sid):
				preserved_skills.append(sid)
		for raw_key in disk_inventory.keys():
			var kid := str(raw_key)
			if not preserved_skills.has(kid):
				preserved_skills.append(kid)
		stage_data.skill_inventory = disk_inventory
		stage_data.available_skills = preserved_skills
		_skills_preserved_on_save = true
	else:
		# (C) 신규 파일 → 현재 스핀 값 그대로(= 보이는 대로 생성). 보존할 디스크 데이터가 없다.
		# 주의(deferred): 다른 stage를 Load한 뒤 새 ID로 Create하면 스냅샷의 SKILL_IDS 밖 미지 스킬은
		# 복제되지 않는다(스핀은 SKILL_IDS만 표현). 현재 데이터에 미지 스킬이 없어 무해.
		var spin_inventory := {}
		var new_skills: Array[String] = []
		for skill_id: String in SKILL_IDS:
			var count := int(_skill_spins[skill_id].value)
			if count > 0:
				spin_inventory[skill_id] = count
				new_skills.append(skill_id)
		stage_data.skill_inventory = spin_inventory
		stage_data.available_skills = new_skills
	# 별 규칙 전역화(2026-06-08) — StageData.star_thresholds 필드 폐지. 별 override UI는 비활성(no-op).
	return stage_data

func _build_layout_data() -> Resource:
	var script := load("res://scripts/core/StageLayoutData.gd") as Script
	var layout_data: Resource = script.new()
	layout_data.cell_size = int(_cell_size_spin.value)
	layout_data.home_cell = Vector2i(int(_home_cell_x_spin.value), int(_home_cell_y_spin.value))
	layout_data.candy_cell = Vector2i(int(_candy_cell_x_spin.value), int(_candy_cell_y_spin.value))
	layout_data.camera_cell = Vector2i(int(_camera_cell_x_spin.value), int(_camera_cell_y_spin.value))
	layout_data.tile_map = _parse_tile_map(_platform_text.text)
	layout_data.platform_cells = _tile_map_to_platform_cells(layout_data.tile_map)
	layout_data.hazard_map = _hazard_map.duplicate()
	layout_data.spawn_direction = 1 if _spawn_dir_option.get_selected_id() == 1 else -1
	layout_data.spawn_direction_alternate = _spawn_alt_check.button_pressed
	layout_data.theme = THEME_NAMES[clampi(_theme_option.get_selected_id(), 0, THEME_NAMES.size() - 1)]
	layout_data.settlement_cell = _current_settlement_cell()
	return layout_data

func _load_or_default_layout(stage_id: int) -> Resource:
	var layout_path := "res://data/stage_layouts/stage%02d_layout.tres" % stage_id
	if ResourceLoader.exists(layout_path):
		var loaded := ResourceLoader.load(layout_path)
		if loaded != null:
			return loaded
	return _default_layout_for_stage(stage_id)

func _default_layout_for_stage(stage_id: int) -> Resource:
	var script := load("res://scripts/core/StageLayoutData.gd") as Script
	var layout_data: Resource = script.new()
	layout_data.cell_size = 32
	if stage_id == 2:
		layout_data.platform_cells = _parse_platform_cells("9,27,19\n33,27,19")
		layout_data.tile_map = _parse_tile_map("9,27,19\n33,27,19")
		layout_data.home_cell = Vector2i(12, 27)
		layout_data.candy_cell = Vector2i(44, 27)
		layout_data.camera_cell = Vector2i(30, 17)
	elif stage_id == 3:
		layout_data.platform_cells = _parse_platform_cells("19,27,38")
		layout_data.tile_map = _parse_tile_map("19,27,38")
		layout_data.home_cell = Vector2i(53, 27)
		layout_data.candy_cell = Vector2i(22, 27)
		layout_data.camera_cell = Vector2i(38, 17)
		layout_data.spawn_direction = 1
		layout_data.spawn_direction_alternate = true
	else:
		layout_data.platform_cells = _parse_platform_cells("0,27,60")
		layout_data.tile_map = _parse_tile_map("0,27,60")
		layout_data.home_cell = Vector2i(12, 27)
		layout_data.candy_cell = Vector2i(44, 27)
		layout_data.camera_cell = Vector2i(30, 17)
	return layout_data

func _apply_layout_data(layout_data: Resource) -> void:
	_cell_size_spin.value = layout_data.cell_size if "cell_size" in layout_data else 32
	_home_cell_x_spin.value = layout_data.home_cell.x if "home_cell" in layout_data else 12
	_home_cell_y_spin.value = layout_data.home_cell.y if "home_cell" in layout_data else 27
	_candy_cell_x_spin.value = layout_data.candy_cell.x if "candy_cell" in layout_data else 44
	_candy_cell_y_spin.value = layout_data.candy_cell.y if "candy_cell" in layout_data else 27
	_camera_cell_x_spin.value = layout_data.camera_cell.x if "camera_cell" in layout_data else 30
	_camera_cell_y_spin.value = layout_data.camera_cell.y if "camera_cell" in layout_data else 17
	if "tile_map" in layout_data and not layout_data.tile_map.is_empty():
		_platform_text.text = _format_tile_map(layout_data.tile_map)
	elif "platform_cells" in layout_data:
		_platform_text.text = _format_platform_cells(layout_data.platform_cells)
	else:
		_platform_text.text = ""

	_hazard_map = layout_data.hazard_map.duplicate() if "hazard_map" in layout_data else {}

	var spawn_dir: int = layout_data.spawn_direction if "spawn_direction" in layout_data else 1
	_spawn_dir_option.select(_spawn_dir_option.get_item_index(1 if spawn_dir >= 0 else 0))
	_spawn_alt_check.button_pressed = layout_data.spawn_direction_alternate if "spawn_direction_alternate" in layout_data else false

	var theme_name: String = layout_data.theme if "theme" in layout_data else "cookie_crust"
	var theme_index := THEME_NAMES.find(theme_name)
	_theme_option.select(_theme_option.get_item_index(theme_index if theme_index >= 0 else 0))

	var settle_cell: Vector2i = layout_data.settlement_cell if "settlement_cell" in layout_data else Vector2i(-1, -1)
	var settle_enabled := settle_cell.x >= 0
	_settlement_check.button_pressed = settle_enabled
	_settlement_x_spin.editable = settle_enabled
	_settlement_y_spin.editable = settle_enabled
	if settle_enabled:
		_settlement_x_spin.value = settle_cell.x
		_settlement_y_spin.value = settle_cell.y

	_sync_grid_from_controls()

func _build_stage_scene(stage_data: Resource) -> Node:
	var root := Node.new()
	root.name = "StageRunner"
	root.set_script(load("res://scripts/core/StageRunner.gd"))
	root.stage_data = stage_data
	root.candy_path = NodePath("World/Candy")
	root.home_path = NodePath("World/Home")
	root.spawner_path = NodePath("Spawner")
	root.hud_path = NodePath("HUD")
	root.ant_scene = load("res://scenes/entities/Ant.tscn") as PackedScene
	root.spawn_parent_path = NodePath("World")

	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	world.owner = root

	var background := _instance_scene("res://scenes/world/StageBackground.tscn", "StageBackground")
	root.add_child(background)
	background.owner = root

	_add_layout_builder(world, stage_data.layout)
	_add_terrain(world)
	_add_placement_preview(world)
	# Home/Candy는 원점이 바닥인 엔티티(충돌이 위로 뻗음) → 셀 중심(cell_to_world)이 아니라
	# 셀 바닥(=지면 표면)에 배치해야 지면에 닿는다. _cell_to_surface 사용 (정상 Stage04 패턴).
	_add_entity(world, "res://scenes/entities/Home.tscn", "Home", _cell_to_surface(stage_data.layout, stage_data.layout.home_cell))
	var candy := _add_entity(world, "res://scenes/entities/Candy.tscn", "Candy", _cell_to_surface(stage_data.layout, stage_data.layout.candy_cell))
	candy.hp = int(_candy_hp_spin.value)
	_add_hazards(world, stage_data.layout)
	_add_camera(world, stage_data.layout)
	_add_spawner(root, stage_data.layout)
	_add_hud(root)
	if not stage_data.available_skills.is_empty():
		_add_skill_toolbar(root, stage_data)

	return root

func _instance_scene(path: String, node_name: String) -> Node:
	var packed := load(path) as PackedScene
	var node := packed.instantiate()
	node.name = node_name
	return node

func _add_entity(parent: Node, path: String, node_name: String, position: Vector2) -> Node2D:
	var node := _instance_scene(path, node_name) as Node2D
	node.position = position
	parent.add_child(node)
	node.owner = parent.owner
	return node

# 셀의 가로 중심 + 세로 바닥 모서리(=지면 표면). 바닥 앵커 엔티티(Home/Candy) 배치용.
# cell_to_world(중심)와 달리 Y를 (cell.y+1)*cell_size로 내려 지면에 닿게 한다.
func _cell_to_surface(layout: Resource, cell: Vector2i) -> Vector2:
	var center: Vector2 = layout.cell_to_world(cell)
	var cs: int = int(layout.cell_size)
	return Vector2(center.x, float((cell.y + 1) * cs))

# 설치형 스킬 ghost 미리보기 노드. SkillToolbar가 없어도 _process가 null-guard로 무해.
# (toolbar_path/terrain_path는 런타임 _ready에서 해석되므로 노드 추가 순서와 무관)
func _add_placement_preview(world: Node2D) -> void:
	var preview := Node2D.new()
	preview.name = "PlacementPreview"
	preview.set_script(load("res://scripts/world/PlacementPreview.gd"))
	world.add_child(preview)
	preview.owner = world.owner
	preview.set("toolbar_path", NodePath("../../SkillToolbar"))
	preview.set("terrain_path", NodePath("../Terrain"))

func _add_layout_builder(world: Node2D, layout_data: Resource) -> void:
	var builder := Node2D.new()
	builder.name = "StageLayoutBuilder"
	builder.set_script(load("res://scripts/world/StageLayoutBuilder.gd"))
	world.add_child(builder)
	_set_scene_owner(builder, world.owner)
	builder.set("layout", layout_data)
	if builder.has_method("build"):
		builder.call("build")
		_set_scene_owner(builder, world.owner)

func _add_terrain(world: Node2D) -> void:
	var terrain := Node2D.new()
	terrain.name = "Terrain"
	terrain.set_script(load("res://scripts/world/Terrain.gd"))
	world.add_child(terrain)
	terrain.owner = world.owner

func _add_hazards(world: Node2D, layout_data: Resource) -> void:
	if not "hazard_map" in layout_data:
		return
	var hazard_map: Dictionary = layout_data.hazard_map
	for key in hazard_map.keys():
		var cell := _cell_from_key(str(key))
		var hazard_type := str(hazard_map[key])
		if hazard_type == GridPreview.TILE_STICKY:
			_add_entity(world, "res://scenes/entities/hazards/Sticky.tscn", "Sticky_%d_%d" % [cell.x, cell.y], layout_data.cell_to_world(cell))
			continue
		# 물 — 같은 열에서 바로 위 칸도 물이면 심부(deep=soda inner), 아니면 수면(surface).
		# WaterHazard.gd 컨벤션("표면 1행 + 그 아래 심부 N행")과 일치. deep은 _ready가 읽으므로
		# add_child(=_ready 실행) 전에 설정해야 한다.
		var deep := _is_water_cell(hazard_map, Vector2i(cell.x, cell.y - 1))
		var water := _instance_scene("res://scenes/entities/hazards/Water.tscn", "Water_%d_%d" % [cell.x, cell.y]) as Node2D
		water.set("deep", deep)
		water.position = layout_data.cell_to_world(cell)
		world.add_child(water)
		water.owner = world.owner

func _is_water_cell(hazard_map: Dictionary, cell: Vector2i) -> bool:
	return str(hazard_map.get(_cell_key(cell), "")) == GridPreview.TILE_WATER

func _add_camera(world: Node2D, layout_data: Resource) -> void:
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = layout_data.cell_to_world(layout_data.camera_cell)
	world.add_child(camera)
	camera.owner = world.owner

func _add_spawner(root: Node, layout_data: Resource) -> void:
	var spawner := Node.new()
	spawner.name = "Spawner"
	spawner.set_script(load("res://scripts/core/AntSpawner.gd"))
	spawner.spawn_position = _cell_to_surface(layout_data, layout_data.home_cell) + Vector2(0, -7.5)
	spawner.total = int(_total_ants_spin.value)
	spawner.release_rate = int(_release_rate_spin.value)
	spawner.spawn_direction = layout_data.spawn_direction
	spawner.spawn_direction_alternate = layout_data.spawn_direction_alternate
	root.add_child(spawner)
	spawner.owner = root

func _add_hud(root: Node) -> void:
	var hud := _instance_scene("res://scenes/ui/HUD.tscn", "HUD")
	root.add_child(hud)
	hud.owner = root

func _add_skill_toolbar(root: Node, stage_data: Resource) -> void:
	var toolbar := _instance_scene("res://scenes/ui/SkillToolbar.tscn", "SkillToolbar")
	toolbar.stage_data = stage_data
	root.add_child(toolbar)
	toolbar.owner = root
	# StageRunner._disable_toolbar(스테이지 클리어 시)가 toolbar를 찾도록 경로 연결.
	root.toolbar_path = NodePath("SkillToolbar")

func _set_scene_owner(node: Node, scene_owner: Node) -> void:
	if node == null or scene_owner == null:
		return
	node.owner = scene_owner
	for child in node.get_children():
		_set_scene_owner(child, scene_owner)

func _set_status(text: String, is_error: bool) -> void:
	_status_label.text = text
	if is_error:
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	else:
		_status_label.add_theme_color_override("font_color", Color(0.25, 0.8, 0.35))

func _create_grid_window() -> void:
	_grid_window = Window.new()
	_grid_window.title = "CandyAnts Grid Editor"
	_grid_window.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	_grid_window.size = Vector2i(1500, 920)
	_grid_window.min_size = Vector2i(900, 620)
	_grid_window.visible = false
	_grid_window.close_requested.connect(_grid_window.hide)
	add_child(_grid_window)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_window.add_child(root)

	var toolbar := HBoxContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(toolbar)

	var hint := Label.new()
	hint.text = "좌클릭=선택 브러시 칠 / 우클릭=지움. 시안 사각형 = 플레이어가 보는 화면(카메라 프레임). 초록 세로선 = 레벨 원점(col 0). H=Home, C=Candy, K=Camera."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(hint)

	var brush_label := Label.new()
	brush_label.text = "Brush"
	toolbar.add_child(brush_label)

	var window_brush := OptionButton.new()
	_populate_brush_option(window_brush)
	window_brush.item_selected.connect(func(index: int) -> void:
		_brush_option.select(index)
		_on_brush_selected(index)
	)
	toolbar.add_child(window_brush)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_grid_window.hide)
	toolbar.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 820)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	root.add_child(scroll)

	_grid_window_preview = GridPreview.new(24)
	_grid_window_preview.size = _grid_window_preview.custom_minimum_size
	_grid_window_preview.tile_map_changed.connect(_on_grid_tile_map_changed)
	_grid_window_preview.hazard_map_changed.connect(_on_grid_hazard_map_changed)
	scroll.add_child(_grid_window_preview)

func _open_grid_editor() -> void:
	_sync_grid_from_controls()
	_grid_window.popup_centered(_grid_window.size)
	if _grid_window_preview != null:
		_grid_window_preview.size = _grid_window_preview.custom_minimum_size
		_grid_window_preview.queue_redraw()
	_grid_window.grab_focus()

func _on_template_selected(index: int) -> void:
	_platform_text.text = _template_text(_template_option.get_item_id(index))
	_sync_grid_from_controls()

func _template_text(template_id: int) -> String:
	if template_id == 1:
		return "9,27,19\n33,27,19\n29,33,4"
	if template_id == 2:
		return "19,27,38\n14,24,8\n48,24,8"
	return "0,27,60"

func _parse_platform_cells(text: String) -> Array[Vector2i]:
	return _tile_map_to_platform_cells(_parse_tile_map(text))

func _parse_tile_map(text: String) -> Dictionary:
	var tile_map := {}
	var seen := {}
	for raw_line: String in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		line = line.replace(",", " ")
		var parts := line.split(" ", false)
		if parts.size() < 2:
			continue
		var x := int(parts[0])
		var y := int(parts[1])
		var length := 1
		if parts.size() >= 3:
			length = maxi(1, int(parts[2]))
		var tile_type := GridPreview.TILE_SOLID
		if parts.size() >= 4:
			tile_type = _normalize_tile_type(parts[3])
		for offset in range(length):
			var cell := Vector2i(x + offset, y)
			var key := _cell_key(cell)
			if seen.has(key):
				continue
			seen[key] = true
			tile_map[key] = tile_type
	return tile_map

func _tile_map_to_platform_cells(tile_map: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen := {}
	for key in tile_map.keys():
		var cell := _cell_from_key(str(key))
		if seen.has(cell):
			continue
		seen[cell] = true
		cells.append(cell)
	return cells

func _mark_dirty() -> void:
	if _suppress_dirty:
		return
	if not _dirty:
		_set_dirty(true)

# 스킬 SpinBox 값 변경 핸들러. value_changed(value) 뒤에 skill_id 가 bind 로 붙는다.
# 사용자가 직접 건드린 스킬만 기록(Load 중 _suppress_dirty 일 때는 프로그램적 변경이라 제외).
func _on_skill_spin_changed(_value: float, skill_id: String) -> void:
	if not _suppress_dirty:
		_skill_user_edited[skill_id] = true
	_mark_dirty()

func _set_dirty(value: bool) -> void:
	_dirty = value
	if _title_label != null:
		_title_label.text = BASE_TITLE + ("  *  (미저장 변경)" if value else "")
	dirty_changed.emit(value)

func _connect_dirty_tracking() -> void:
	for spin: SpinBox in [
		_total_ants_spin, _candy_hp_spin, _time_limit_spin, _release_rate_spin,
		_cell_size_spin, _home_cell_x_spin, _home_cell_y_spin,
		_candy_cell_x_spin, _candy_cell_y_spin, _camera_cell_x_spin, _camera_cell_y_spin,
		_settlement_x_spin, _settlement_y_spin,
	]:
		spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	for skill_id: String in SKILL_IDS:
		_skill_spins[skill_id].value_changed.connect(_on_skill_spin_changed.bind(skill_id))
	for star_spin: SpinBox in _star_spins:
		star_spin.value_changed.connect(func(_v: float) -> void: _mark_dirty())
	_name_edit.text_changed.connect(func(_t: String) -> void: _mark_dirty())
	_platform_text.text_changed.connect(func() -> void: _mark_dirty())
	_spawn_dir_option.item_selected.connect(func(_i: int) -> void: _mark_dirty())
	_theme_option.item_selected.connect(func(_i: int) -> void: _mark_dirty())
	_template_option.item_selected.connect(func(_i: int) -> void: _mark_dirty())
	_spawn_alt_check.toggled.connect(func(_p: bool) -> void: _mark_dirty())
	_settlement_check.toggled.connect(func(_p: bool) -> void: _mark_dirty())
	_star_override_check.toggled.connect(func(_p: bool) -> void: _mark_dirty())

func _connect_layout_spins() -> void:
	for spin: SpinBox in [
		_cell_size_spin,
		_home_cell_x_spin,
		_home_cell_y_spin,
		_candy_cell_x_spin,
		_candy_cell_y_spin,
		_camera_cell_x_spin,
		_camera_cell_y_spin,
	]:
		spin.value_changed.connect(_on_marker_spin_changed)

func _on_marker_spin_changed(_value: float) -> void:
	_sync_grid_from_controls()

func _sync_grid_from_controls() -> void:
	if _grid_preview == null or _syncing_grid:
		return
	var home_cell := Vector2i(int(_home_cell_x_spin.value), int(_home_cell_y_spin.value))
	var candy_cell := Vector2i(int(_candy_cell_x_spin.value), int(_candy_cell_y_spin.value))
	var camera_cell := Vector2i(int(_camera_cell_x_spin.value), int(_camera_cell_y_spin.value))
	var settlement_cell := _current_settlement_cell()
	var world_cell_size := int(_cell_size_spin.value)
	var tile_map := _parse_tile_map(_platform_text.text)
	_grid_preview.set_tile_map(tile_map)
	_grid_preview.set_hazard_map(_hazard_map)
	_grid_preview.set_markers(home_cell, candy_cell, camera_cell, settlement_cell)
	_grid_preview.set_world_cell_size(world_cell_size)
	_grid_preview.set_brush_tile_type(_selected_brush_tile_type())
	if _grid_window_preview != null:
		_grid_window_preview.set_tile_map(tile_map)
		_grid_window_preview.set_hazard_map(_hazard_map)
		_grid_window_preview.set_markers(home_cell, candy_cell, camera_cell, settlement_cell)
		_grid_window_preview.set_world_cell_size(world_cell_size)
		_grid_window_preview.set_brush_tile_type(_selected_brush_tile_type())

func _on_grid_tile_map_changed(tile_map: Dictionary) -> void:
	_syncing_grid = true
	_platform_text.text = _format_tile_map(tile_map)
	_syncing_grid = false
	_sync_grid_from_controls()
	_mark_dirty()

func _on_grid_hazard_map_changed(hazard_map: Dictionary) -> void:
	_hazard_map = hazard_map.duplicate()
	_sync_grid_from_controls()
	_mark_dirty()

# "수위선 아래 빈 공간 물 채우기" — 수위선(y) 이하 ~ 레벨 바닥까지, 지면 경계 상자(좌우·하단)
# 안에서 지면/기존 해저드가 없는 빈 칸을 hazard_map에 water로 채운다. 사이드뷰라 하늘(수위선 위)은
# 채우지 않고, Home/Candy/분배자 마커 셀은 엔티티 앵커이므로 건너뛴다. 멱등(idempotent) —
# 이미 물/해저드인 칸은 재칠하지 않으므로 지면 수정 후 재실행해도 안전하다.
func _fill_water_below_line() -> void:
	var tile_map := _parse_tile_map(_platform_text.text)
	if tile_map.is_empty():
		_set_status("지면 타일이 없어 수위 범위를 정할 수 없습니다. 먼저 지면을 그리세요.", true)
		return
	var water_line := int(_water_line_spin.value)
	# 콘텐츠(지면 + 기존 해저드) 경계 상자로 수평/하단 범위를 정해 무한 확장을 막는다.
	var min_x := 1 << 30
	var max_x := -(1 << 30)
	var max_y := -(1 << 30)
	for key in tile_map.keys():
		var cell := _cell_from_key(str(key))
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	for key in _hazard_map.keys():
		var cell := _cell_from_key(str(key))
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	if water_line > max_y:
		_set_status("수위선(y=%d)이 레벨 바닥(y=%d)보다 아래라 채울 칸이 없습니다." % [water_line, max_y], true)
		return
	# 엔티티 앵커 셀(Home/Candy/분배자)은 물을 칠하지 않는다.
	var skip_cells := {}
	skip_cells[_cell_key(Vector2i(int(_home_cell_x_spin.value), int(_home_cell_y_spin.value)))] = true
	skip_cells[_cell_key(Vector2i(int(_candy_cell_x_spin.value), int(_candy_cell_y_spin.value)))] = true
	var settle := _current_settlement_cell()
	if settle.x >= 0:
		skip_cells[_cell_key(settle)] = true
	var added := 0
	for y in range(water_line, max_y + 1):
		for x in range(min_x, max_x + 1):
			var key := _cell_key(Vector2i(x, y))
			if tile_map.has(key) or _hazard_map.has(key) or skip_cells.has(key):
				continue
			_hazard_map[key] = GridPreview.TILE_WATER
			added += 1
	if added > 0:
		_sync_grid_from_controls()
		_mark_dirty()
		_set_status("수위선 y=%d 아래 빈 칸 %d개를 물로 채웠습니다." % [water_line, added], false)
	else:
		_set_status("채울 빈 칸이 없습니다 (범위 내 빈 칸이 이미 채워졌거나 없음).", false)

func _on_settlement_toggled(pressed: bool) -> void:
	_settlement_x_spin.editable = pressed
	_settlement_y_spin.editable = pressed
	_sync_grid_from_controls()

func _on_star_override_toggled(pressed: bool) -> void:
	for star_spin: SpinBox in _star_spins:
		star_spin.editable = pressed

func _current_settlement_cell() -> Vector2i:
	if _settlement_check != null and _settlement_check.button_pressed:
		return Vector2i(int(_settlement_x_spin.value), int(_settlement_y_spin.value))
	return Vector2i(-1, -1)

func _format_platform_cells(cells: Array) -> String:
	var tile_map := {}
	for raw_cell in cells:
		var cell := raw_cell as Vector2i
		tile_map[_cell_key(cell)] = GridPreview.TILE_SOLID
	return _format_tile_map(tile_map)

func _format_tile_map(tile_map: Dictionary) -> String:
	var typed_cells: Array[Vector2i] = []
	var seen := {}
	for key in tile_map.keys():
		var cell := _cell_from_key(str(key))
		if seen.has(cell):
			continue
		seen[cell] = true
		typed_cells.append(cell)
	typed_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)

	var lines: Array[String] = []
	var index := 0
	while index < typed_cells.size():
		var start := typed_cells[index]
		var tile_type := str(tile_map[_cell_key(start)])
		var length := 1
		index += 1
		while (index < typed_cells.size()
			and typed_cells[index].y == start.y
			and typed_cells[index].x == start.x + length
			and str(tile_map[_cell_key(typed_cells[index])]) == tile_type):
			length += 1
			index += 1
		if tile_type == GridPreview.TILE_SOLID:
			lines.append("%d,%d,%d" % [start.x, start.y, length])
		else:
			lines.append("%d,%d,%d,%s" % [start.x, start.y, length, tile_type])
	return "\n".join(lines)

func _on_brush_selected(_index: int) -> void:
	var tile_type := _selected_brush_tile_type()
	if _grid_preview != null:
		_grid_preview.set_brush_tile_type(tile_type)
	if _grid_window_preview != null:
		_grid_window_preview.set_brush_tile_type(tile_type)

func _selected_brush_tile_type() -> String:
	match _brush_option.get_selected_id():
		1:
			return GridPreview.TILE_SLOPE_RIGHT
		2:
			return GridPreview.TILE_SLOPE_LEFT
		3:
			return GridPreview.TILE_ERASE
		4:
			return GridPreview.TILE_WATER
		5:
			return GridPreview.TILE_STICKY
		6:
			return GridPreview.TILE_BACKGROUND
		7:
			return GridPreview.TILE_PLANT
		8:
			return GridPreview.TILE_COOKIE
		9:
			return GridPreview.TILE_SAND_MOUND
		_:
			return GridPreview.TILE_SOLID

func _normalize_tile_type(raw: String) -> String:
	var value := raw.strip_edges().to_lower()
	if value == "slope_right" or value == "slop_right" or value == "right":
		return GridPreview.TILE_SLOPE_RIGHT
	if value == "slope_left" or value == "slop_left" or value == "left":
		return GridPreview.TILE_SLOPE_LEFT
	if value == "background" or value == "bg":
		return GridPreview.TILE_BACKGROUND
	if value == "plant":
		return GridPreview.TILE_PLANT
	if value == "cookie":
		return GridPreview.TILE_COOKIE
	if value == "sand_mound" or value == "ladder" or value == "sandmound":
		return GridPreview.TILE_SAND_MOUND
	return GridPreview.TILE_SOLID

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",", false)
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
