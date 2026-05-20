class_name ClimberSkill extends Skill

const ID: String = "climber"

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	var s: AntState = ant.state_machine.current_state
	# Walker 또는 Carrying만 허용. Faller/Worker(blocker/builder)/Saved/Dead 거부.
	if not (s is WalkerState or s is CarryingState):
		return false
	if ant.has_trait(&"climber"):
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null:
		return
	ant.set_trait(&"climber")
