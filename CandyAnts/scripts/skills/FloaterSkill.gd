class_name FloaterSkill extends Skill

const ID: String = "floater"

# 솔버 self-describing 메타 (D7) — SkillMetadataDriftTest가 category 동기·완전성을 강제.
const SOLVER_META := {
	"target": "ant",
	"category": "ANT_SETTLE",
	"hints": {"effect": "distribute_slow_fall"},
}

const _MARKER_SCENE := preload("res://scenes/world/SettlementMarker.tscn")

# 낙하산 분배자 (2026-06-03 재설계, B안). 적용 즉시 그 자리에 정착해 지나가는 개미에게
# slow-fall(floater) 트레잇을 분배한다.
# - 적용 즉시 SettledState로 정착(영구 정지). 자기 위치에 SettlementMarker를 동적 생성해
#   지나가는 보행/운반 개미에게 floater 트레잇 전이(SettledState.TRANSFER_WHITELIST=[floater]).
# - 운반 중이었다면 사탕을 바닥에 드롭 → 즉시 lost 회계(candy_piece_lost) + 재획득 가능한
#   DroppedCandy 생성. 비운반 보행 개미가 주우면 candy_piece_recovered로 lost→in_transit 보정.
# - 지면 위 개미에게만 부여 가능(낙하 중·물 속·등반/정착 중 불가).
#
# 주의: 이 스킬은 더 이상 시전 개미를 '자기 강하'시키지 않는다(자기 낙하산 폐기 — S5/S6/S9 재설계 필요).
#   slow-fall은 분배받은 개미에게만 적용된다. 분배자 본인은 floater 트레잇을 갖되 정착 후 낙하하지
#   않으므로 무해(전이 화이트리스트가 floater를 분배하려면 본인이 floater 트레잇을 보유해야 함).

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	if ant.has_trait(&"distributor"):
		return false
	# 지면 위 개미에게만 — 낙하 중(Faller)·물 속(LostState=사망)·등반/정착 중 부여 불가.
	if not ant.is_on_floor():
		return false
	var s: AntState = ant.state_machine.current_state
	if not (s is WalkerState or s is CarryingState):
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	# 운반 중이면 사탕 드롭 — 즉시 lost 회계 + 바닥에 재획득 가능한 DroppedCandy 생성(Skill 공용 헬퍼).
	_drop_carried_candy(ant)
	# 분배자 본인은 floater 트레잇 보유(정착 후 낙하 안 하므로 무해) → 전이 화이트리스트가 floater 분배.
	ant.set_trait(&"floater")
	ant.set_trait(&"distributor")
	# 적용 즉시 그 자리에 정착(영구 정지).
	ant.state_machine.change_state(SettledState.new())
	_spawn_marker(ant)

func _spawn_marker(ant: Ant) -> void:
	var parent: Node = ant.get_parent()
	if parent == null:
		return
	var marker: SettlementMarker = _MARKER_SCENE.instantiate() as SettlementMarker
	parent.add_child(marker)
	marker.global_position = ant.global_position
	marker.bind_distributor(ant)
