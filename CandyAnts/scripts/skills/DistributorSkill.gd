class_name DistributorSkill extends Skill

const ID: String = "distributor"

# Phase 15 — 민들레씨 분배자. 영구 트레잇 set_trait(&"distributor")로 표시.
# 정착은 SettlementMarker가 위치 도달 시 트리거. 능력 전이도 SettlementMarker가 처리.

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	if ant.has_trait(&"distributor"):
		return false
	var s: AntState = ant.state_machine.current_state
	# WalkerState 또는 CarryingState 허용. Faller/Climber/Worker(blocker/builder)/Saved/Settled 거부.
	# Faller 거부 — Floater와 달리 분배자는 공중 부여 의미 약함(정착 위치까지 도달 불가능 위험).
	if not (s is WalkerState or s is CarryingState):
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null:
		return
	ant.set_trait(&"distributor")
