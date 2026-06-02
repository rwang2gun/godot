class_name WalkerState extends AntState

# 첫 frame에 is_on_floor()가 false로 잡혀 즉시 Faller 전이되는 깜박임 방지용 grace.
var _frame: int = 0

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	# Phase 17 — sticky stuck 시 좌우 0, 중력만 + slide. flip/climber/faller 전이 모두 skip.
	# _frame 증가도 skip(stuck 중 grace 카운트 동결) — stuck 해방 후 첫 frame이 Walker 진입 직후와 동일하게 동작.
	if a.is_stuck():
		a.velocity.x = 0.0
		a.velocity.y += a.gravity * delta
		a.move_and_slide()
		return

	a.velocity.y += a.gravity * delta
	a.velocity.x = float(a.direction) * a.effective_speed()
	a.move_and_slide()
	_frame += 1

	# 무장한 다리 스킬 — 낭떠러지 도달 시 그 자리(지표면 높이)에서 자동 건설. 전이 시 즉시 return.
	if a.try_build_armed_bridge():
		return

	if a.is_on_wall():
		# Phase 14 — climber 보유 시 벽에서 ClimberState로 전이, 아니면 기존대로 flip.
		if a.has_trait(&"climber"):
			a.state_machine.change_state(ClimberState.new())
			return
		# builder 대각 계단(STAIR) 1칸 step-up — 계단 셀이 관여하는 벽 충돌만 등반으로 처리.
		# 정적 벽(S1 분지 등)은 게이트 불충족 → 기존 flip 유지(climber 필수 퍼즐 보존).
		if _try_stair_step_up(a):
			return
		a.flip()

	if _frame > 1 and not a.is_on_floor():
		a.state_machine.change_state(FallerState.new())

# builder 계단(정사각 STAIR 타일)을 walker가 보행 등반하도록 1칸 step-up.
# 게이트: 전방 벽 셀이 STAIR이거나(계단 진입·계단 간 등반) 발밑이 STAIR(계단 꼭대기→정적 단 진입)일 때만,
#   그리고 올라설 목적 셀(전방+위)이 비어 있을 때만. 그 외(정적 벽)는 false → 호출부가 flip.
# 동작: builder _place_one_tile와 동일한 (dir*cs, -cs) 텔레포트로 전방 계단/단 위에 올라선다(결정적).
# down 방향은 계단 가장자리 1칸 낙하(기존 Faller)로 자연 처리되므로 step-up 불필요.
func _try_stair_step_up(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	if a.direction == 0:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var front: Vector2i = body_cell + Vector2i(a.direction, 0)
	var below: Vector2i = body_cell + Vector2i(0, 1)
	# 계단이 관여하지 않는 벽이면 step-up 금지(정적 벽 = climber 퍼즐 보존).
	if not (terrain.is_stair_cell(front) or terrain.is_stair_cell(below)):
		return false
	# 올라설 자리(전방+위)가 막혀 있으면 등반 불가(레지/천장).
	var dest: Vector2i = body_cell + Vector2i(a.direction, -1)
	if terrain.is_cell_occupied(dest):
		return false
	# 전방 계단/단 위로 1칸 상승 + 전진(builder 텔레포트와 동일 델타). 하강 모멘텀 제거 + grace 재무장.
	a.velocity.y = 0.0
	a.global_position += Vector2(float(a.direction) * cs, float(-cs))
	_frame = 0
	return true

func _find_terrain(a: Ant) -> Terrain:
	# WorkerState._find_terrain와 동일 — ancestor chain에서 Terrain 노드 탐색.
	var n: Node = a.get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null
