class_name SandMoundSkill extends Skill

const ID: String = "sand_mound"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
# target="cell": 표지판(①)을 표면 셀에 설치, 도착한 적격 개미에게 발동.
const SOLVER_META := {
	"target": "cell",
	"category": "SIGN",
	"routing": "up",
	"purpose": "표면에 사다리를 세워 개미를 위층으로 올린다",
	"hints": {"effect": "build_ladder_up"},
}

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	var s: AntState = ant.state_machine.current_state
	# 운반자 통일 (2026-06-20) — bridge/slide와 동일하게 Walker/Carrying 모두 허용. 구 "Carrying·
	# has_candy 거부"의 사유(작업 중 has_candy 잔존 → in_transit 영구 잔존)는 해소됐다: WorkerState
	# ("sand_mound")는 has_candy를 변경하지 않고(line 71 가드), 종료 시 모든 분기가 return_to_walking()을
	# 호출해 has_candy면 CarryingState로 복원하므로 운반 개미가 사다리를 짓고 운반을 이어갈 수 있다.
	if not (s is WalkerState or s is CarryingState):
		return false
	if not ant.is_on_floor():
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	ant.state_machine.change_state(WorkerState.new("sand_mound"))
