class_name DiggerSkill extends Skill

const ID: String = "digger"

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	var s: AntState = ant.state_machine.current_state
	# Walker만 — Carrying 거부(작업 중 has_candy 잔존 시 in_transit 영구 잔존 위험).
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
	ant.state_machine.change_state(WorkerState.new("digger"))
