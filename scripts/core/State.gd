class_name BaseState
extends RefCounted

## 캐릭터(CharacterBase) 참조 — _init 에서 주입
var parent

func _init(p) -> void:
	parent = p

## 상태 진입 시 호출
func enter() -> void:
	pass

## 매 프레임 호출 (_physics_process 에서)
func update(_delta: float) -> void:
	pass

## 상태 퇴장 시 호출
func exit() -> void:
	pass
