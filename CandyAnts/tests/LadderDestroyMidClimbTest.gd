extends Node

# codex 2026-06-03 HIGH 회귀 — 등반(LadderClimbState) 도중 rung이 파괴되면 충돌 우회 글라이드로
# 무관 지형을 관통해 위로 튀어나오지 않고, 지지(rung)를 잃는 즉시 FallerState로 전환(중력 낙하)하는지 검증.
#
# 시나리오: dev_sand_mound 레지(row17) 아래에서 첫 ant가 sand_mound 시전 → rung 기둥 건설.
#   후속 ant가 LadderClimbState 진입하는 순간 모든 동적 rung을 destroy_tile_at로 제거 →
#   그 ant가 (가드로) FallerState로 전환하고 **레지 위로 올라서지 못함**을 확인.
# PASS: victim이 LadderClimbState→FallerState 전환 관측 + 레지 위 미도달. FAIL: 레지 도달 / deadline.

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
	print("[LadderDestroyMidClimbTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_catch_and_destroy()
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
		print("[LadderDestroyMidClimbTest] sand_mound cast frame=%d" % _frame)
		return

func _catch_and_destroy() -> void:
	if not _applied or _destroyed or _terrain == null:
		return
	# 후속 ant가 LadderClimbState로 **레지 근처(최종 세그먼트)까지 등반**했을 때 포착 → 모든 동적 rung 제거.
	# (codex R2 — 진입 즉시가 아니라 지지 검사 통과 후 final-segment 파괴를 노린다.)
	var ledge_top_y: float = float(LEDGE_ROW * _terrain.cell_size)
	var near_top: float = ledge_top_y + 2.5 * float(_terrain.cell_size)
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or a.state_machine == null:
			continue
		if not (a.state_machine.current_state is LadderClimbState):
			continue
		if a.global_position.y > near_top:
			continue   # 아직 하단 — 레지 근처까지 더 오르길 기다린다.
		_victim = a
		var cells: Array = _terrain._sand_mound_sprites.keys().duplicate()
		for c in cells:
			_terrain.destroy_tile_at(c as Vector2i, ["earth"])
		_destroyed = true
		print("[LadderDestroyMidClimbTest] caught victim in LadderClimbState, destroyed %d rungs frame=%d pos=%s" % [
			cells.size(), _frame, a.global_position])
		return

func _track_victim() -> void:
	if not _destroyed or _victim == null or not is_instance_valid(_victim):
		return
	var st: AntState = _victim.state_machine.current_state if _victim.state_machine != null else null
	if st is FallerState:
		_saw_faller = true
	# 가드 실패 시(버그) victim이 레지 위로 올라섬 → 즉시 FAIL.
	if _terrain != null:
		var ledge_top_y: float = float(LEDGE_ROW * _terrain.cell_size)
		if _victim.global_position.y <= ledge_top_y + 8.0 and _victim.is_on_floor():
			_fail("victim climbed onto ledge after rung destruction (collision-bypass glide) y=%.1f" % _victim.global_position.y)
			return
	# FallerState 관측 후 충분히 낙하(레지보다 한참 아래)했으면 PASS.
	if _saw_faller and _terrain != null:
		var ledge_top_y: float = float(LEDGE_ROW * _terrain.cell_size)
		if _victim.global_position.y > ledge_top_y + float(_terrain.cell_size):
			print("[LadderDestroyMidClimbTest] PASS — victim aborted to FallerState + fell below ledge (y=%.1f) frame=%d" % [
				_victim.global_position.y, _frame])
			_result_emitted = true
			get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[LadderDestroyMidClimbTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
