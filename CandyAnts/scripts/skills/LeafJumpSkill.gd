class_name LeafJumpSkill extends Skill

const ID: String = "leaf_jump"

# 나뭇잎 점프대 — SkillToolbar가 표지판 없이 LeafJumpPad를 지면에 직접 설치한다.
# 그 셀에 처음 도착한 적격 개미가 전방 LEAF_JUMP_CELLS타일을 포물선으로 비행(LeafJumpState,
# 낙하 모션)해 끈끈이 너머 바닥에 착지한다. 비행 내내 끈끈이 면역(Ant.is_jump_immune).
# LeafJumpPad는 재사용형이라 도착하는 모든 적격 개미가 반복 점프한다(무리 통행).
#
# 부여(인벤토리 차감)는 설치 시점(SkillToolbar._place_leaf_jump_pad), 발동은 LeafJumpPad가
# can_apply 재검사 후 LeafChargeState를 거쳐 수행한다.

# 전방으로 날아갈 타일 수(포물선 사거리). terrain.cell_size 비례라 cs 무관.
const LEAF_JUMP_CELLS: int = 4

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_alive():
		return false
	if not ant.is_on_floor():
		return false
	if ant.direction == 0:
		return false
	var s: AntState = ant.state_machine.current_state
	# Walker/Carrying만 — 둘 다 끈끈이에 정지하므로 점프 대상. 홉은 state 변경/has_candy 변동이
	# 없어 in_transit 정산에 영향 없음(WorkerState 진입 스킬과 달리 Carrying 허용 안전).
	if not (s is WalkerState or s is CarryingState):
		return false
	# 착지 가능한 전방 바닥이 있어야 발동 — 허공/벽으로 점프 금지. LeafJumpPad 발동 시점에 재검사된다.
	if ant.leaf_landing_cell(LEAF_JUMP_CELLS) == Ant.LEAF_NO_LANDING:
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null:
		return
	ant.leaf_jump_launch(LEAF_JUMP_CELLS)
