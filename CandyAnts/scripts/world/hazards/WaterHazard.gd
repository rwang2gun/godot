class_name WaterHazard extends HazardBase

# Phase 17 — Water hazard. body_entered → 즉시 LostState 전이로 사탕 손실 + ant 제거.
# LostState.enter()가 candy_piece_lost emit + queue_free 수행.
#
# 2026-06-02 (소다 워터 시각 개편) — surface/inner 2종 텍스처 분기.
# `deep == false` → 표면행(soda_water_surface_square), `deep == true` → 심부행(soda_water_inner_square).
# 동작(즉사·셀 등록)은 두 변형 모두 동일 — 시각만 분기한다. 물 몸체는 표면 1행(surface)
# + 그 아래 심부 N행(inner)으로 스테이지 씬에서 셀별 인스턴스로 배치한다.
@export var deep: bool = false

func _ready() -> void:
	_apply_variant_texture()
	super()   # HazardBase._ready — cell 등록 (physics_frame await)

# Terrain._bridge_tile_texture와 동일한 lazy load 패턴 — class_name 스크립트가
# 컴파일 타임 preload로 전체 클래스 레지스트리를 깨지 않도록 런타임 load 사용.
func _apply_variant_texture() -> void:
	var visual: Sprite2D = get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	var path: String = (
		"res://assets/sprites/terrain/usable_square/soda_water_inner_square.png" if deep
		else "res://assets/sprites/terrain/usable_square/soda_water_surface_square.png"
	)
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		visual.texture = tex

func _handle_ant_entry(ant: Ant) -> void:
	# Phase 20 — sfx_request emit 직전 (id only). receiver는 phase 21에서 connect.
	EventBus.sfx_request.emit(&"water_splash")
	ant.state_machine.change_state(LostState.new())
