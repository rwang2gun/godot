@tool
class_name StageLayoutBuilder extends Node2D

@export var layout: Resource = null:
	set(value):
		layout = value
		if Engine.is_editor_hint():
			_rebuild_preview()

@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		if Engine.is_editor_hint():
			_rebuild_preview()

var _tile_texture: Texture2D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_preview()
	else:
		build()

func build() -> void:
	_clear_children()
	if layout == null:
		return
	for cell: Vector2i in layout.platform_cells:
		_add_cell(cell)

func _rebuild_preview() -> void:
	if not is_inside_tree():
		return
	_clear_children()
	if not preview_in_editor or layout == null:
		return
	for cell: Vector2i in layout.platform_cells:
		_add_cell(cell)

func _add_cell(cell: Vector2i) -> void:
	var cell_size := layout.cell_size
	var body := StaticBody2D.new()
	body.name = "Cell_%d_%d" % [cell.x, cell.y]
	body.position = layout.cell_to_world(cell)
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	body.owner = owner

	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(cell_size, cell_size)
	shape.shape = rect
	body.add_child(shape)
	shape.owner = owner

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = _get_tile_texture()
	if sprite.texture != null:
		var texture_size := sprite.texture.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			sprite.scale = Vector2(float(cell_size) / texture_size.x, float(cell_size) / texture_size.y)
	else:
		sprite.modulate = Color(0.45, 0.28, 0.15)
	body.add_child(sprite)
	sprite.owner = owner

func _get_tile_texture() -> Texture2D:
	if _tile_texture == null:
		_tile_texture = load("res://assets/sprites/terrain/thin_cookie_bridge_tile.png") as Texture2D
	return _tile_texture

func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
