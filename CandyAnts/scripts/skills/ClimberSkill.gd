class_name ClimberSkill extends Skill

const ID: String = "climber"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
const SOLVER_META := {
	"target": "ant",
	"category": "ANT_ARMED",
	"routing": "up",
	"purpose": "개미를 무장해 벽을 만나면 반전 대신 등반해 위로 넘게 한다",
	"hints": {"effect": "climb_wall"},
}

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
