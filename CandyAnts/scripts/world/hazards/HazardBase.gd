class_name HazardBase extends Area2D

# Phase 17 — hazard 베이스. Area2D 자체 monitoring + Terrain 자체 register.
# 서브클래스(WaterHazard·StickyHazard)는 _handle_ant_entry(ant)만 override.
# §0.2 어휘 정책 — terminal state 식별자 직접 참조 회피:
# Ant.is_alive() 단일 진입점으로 terminal state 4종 일괄 차단.

var _hazard_cell: Vector2i = Vector2i.ZERO
var _active: bool = true
var _terrain: Terrain = null

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	# cell_size race 회피 — StageLayoutBuilder.build 이후 frame에 cell 계산 + register.
	# phase 15 SettlementMarker._on_body_entered 패턴 답습 (deferred re-check).
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	_terrain = _find_ancestor_terrain()
	if _terrain == null:
		push_warning("[%s] could not find ancestor Terrain — hazard cell registration skipped" % name)
		return
	var cs: int = _terrain.cell_size
	_hazard_cell = Vector2i(
		int(floor(global_position.x / cs)),
		int(floor(global_position.y / cs))
	)
	_terrain.register_hazard_at_cell(_hazard_cell, self)

func _find_ancestor_terrain() -> Terrain:
	var n: Node = get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null

func set_active(active: bool) -> void:
	_active = active
	monitoring = active
	var shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.disabled = not active
	# 시각 alpha 토글 — 모든 자식 CanvasItem(ColorRect/Sprite2D)에 modulate.a 적용.
	for c in get_children():
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = (1.0 if active else 0.3)

func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	var ant: Ant = body as Ant
	if ant == null or not is_instance_valid(ant):
		return
	# D13 — Ant.is_alive() 단일 진입점으로 4 terminal state 일괄 차단.
	# 신규 코드에서 terminal state 식별자 직접 참조 0건 (§0.2 어휘 정합).
	if not ant.is_alive():
		return
	_handle_ant_entry(ant)

func _handle_ant_entry(_ant: Ant) -> void:
	# 추상 — 서브클래스가 override.
	pass
