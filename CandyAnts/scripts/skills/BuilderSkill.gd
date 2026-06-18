class_name BuilderSkill extends Skill

const ID: String = "builder"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
const SOLVER_META := {
	"target": "ant",
	"category": "ANT_ARMED",
	"hints": {"effect": "build_stair", "arms_until": "cliff"},
}

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	# 이미 무장(계단 또는 다리) 중이면 중복 부여 차단 — 무장 스킬은 상호 배타(codex 2026-06-03 MEDIUM).
	# bridge_armed인 ant에 builder를 부여하면 낭떠러지에서 try_build_armed_bridge가 먼저 발화해
	# builder가 그림자 처리(인벤토리만 소모)되므로, 한 번에 한 무장만 허용한다.
	if ant.builder_armed or ant.bridge_armed or ant.basher_armed or ant.cutter_armed:
		return false
	var s: AntState = ant.state_machine.current_state
	# Walker 또는 Carrying만 허용. Faller/Worker/Saved/Dead 거부.
	if not (s is WalkerState or s is CarryingState):
		return false
	if not ant.is_on_floor():
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	# 무장→지연 건설 (2026-06-03, BridgeSkill 패턴 복제): 낭떠러지가 아닌 곳에서 부여하면 즉시 건설하지
	# 않고 무장만 한다. 개미가 그 스킬을 든 채 보행하다 낭떠러지(전방 바닥 없음)에 도달하면 Walker/Carrying이
	# 자동으로 대각 계단을 건설. 이미 낭떠러지에서 부여하면(기존 동작) 즉시 그 자리에서 건설 — 한 frame도 지체 없음.
	if ant.cliff_ahead():
		ant.state_machine.change_state(WorkerState.new("builder"))
	else:
		ant.builder_armed = true
