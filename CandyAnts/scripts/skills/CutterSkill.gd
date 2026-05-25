class_name CutterSkill extends Skill

const ID: String = "cutter"

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	var s: AntState = ant.state_machine.current_state
	if not (s is WalkerState):
		return false
	if not ant.is_on_floor():
		return false
	if ant.has_candy:
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	ant.state_machine.change_state(WorkerState.new("cutter"))
