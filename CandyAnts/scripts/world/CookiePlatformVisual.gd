class_name CookiePlatformVisual extends Node2D

@export var platform_size: Vector2 = Vector2(1920, 200)

var _surface: Texture2D = null
var _surface_flip: Texture2D = null
var _background: Texture2D = null
var _background_flip: Texture2D = null

func _draw() -> void:
	if _surface == null:
		_surface = load("res://assets/sprites/terrain/cookie_tile_surface.png") as Texture2D
	if _surface_flip == null:
		_surface_flip = load("res://assets/sprites/terrain/cookie_tile_surface_flip.png") as Texture2D
	if _background == null:
		_background = load("res://assets/sprites/terrain/cookie_tile_background.png") as Texture2D
	if _background_flip == null:
		_background_flip = load("res://assets/sprites/terrain/cookie_tile_background_flip.png") as Texture2D
	if _surface == null or _surface_flip == null or _background == null or _background_flip == null:
		return

	var half: Vector2 = platform_size * 0.5
	var collision_top_y: float = -half.y
	var width: float = platform_size.x
	var left: float = -half.x
	var surface_size: Vector2 = _surface.get_size()
	var background_size: Vector2 = _background.get_size()
	var segment_width: float = surface_size.x
	var cursor_x: float = left
	var segment_index: int = 0

	while cursor_x < half.x:
		var surface_texture: Texture2D = _surface if segment_index % 2 == 0 else _surface_flip
		var background_texture: Texture2D = _background if segment_index % 2 == 0 else _background_flip
		var remaining: float = half.x - cursor_x
		var draw_w: float = minf(segment_width, remaining)
		var source_w: float = segment_width * (draw_w / segment_width)
		var surface_dst: Rect2 = Rect2(
			Vector2(cursor_x, collision_top_y - surface_size.y),
			Vector2(draw_w, surface_size.y)
		)
		var surface_src: Rect2 = Rect2(Vector2.ZERO, Vector2(source_w, surface_size.y))
		var background_dst: Rect2 = Rect2(
			Vector2(cursor_x, collision_top_y),
			Vector2(draw_w, background_size.y)
		)
		var background_src: Rect2 = Rect2(Vector2.ZERO, Vector2(source_w, background_size.y))
		draw_texture_rect_region(background_texture, background_dst, background_src)
		draw_texture_rect_region(surface_texture, surface_dst, surface_src)
		cursor_x += draw_w
		segment_index += 1
