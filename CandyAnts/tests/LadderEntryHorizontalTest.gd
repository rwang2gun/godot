extends Node

# codex 2026-06-03 R4 HIGH 회귀 — 사다리 진입이 **대각 글라이드가 아니라 수평 진입**임을 검증.
# 보행 레인(_col-1)에서 상단 rung으로 대각 이동하면 move_and_slide 우회로 코너의 비-rung 솔리드를
# 관통할 수 있다. 수정판은 먼저 같은 행 rung 칸(_col, 진입행)으로 수평 진입한 뒤 수직 등반한다.
#
# 불변(invariant): LadderClimbState인 개미는 **기둥(_col)에 x가 도달하기 전에는 진입행보다 위로 오르지 않는다**.
#   즉 (body.y < 진입행) AND (body.x < 기둥열) 인 순간이 절대 없어야 한다(대각이면 그 순간이 생긴다).
# PASS: 후속 개미가 레지 도달(등반 동작 입증) + 진입 위반 0건. FAIL: 위반 관측 / deadline.

const DEADLINE_FRAMES: int = 2400
const TRIGGER_X: float = 420.0
const LEDGE_ROW: int = 17

var _terrain: Terrain = null
var _applied: bool = false
var _frame: int = 0
var _result_emitted: bool = false
var _entry: Dictionary = {}        # instance_id → {row:int, col:int}  (LadderClimbState 진입 시점 기록)
var _follower_on_ledge: bool = false

func _ready() -> void:
	print("[LadderEntryHorizontalTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_entry_invariant()
	if _follower_on_ledge:
		print("[LadderEntryHorizontalTest] PASS — follower climbed to ledge via horizontal entry, no diagonal corner-phase. frame=%d" % _frame)
		_result_emitted = true
		get_tree().quit(0)
		return
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%s entries=%d follower_on_ledge=%s" % [_applied, _entry.size(), _follower_on_ledge])

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

func _check_entry_invariant() -> void:
	if _terrain == null:
		return
	var cs: int = _terrain.cell_size
	var ledge_top_y: float = float(LEDGE_ROW * cs)
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		var id: int = a.get_instance_id()
		var bc: Vector2i = Vector2i(int(floor(a.global_position.x / cs)), int(floor((a.global_position.y - 2.0) / cs)))
		if a.state_machine.current_state is LadderClimbState:
			if not _entry.has(id):
				# 진입 시점 기록: 진입행 = 현재 행, 기둥열 = 전방 rung column(= body.x + dir).
				_entry[id] = {"row": bc.y, "col": bc.x + a.direction}
			var rec: Dictionary = _entry[id]
			# 불변 위반: 기둥에 x 도달 전(body.x < col)에 진입행보다 위(body.y < row)로 올라섰다 = 대각.
			if bc.y < int(rec["row"]) and bc.x < int(rec["col"]):
				_fail("diagonal entry detected — body=%s rose above entry_row=%d before reaching col=%d" % [
					bc, int(rec["row"]), int(rec["col"])])
				return
		# 사다리를 탔던(진입 기록 있는) 개미가 레지 위 걷는 면에 도달(등반 동작 입증) — 보행 복귀 후에도 체크.
		if _entry.has(id) and a.global_position.y <= ledge_top_y + 8.0 and a.is_on_floor():
			_follower_on_ledge = true

func _fail(msg: String) -> void:
	print("[LadderEntryHorizontalTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
