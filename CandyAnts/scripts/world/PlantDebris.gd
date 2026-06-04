class_name PlantDebris extends Node2D

# Cutter가 덩쿨(plant) cell을 flood-fill로 잘라낼 때, 잘린 각 cell 자리에 스폰되는 **순수 시각** 디브리.
# 충돌·점유·score 0 영향 (Node2D + Sprite2D 조각들만, collision body 없음). 잘린 plant 텍스처를 여러 조각으로
# 흩뜨려 중력으로 지면을 향해 떨어뜨리고 회전·축소·페이드아웃시킨 뒤 자가 free한다.
# Terrain.shatter_connected_plants가 destroy_tile_at 직전(원본 Sprite가 살아있을 때) 텍스처를 캡처해 setup 호출.

const GRAVITY: float = 1100.0          # px/s² — 개미 낙하보다 약간 빠르게 떨어져 "툭 떨어지는" 무게감.
const LIFETIME: float = 0.8            # 전체 수명(초). 이후 queue_free.
const FRAGMENT_COUNT: int = 4          # cell 하나당 흩어지는 조각 수.
const FRAGMENT_SCALE: float = 0.5      # cell_size 대비 각 조각의 기본 크기 비율.

var _elapsed: float = 0.0
# 각 조각: {"spr": Sprite2D, "vel": Vector2, "ang_vel": float}
var _pieces: Array[Dictionary] = []

# texture: 잘린 plant cell의 원본 Sprite 텍스처. world_pos: cell 중심 global 좌표. cell_size: 셀 한 변(px).
func setup(texture: Texture2D, world_pos: Vector2, cell_size: int) -> void:
	global_position = world_pos
	if texture == null:
		return   # 텍스처 없으면 디브리 생략 — 시각만이라 무해(보일 게 없음).
	var tex_w: float = texture.get_size().x
	var base_scale: float = 1.0
	if tex_w > 0.0:
		base_scale = float(cell_size) / tex_w * FRAGMENT_SCALE
	for i in FRAGMENT_COUNT:
		var spr := Sprite2D.new()
		spr.texture = texture
		spr.scale = Vector2(base_scale, base_scale)
		# cell 안 사방으로 흩뿌린 시작 오프셋.
		spr.position = Vector2(
			randf_range(-0.3, 0.3) * cell_size,
			randf_range(-0.3, 0.3) * cell_size
		)
		spr.rotation = randf_range(-PI, PI)
		add_child(spr)
		# 약간 좌우로 튀며 위로 살짝 솟았다가(음수 y) 중력으로 낙하.
		var vel := Vector2(
			randf_range(-70.0, 70.0),
			randf_range(-140.0, -10.0)
		)
		_pieces.append({"spr": spr, "vel": vel, "ang_vel": randf_range(-8.0, 8.0)})

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return
	var t: float = _elapsed / LIFETIME
	var alpha: float = 1.0 - t * t   # 후반부 가속 페이드.
	for p in _pieces:
		var spr: Sprite2D = p["spr"]
		var vel: Vector2 = p["vel"]
		vel.y += GRAVITY * delta
		p["vel"] = vel
		spr.position += vel * delta
		spr.rotation += float(p["ang_vel"]) * delta
		spr.scale *= (1.0 - 0.4 * delta)   # 떨어지면서 서서히 부서져 작아짐.
		spr.modulate.a = alpha
