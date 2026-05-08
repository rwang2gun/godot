class_name Skill extends RefCounted

# 서브클래스가 반드시 `const ID: String = "..."` 정의.
# (GDScript 4는 const 상속 shadowing 금지 → 베이스에서는 선언하지 않음.)

func can_apply(_ant: Ant) -> bool:
	return true

func apply(_ant: Ant) -> void:
	pass
