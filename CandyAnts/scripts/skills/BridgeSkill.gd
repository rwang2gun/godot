class_name BridgeSkill extends Skill

const ID: String = "bridge"

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	# 이미 다리 무장 중이면 중복 부여(인벤토리 낭비) 차단 — 무장→지연 건설 도입(2026-06-02).
	if ant.bridge_armed:
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
	# 무장→지연 건설 (2026-06-02): 낭떠러지가 아닌 곳에서 부여하면 즉시 건설하지 않고 무장만 한다.
	# 개미가 그 스킬을 든 채 보행하다 낭떠러지(전방 바닥 없음)에 도달하면 Walker/Carrying이 자동 건설.
	# 이미 낭떠러지에서 부여하면(기존 동작) 즉시 그 자리(지표면 높이)에서 건설 — 한 frame도 지체 없음.
	if ant.bridge_cliff_ahead():
		ant.state_machine.change_state(WorkerState.new("bridge"))
	else:
		ant.bridge_armed = true
