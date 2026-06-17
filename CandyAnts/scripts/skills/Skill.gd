class_name Skill extends RefCounted

# 서브클래스가 반드시 `const ID: String = "..."` 정의.
# (GDScript 4는 const 상속 shadowing 금지 → 베이스에서는 선언하지 않음.)

const _DROPPED_CANDY_SCENE := preload("res://scenes/world/DroppedCandy.tscn")

func can_apply(_ant: Ant) -> bool:
	return true

func apply(_ant: Ant) -> void:
	pass

# 운반 중 개미가 그 자리에 정착/정지하는 스킬(floater 분배자·blocker) 공용 — 들고 있던 사탕을
# 바닥에 드롭한다. 즉시 lost 회계(candy_piece_lost) + 재획득 가능한 DroppedCandy 생성. 비운반
# 보행 개미가 주우면 candy_piece_recovered로 lost→in_transit 보정(DroppedCandy). 비운반이면 no-op.
# 단일 SoT — floater/blocker가 같은 회계로 드롭하도록 한 곳에 둔다(drift 방지).
func _drop_carried_candy(ant: Ant) -> void:
	if ant == null or not ant.has_candy:
		return
	ant.has_candy = false
	EventBus.sfx_request.emit(&"candy_lost")
	EventBus.candy_piece_lost.emit(ant)
	var parent: Node = ant.get_parent()
	if parent == null:
		return
	var dc: Node2D = _DROPPED_CANDY_SCENE.instantiate() as Node2D
	parent.add_child(dc)
	dc.global_position = ant.global_position
