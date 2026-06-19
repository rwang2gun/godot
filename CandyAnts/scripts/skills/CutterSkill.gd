class_name CutterSkill extends Skill

const ID: String = "cutter"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
const SOLVER_META := {
	"target": "cell",
	"category": "SIGN",
	"routing": "break",
	"purpose": "앞의 식물벽을 잘라 통로를 연다",
	"hints": {"effect": "cut_plant", "needs": "plant_wall"},
}

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	# 이미 무장(절단/굴착/다리/계단) 중이면 중복 부여 차단 — 무장 스킬은 상호 배타.
	if ant.cutter_armed or ant.basher_armed or ant.bridge_armed or ant.builder_armed:
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
	# 무장→지연 절단 (2026-06-05, Basher 패턴 복제): 전방이 열려 있으면(벽 없음) 즉시 절단하지 않고 무장만 한다.
	# 개미가 cutter를 든 채 보행하다 식물 벽(전방 셀 plant)에 도달하면 Walker가 자동으로 연결 덩쿨을 일괄 절단하고
	# 해제. 이미 벽에서 부여하면(전방 막힘) 기존처럼 즉시 처리 — 식물이면 절단, 식물이 아닌 벽(흙/쿠키)이면
	# WorkerState가 자연 abort(cross-kind 침범 차단 유지).
	if ant.forward_cell_open():
		ant.cutter_armed = true
	else:
		ant.state_machine.change_state(WorkerState.new("cutter"))
