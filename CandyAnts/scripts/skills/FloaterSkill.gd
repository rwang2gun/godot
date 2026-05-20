class_name FloaterSkill extends Skill

const ID: String = "floater"

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	# Lemmings 정통 — Faller 도중 부여 가능. is_alive() 통과면 OK.
	if not ant.is_alive():
		return false
	if ant.has_trait(&"floater"):
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null:
		return
	ant.set_trait(&"floater")
