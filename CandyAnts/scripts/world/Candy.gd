class_name Candy extends Area2D

@export var hp: int = 10

@onready var _sprite: Polygon2D = $Sprite if has_node("Sprite") else null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if hp <= 0:
		return
	if not (body is Ant):
		return
	var a: Ant = body as Ant
	if a.has_been_carrying:
		return
	if not (a.state_machine.current_state is WalkerState):
		return

	hp -= 1
	print("[Candy] picked by ", a.name, " hp=", hp)
	EventBus.candy_piece_picked.emit(hp)
	a.flip()
	a.state_machine.change_state(CarryingState.new())
	if hp <= 0:
		monitoring = false
		if _sprite != null:
			_sprite.color = Color(0.5, 0.5, 0.5, 0.6)
		EventBus.candy_depleted.emit()
