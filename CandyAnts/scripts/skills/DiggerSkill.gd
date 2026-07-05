class_name DiggerSkill extends Skill

const ID: String = "digger"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
const SOLVER_META := {
	"target": "cell",
	"category": "SIGN",
	"routing": "down",
	"purpose": "발밑을 수직으로 파 개미를 아래층으로 내려보낸다",
	"hints": {"effect": "dig_down"},
}

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	var s: AntState = ant.state_machine.current_state
	# 운반자 통일 (2026-06-20) — bridge/slide/sand_mound와 동일하게 Walker/Carrying 모두 허용. WorkerState
	# ("digger")는 has_candy를 변경하지 않고, 종료 시 return_to_walking()이 CarryingState로 복원한다.
	# 수직 굴착 중 자유낙하(갱도 관통)는 FallerState로 이양되며 착지 시 운반이 복원된다(일반 carry-fall
	# 경로). 운반 개미가 갱도를 파고 내려가 운반을 이어갈 수 있다.
	if not (s is WalkerState or s is CarryingState):
		return false
	if not ant.is_on_floor():
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	ant.state_machine.change_state(WorkerState.new("digger"))
