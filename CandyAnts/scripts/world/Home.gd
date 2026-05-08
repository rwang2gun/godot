class_name Home extends Area2D

@export var spawn_position_offset: Vector2 = Vector2(48, -32)

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
	var carrying: bool = a.state_machine.current_state is CarryingState
	if not carrying and not a.has_been_carrying:
		return

	print("[Home] saved ", a.name, " carrying=", carrying)
	EventBus.ant_saved.emit(a, carrying)
	a.state_machine.change_state(SavedState.new())
