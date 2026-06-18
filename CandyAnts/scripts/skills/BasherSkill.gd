class_name BasherSkill extends Skill

const ID: String = "basher"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
const SOLVER_META := {
	"target": "cell",
	"category": "SIGN",
	"hints": {"effect": "dig_horizontal", "needs": "earth_wall"},
}

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	# 이미 무장(굴착/절단/다리/계단) 중이면 중복 부여 차단 — 무장 스킬은 상호 배타(bridge/builder와 대칭).
	if ant.basher_armed or ant.cutter_armed or ant.bridge_armed or ant.builder_armed:
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
	# 무장→지연 굴착 (2026-06-05, Bridge/Builder 패턴 복제): 전방이 열려 있으면(벽 없음) 즉시 굴착하지 않고
	# 무장만 한다. 개미가 basher를 든 채 보행하다 흙 벽(전방 셀 earth)에 도달하면 Walker가 자동으로 전방
	# 최대 5칸을 굴착하고 해제. 이미 벽에서 부여하면(전방 막힘) 기존처럼 즉시 처리 — 흙이면 그 자리 굴착,
	# 흙이 아닌 벽(식물/쿠키)이면 WorkerState가 자연 abort(cross-kind 침범 차단 유지).
	if ant.forward_cell_open():
		ant.basher_armed = true
	else:
		ant.state_machine.change_state(WorkerState.new("basher"))
