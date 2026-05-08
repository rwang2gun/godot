class_name BuilderSkill extends Skill

const ID: String = "builder"

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	var s: AntState = ant.state_machine.current_state
	# Walker 또는 Carrying만 허용. Faller/Worker/Saved/Dead 거부.
	if not (s is WalkerState or s is CarryingState):
		return false
	if not ant.is_on_floor():
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	ant.state_machine.change_state(WorkerState.new("builder"))
