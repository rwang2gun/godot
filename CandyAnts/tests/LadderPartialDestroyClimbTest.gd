extends Node

# codex 2026-06-03 R3 HIGH 회귀 — 등반 중 **현재 행의 rung만** 파괴하고 그 아래 rung은 남겨도,
# 후속 개미가 (아래 잔존 rung에 의존해) 글라이드를 지속하지 않고 즉시 FallerState로 중단하는지 검증.
# (넓은 윈도우 지지 검사는 아래 rung으로 통과 → 레지 착지하는 버그를 막는 단일-셀 지지 검사 가드.)
#
# 시나리오: 첫 ant sand_mound 시전 → rung 기둥. 후속 ant가 레지 근처까지 LadderClimbState 등반 →
#   그 ant의 **현재 body 행 + 위쪽** rung만 destroy, **아래쪽 rung 1개 이상은 잔존**시킨 뒤
#   ant가 FallerState로 전환 + 레지 미도달을 확인.
# PASS: 하단 rung 잔존 확인 + victim→FallerState + 레지 미도달. FAIL: 레지 도달 / deadline.

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 420.0
const LEDGE_ROW: int = 17

var _terrain: Terrain = null
var _applied: bool = false
var _victim: Ant = null
var _destroyed: bool = false
var _saw_faller: bool = false
var _frame: int = 0
var _result_emitted: bool = false

func _ready() -> void:
	print("[LadderPartialDestroyClimbTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_catch_and_partial_destroy()
	_track_victim()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%s destroyed=%s victim=%s saw_faller=%s" % [
			_applied, _destroyed, _victim != null, _saw_faller])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../SandMoundStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain

func _apply_when_ready() -> void:
	if _applied or _terrain == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		if a.global_position.x < TRIGGER_X or not a.is_on_floor():
			continue
		var skill: SandMoundSkill = SandMoundSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		_applied = true
		return

func _catch_and_partial_destroy() -> void:
	if not _applied or _destroyed or _terrain == null:
		return
	var ledge_top_y: float = float(LEDGE_ROW * _terrain.cell_size)
	var near_top: float = ledge_top_y + 2.5 * float(_terrain.cell_size)
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is LadderClimbState):
			continue
		if a.global_position.y > near_top:
			continue
		var cs: int = _terrain.cell_size
		var bc: Vector2i = Vector2i(int(floor(a.global_position.x / cs)), int(floor((a.global_position.y - 2.0) / cs)))
		# 현재 행 + 위쪽 2칸 rung만 제거 — **아래쪽(bc.y+1..)은 보존**.
		var removed: int = 0
		for dy in range(-2, 1):   # bc.y-2, bc.y-1, bc.y (현재/상단)
			var cell: Vector2i = Vector2i(bc.x, bc.y + dy)
			if _terrain.is_ladder_cell(cell):
				_terrain.destroy_tile_at(cell, ["earth"])
				removed += 1
		# 아래쪽 rung 잔존 검증 — 부분 파괴 시나리오 성립 보장.
		var lower_remaining: int = 0
		for dy in range(1, 6):
			if _terrain.is_ladder_cell(Vector2i(bc.x, bc.y + dy)):
				lower_remaining += 1
		if removed == 0 or lower_remaining == 0:
			# 아직 충분히 안 올라옴(상단만 있거나 하단 없음) — 다음 프레임 재시도.
			continue
		_victim = a
		_destroyed = true
		print("[LadderPartialDestroyClimbTest] partial destroy: removed top %d rung(s) at col=%d, %d lower rung(s) remain, frame=%d pos=%s" % [
			removed, bc.x, lower_remaining, _frame, a.global_position])
		return

func _track_victim() -> void:
	if not _destroyed or _victim == null or not is_instance_valid(_victim):
		return
	var st: AntState = _victim.state_machine.current_state if _victim.state_machine != null else null
	if st is FallerState:
		_saw_faller = true
	if _terrain != null:
		var ledge_top_y: float = float(LEDGE_ROW * _terrain.cell_size)
		if _victim.global_position.y <= ledge_top_y + 8.0 and _victim.is_on_floor():
			_fail("victim climbed onto ledge after top-rung destruction (leftover lower rung bypass) y=%.1f" % _victim.global_position.y)
			return
		if _saw_faller and _victim.global_position.y > ledge_top_y + float(_terrain.cell_size):
			print("[LadderPartialDestroyClimbTest] PASS — victim aborted to FallerState (single-cell support), did not climb past destroyed top rung. y=%.1f frame=%d" % [
				_victim.global_position.y, _frame])
			_result_emitted = true
			get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[LadderPartialDestroyClimbTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
