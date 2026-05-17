@tool
extends VBoxContainer

class GridPreview:
	extends Control

	signal tile_map_changed(tile_map: Dictionary)

	const GRID_COLUMNS := 60
	const GRID_ROWS := 34
	const MAX_PLATFORM_ROW := 27
	const TILE_SOLID := "solid"
	const TILE_SLOPE_RIGHT := "slope_right"
	const TILE_SLOPE_LEFT := "slope_left"
	const TILE_ERASE := "erase"

	var tile_map: Dictionary = {}
	var home_cell := Vector2i(12, 27)
	var candy_cell := Vector2i(44, 27)
	var camera_cell := Vector2i(30, 17)
	var preview_cell_size := 16
	var brush_tile_type := TILE_SOLID
	var _paint_button := 0

	func _init(next_preview_cell_size: int = 16) -> void:
		preview_cell_size = next_preview_cell_size
		custom_minimum_size = Vector2(GRID_COLUMNS * preview_cell_size, GRID_ROWS * preview_cell_size)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_platform_cells(cells: Array[Vector2i]) -> void:
		tile_map = {}
		for cell: Vector2i in cells:
			tile_map[_cell_key(cell)] = TILE_SOLID
		queue_redraw()

	func set_tile_map(next_tile_map: Dictionary) -> void:
		tile_map = next_tile_map.duplicate()
		queue_redraw()

	func set_brush_tile_type(next_tile_type: String) -> void:
		brush_tile_type = next_tile_type
		queue_redraw()

	func set_markers(next_home_cell: Vector2i, next_candy_cell: Vector2i, next_camera_cell: Vector2i) -> void:
		home_cell = next_home_cell
		candy_cell = next_candy_cell
		camera_cell = next_camera_cell
		queue_redraw()

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
		var bounds := Rect2(Vector2.ZERO, Vector2(GRID_COLUMNS * preview_cell_size, GRID_ROWS * preview_cell_size))
		draw_rect(bounds, Color(0.10, 0.09, 0.08, 1.0), true)
		var blocked_top := float((MAX_PLATFORM_ROW + 1) * preview_cell_size)
		var blocked_rect := Rect2(Vector2(0, blocked_top), Vector2(bounds.size.x, bounds.size.y - blocked_top))
		draw_rect(blocked_rect, Color(0.02, 0.02, 0.02, 0.72), true)

		for key in tile_map.keys():
			var cell := _cell_from_key(str(key))
			if _is_cell_in_bounds(cell) and _is_cell_placeable(cell):
				var rect := _cell_rect(cell).grow(-1.0)
				_draw_tile(rect, str(tile_map[key]))

		for x in range(GRID_COLUMNS + 1):
			var x_pos := float(x * preview_cell_size)
			var color := Color(1, 1, 1, 0.28) if x % 5 == 0 else Color(1, 1, 1, 0.12)
			draw_line(Vector2(x_pos, 0), Vector2(x_pos, bounds.size.y), color, 1.0)
		for y in range(GRID_ROWS + 1):
			var y_pos := float(y * preview_cell_size)
			var color := Color(1, 1, 1, 0.28) if y % 5 == 0 else Color(1, 1, 1, 0.12)
			draw_line(Vector2(0, y_pos), Vector2(bounds.size.x, y_pos), color, 1.0)

		_draw_marker(home_cell, Color(0.18, 0.85, 0.36), "H")
		_draw_marker(candy_cell, Color(1.0, 0.28, 0.62), "C")
		_draw_marker(camera_cell, Color(0.35, 0.65, 1.0), "K")
		var limit_y := float((MAX_PLATFORM_ROW + 1) * preview_cell_size)
		draw_line(Vector2(0, limit_y), Vector2(bounds.size.x, limit_y), Color(1.0, 0.2, 0.15, 0.85), 2.0)
		draw_rect(bounds, Color(1, 1, 1, 0.22), false, 2.0)

	func _apply_paint_at(position: Vector2) -> void:
		var cell := Vector2i(floori(position.x / preview_cell_size), floori(position.y / preview_cell_size))
		if not _is_cell_in_bounds(cell) or not _is_cell_placeable(cell):
			return
		var key := _cell_key(cell)
		var changed := false
		if _paint_button == MOUSE_BUTTON_RIGHT or brush_tile_type == TILE_ERASE:
			if tile_map.has(key):
				tile_map.erase(key)
				changed = true
		elif tile_map.get(key, "") != brush_tile_type:
			tile_map[key] = brush_tile_type
			changed = true
		if changed:
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
			draw_rect(rect, Color(0.92, 0.60, 0.28, 1.0), true)
			draw_rect(rect, Color(0.45, 0.24, 0.12, 1.0), false, 1.0)

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
		return Rect2(Vector2(cell.x * preview_cell_size, cell.y * preview_cell_size), Vector2(preview_cell_size, preview_cell_size))

	func _is_cell_in_bounds(cell: Vector2i) -> bool:
		return cell.x >= 0 and cell.x < GRID_COLUMNS and cell.y >= 0 and cell.y < GRID_ROWS

	func _is_cell_placeable(cell: Vector2i) -> bool:
		return cell.y <= MAX_PLATFORM_ROW

	func _cell_key(cell: Vector2i) -> String:
		return "%d,%d" % [cell.x, cell.y]

	func _cell_from_key(key: String) -> Vector2i:
		var parts := key.split(",", false)
		if parts.size() < 2:
			return Vector2i.ZERO
		return Vector2i(int(parts[0]), int(parts[1]))

var editor_interface: EditorInterface = null

var _id_spin: SpinBox
var _name_edit: LineEdit
var _total_ants_spin: SpinBox
var _candy_hp_spin: SpinBox
var _time_limit_spin: SpinBox
var _release_rate_spin: SpinBox
var _builder_spin: SpinBox
var _blocker_spin: SpinBox
var _cell_size_spin: SpinBox
var _home_cell_x_spin: SpinBox
var _home_cell_y_spin: SpinBox
var _candy_cell_x_spin: SpinBox
var _candy_cell_y_spin: SpinBox
var _camera_cell_x_spin: SpinBox
var _camera_cell_y_spin: SpinBox
var _platform_text: TextEdit
var _brush_option: OptionButton
var _grid_preview: GridPreview
var _grid_window: Window
var _grid_window_preview: GridPreview
var _template_option: OptionButton
var _status_label: Label
var _syncing_grid := false

func _ready() -> void:
	name = "CandyAnts Level"
	custom_minimum_size = Vector2(300, 0)

	var title := Label.new()
	title.text = "CandyAnts Level"
	title.add_theme_font_size_override("font_size", 18)
	add_child(title)

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
	_total_ants_spin = _add_spin("Ants", 10, 1, 200, 1)
	_candy_hp_spin = _add_spin("Candy HP", 10, 1, 999, 1)
	_time_limit_spin = _add_spin("Time Limit", 180, 10, 999, 5)
	_release_rate_spin = _add_spin("Release Rate", 30, 1, 99, 1)

	_add_section("Skills")
	_builder_spin = _add_spin("Builder", 3, 0, 99, 1)
	_blocker_spin = _add_spin("Blocker", 0, 0, 99, 1)

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
	_brush_option.add_item("Solid", 0)
	_brush_option.add_item("Slope Right", 1)
	_brush_option.add_item("Slope Left", 2)
	_brush_option.add_item("Erase", 3)
	_brush_option.item_selected.connect(_on_brush_selected)
	add_child(_labeled_control("Brush", _brush_option))

	_add_section("Grid Preview")
	var grid_hint := Label.new()
	grid_hint.text = "Left drag: draw. Right drag: erase. Rows below Stage01 ground limit are blocked."
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

func _save_stage(overwrite: bool) -> void:
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

	var layout_data := _build_layout_data()
	if layout_data.platform_cells.is_empty():
		_set_status("At least one platform cell is required.", true)
		return

	var layout_result := _save_resource(layout_data, layout_path)
	if layout_result != OK:
		_set_status("Failed to save %s: %s" % [layout_path, error_string(layout_result)], true)
		return

	var stage_data := _build_stage_data(stage_id, stage_name, scene_path, layout_path, data_path)
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

	_set_status("%s Stage%02d." % ["Saved" if overwrite else "Created", stage_id], false)

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

	_name_edit.text = stage_data.display_name if "display_name" in stage_data else ""
	_total_ants_spin.value = stage_data.total_ants if "total_ants" in stage_data else 10
	_candy_hp_spin.value = stage_data.candy_hp if "candy_hp" in stage_data else 10
	_time_limit_spin.value = stage_data.time_limit_seconds if "time_limit_seconds" in stage_data else 180
	_release_rate_spin.value = stage_data.release_rate_initial if "release_rate_initial" in stage_data else 30
	_builder_spin.value = int(stage_data.skill_inventory.get("builder", 0)) if "skill_inventory" in stage_data else 0
	_blocker_spin.value = int(stage_data.skill_inventory.get("blocker", 0)) if "skill_inventory" in stage_data else 0

	var layout_data := _load_or_default_layout(stage_id)
	_apply_layout_data(layout_data)
	_set_status("Loaded Stage%02d. Use Save Stage to overwrite existing files." % stage_id, false)

func _build_stage_data(stage_id: int, stage_name: String, _scene_path: String, layout_path: String, data_path: String) -> Resource:
	var stage_data: Resource = ResourceLoader.load(data_path) if ResourceLoader.exists(data_path) else null
	if stage_data == null:
		var script := load("res://scripts/core/StageData.gd") as Script
		stage_data = script.new()
	stage_data.id = stage_id
	stage_data.display_name = stage_name
	var layout_ref := ResourceLoader.load(layout_path)
	stage_data.layout = layout_ref if layout_ref != null else _build_layout_data()
	stage_data.total_ants = int(_total_ants_spin.value)
	stage_data.candy_hp = int(_candy_hp_spin.value)
	stage_data.time_limit_seconds = float(_time_limit_spin.value)
	stage_data.release_rate_initial = int(_release_rate_spin.value)
	stage_data.release_rate_min = 1
	stage_data.skill_inventory = {}
	stage_data.available_skills = []
	_add_skill(stage_data, "builder", int(_builder_spin.value))
	_add_skill(stage_data, "blocker", int(_blocker_spin.value))
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
	if _template_option.get_selected_id() == 2:
		layout_data.spawn_direction = 1
		layout_data.spawn_direction_alternate = true
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
	_sync_grid_from_controls()

func _add_skill(stage_data: Resource, skill_id: String, count: int) -> void:
	if count <= 0:
		return
	stage_data.available_skills.append(skill_id)
	stage_data.skill_inventory[skill_id] = count

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
	_add_entity(world, "res://scenes/entities/Home.tscn", "Home", stage_data.layout.cell_to_world(stage_data.layout.home_cell))
	var candy := _add_entity(world, "res://scenes/entities/Candy.tscn", "Candy", stage_data.layout.cell_to_world(stage_data.layout.candy_cell))
	candy.hp = int(_candy_hp_spin.value)
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
	spawner.spawn_position = layout_data.cell_to_world(layout_data.home_cell) + Vector2(0, -5)
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
	hint.text = "Left drag paints the selected tile. Right drag erases. Rows below the Stage01 ground limit are blocked. H=Home, C=Candy, K=Camera."
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(hint)

	var brush_label := Label.new()
	brush_label.text = "Brush"
	toolbar.add_child(brush_label)

	var window_brush := OptionButton.new()
	window_brush.add_item("Solid", 0)
	window_brush.add_item("Slope Right", 1)
	window_brush.add_item("Slope Left", 2)
	window_brush.add_item("Erase", 3)
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
			if cell.y > GridPreview.MAX_PLATFORM_ROW:
				continue
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
		if cell.y > GridPreview.MAX_PLATFORM_ROW:
			continue
		if seen.has(cell):
			continue
		seen[cell] = true
		cells.append(cell)
	return cells

func _connect_layout_spins() -> void:
	for spin: SpinBox in [
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
	var tile_map := _parse_tile_map(_platform_text.text)
	_grid_preview.set_tile_map(tile_map)
	_grid_preview.set_markers(home_cell, candy_cell, camera_cell)
	_grid_preview.set_brush_tile_type(_selected_brush_tile_type())
	if _grid_window_preview != null:
		_grid_window_preview.set_tile_map(tile_map)
		_grid_window_preview.set_markers(home_cell, candy_cell, camera_cell)
		_grid_window_preview.set_brush_tile_type(_selected_brush_tile_type())

func _on_grid_tile_map_changed(tile_map: Dictionary) -> void:
	_syncing_grid = true
	_platform_text.text = _format_tile_map(tile_map)
	_syncing_grid = false
	_sync_grid_from_controls()

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
		_:
			return GridPreview.TILE_SOLID

func _normalize_tile_type(raw: String) -> String:
	var value := raw.strip_edges().to_lower()
	if value == "slope_right" or value == "slop_right" or value == "right":
		return GridPreview.TILE_SLOPE_RIGHT
	if value == "slope_left" or value == "slop_left" or value == "left":
		return GridPreview.TILE_SLOPE_LEFT
	return GridPreview.TILE_SOLID

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func _cell_from_key(key: String) -> Vector2i:
	var parts := key.split(",", false)
	if parts.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))
