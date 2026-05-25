class_name Home extends Area2D

@export var spawn_position_offset: Vector2 = Vector2(0, -5)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func get_spawn_position() -> Vector2:
	return global_position + spawn_position_offset

func _on_body_entered(body: Node2D) -> void:
	if not (body is Ant):
		return
	var a: Ant = body as Ant
	# 가드 1: 스폰 grace
	if Time.get_ticks_msec() / 1000.0 < a._grace_until:
		return
	# 가드 2: 한 번도 운반 안 한 fresh ant는 무시
	var carrying: bool = a.has_candy
	if not carrying and not a.has_been_carrying:
		return

	# 운반 종료 처리 — 사탕은 ant 손을 떠나 Home에 안착, has_candy 해제 후 시그널.
	a.has_candy = false
	print("[Home] saved ", a.name, " carrying=", carrying)
	# Phase 20 — sfx_request emit (with_candy=true만; 빈손 회수는 분배자 정착 후 등 코어 게임플레이 핵심 아님).
	if carrying:
		EventBus.sfx_request.emit(&"ant_save")
	EventBus.ant_saved.emit(a, carrying)
	a.state_machine.change_state(SavedState.new())
