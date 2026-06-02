class_name BridgeSkill extends Skill

const ID: String = "bridge"

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	var s: AntState = ant.state_machine.current_state
	# A1 (운반자 통일, 2026-06-02) — builder처럼 Walker/Carrying 모두 허용. 작업 종료 시 return_to_walking()이
	# has_candy면 CarryingState로 복원하므로 운반 개미가 다리를 놓고 다시 운반을 이어가도 데드락 없음.
	# (파괴·정지·하강계는 현행 거부 유지 — bridge/builder만 통일.)
	if not (s is WalkerState or s is CarryingState):
		return false
	if not ant.is_on_floor():
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	ant.state_machine.change_state(WorkerState.new("bridge"))
