class_name BlockerSkill extends Skill

const ID: String = "blocker"

# can_apply 단일 진실 출처 (phase04-review HIGH 대응).
# Carrying / has_candy=true 둘 다 거부 — Blocker는 외부 해제 없이 영구 정지하므로
# 운반자 Blocker화 시 in_transit 영구 잔존 → 클리어 데드락.
func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not (ant.state_machine.current_state is WalkerState):
		return false
	if not ant.is_on_floor():
		return false
	if ant.has_candy:
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	ant.state_machine.change_state(WorkerState.new("blocker"))
