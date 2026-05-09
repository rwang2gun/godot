class_name CoordSpace
extends RefCounted

# 매번 viewport.get_canvas_transform()을 다시 읽는다. 캐싱 금지(카메라 매 프레임 이동 가능).

static func screen_to_world(screen_pos: Vector2, viewport: Viewport) -> Vector2:
	if viewport == null:
		return screen_pos
	return viewport.get_canvas_transform().affine_inverse() * screen_pos

static func world_to_screen(world_pos: Vector2, viewport: Viewport) -> Vector2:
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos
