class_name WaterHazard extends HazardBase

# Phase 17 — Water hazard. body_entered → 개미 물 진입 처리.
# 2026-06-04 (물 동작 개편) — 즉사(LostState·queue_free) 대신 수면 표류(AdriftState)로 전이한다.
# 보유 사탕 손실 정산(candy_piece_lost emit)은 AdriftState.enter가 수행하며 개미는 제거되지 않고
# 수면에 떠서 표류한다. 상세는 AdriftState.gd 참조.
#
# 2026-06-02 (소다 워터 시각 개편) — surface/inner 2종 텍스처 분기.
# `deep == false` → 표면행(soda_water_surface_square), `deep == true` → 심부행(soda_water_inner_square).
# 동작(표류·셀 등록)은 두 변형 모두 동일 — 시각만 분기한다. 물 몸체는 표면 1행(surface)
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
	# 2026-06-04 — 물 진입은 즉사(LostState)가 아니라 수면 표류(AdriftState)로 처리한다.
	# 보유 사탕 손실 정산은 AdriftState.enter가 LostState와 동일하게 수행한다(개미는 제거되지 않음).
	# 표류 기준 수면 높이 = 본 물 셀 상단 모서리(셀 중심 y − cell_size/2). surface 행이 deep 행보다
	# 물리적으로 위에 있어 낙하 개미는 surface 셀의 body_entered가 먼저 발화 → 표면 높이로 부유한다.
	var cs: float = float(_terrain.cell_size) if _terrain != null else 48.0
	var surface_y: float = global_position.y - cs * 0.5
	ant.state_machine.change_state(AdriftState.new(surface_y))
