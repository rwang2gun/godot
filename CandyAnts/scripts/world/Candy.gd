class_name Candy extends Area2D

@export var hp: int = 10

@onready var _sprite: AnimatedSprite2D = $Sprite if has_node("Sprite") else null
var _original_hp: int = 0
var _base_scale: Vector2 = Vector2.ONE
var _base_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	_original_hp = hp
	if _sprite != null:
		_base_scale = _sprite.scale
		# bottom-center anchor: sprite는 node origin 위쪽으로 height/2 만큼 올라가 있음.
		# hp 비율로 축소 시 offset도 동일 비율 — 작아져도 하단이 항상 node origin에 고정.
		_base_offset = _sprite.position
		# 정적 sprite — 항상 frame 0, autoplay 없음. 남은 hp 비율로 scale + offset 축소.
		_sprite.stop()
		_sprite.frame = 0
	body_entered.connect(_on_body_entered)

func _update_scale() -> void:
	if _sprite == null or _original_hp <= 0:
		return
	var ratio: float = clamp(float(hp) / float(_original_hp), 0.0, 1.0)
	_sprite.scale = _base_scale * ratio
	_sprite.position = _base_offset * ratio

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
	# Phase 20 — sfx_request emit 직전 (id only). receiver는 phase 21에서 connect.
	EventBus.sfx_request.emit(&"candy_pick")
	EventBus.candy_piece_picked.emit(hp)
	a.flip()
	a.state_machine.change_state(CarryingState.new())
	_update_scale()
	if hp <= 0:
		# Area2D body_entered 콜백 안에서 monitoring 직접 set 금지 (Godot 4 in/out signal
		# block). set_deferred로 다음 idle frame에 적용. 동작 멱등 — 이미 hp<=0면 함수 상단
		# `if hp <= 0: return` 가드로 추가 발화 차단.
		set_deferred("monitoring", false)
		if _sprite != null:
			_sprite.visible = false
		# Phase 20 — sfx_request emit 직전 (id only). receiver는 phase 21에서 connect.
		EventBus.sfx_request.emit(&"candy_depleted")
		EventBus.candy_depleted.emit()
