class_name SandMoundSkill extends Skill

const ID: String = "sand_mound"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
# target="cell": 표지판(①)을 표면 셀에 설치, 도착한 적격 개미에게 발동.
const SOLVER_META := {
	"target": "cell",
	"category": "SIGN",
	"hints": {"effect": "build_ladder_up"},
}

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
	ant.state_machine.change_state(WorkerState.new("sand_mound"))
