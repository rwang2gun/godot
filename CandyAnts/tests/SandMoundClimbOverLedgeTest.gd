extends Node

# biscuit-ladder 지형 통합 (구 sand_mound climb-over 폐기, 2026-06-02) —
# 윗단 솔리드 레지(dev_sand_mound_layout: row 17 solid, x=11..40) 아래에서 사다리를 세울 때,
# 위 레지 surface를 만나면 "타고 넘어 계속 쌓기"가 아니라 그 면을 top으로 교체(cap)하고
# 개미가 그 위로 올라선 뒤 종료하는지 검증한다.
#
# PASS: apply 후 WorkerState 종료 + on_floor 시
#   (1) y <= 레지 상단(걷는 면) — 개미가 레지 위로 올라섬
#   (2) 시전 column의 레지 셀(row 17) 텍스처 = top (cap)
#   (3) 동적 rung 전부 middle
#   (4) 바닥 지형 면(최저 rung 바로 아래) = root

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 420.0   # cell 13 — 레지(x>=11) 바로 아래
const LEDGE_ROW: int = 17        # dev_sand_mound_layout의 윗단 솔리드 row

var _ant: Ant = null
var _applied: bool = false
var _applied_frame: int = 0
var _cast_col_x: int = 0          # 시전 시점 ant x-cell (이후 walker가 이동해도 cap/root 셀은 이 column).
var _frame: int = 0
var _result_emitted: bool = false
var _terrain: Terrain = null

func _ready() -> void:
	print("[SandMoundClimbOverLedgeTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _result_emitted:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_complete()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%s tile_count=%d state=%s y=%.1f" % [_applied, _tile_count(), _state_name(), _ant_y()])

func _ensure_refs() -> void:
	if _terrain == null:
		var stage: Node = get_node_or_null("../SandMoundStage")
		if stage != null:
			_terrain = stage.get_node_or_null("World/Terrain") as Terrain
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_ant = a
			return

func _apply_when_ready() -> void:
	if _applied or _ant == null or _ant.state_machine == null or _terrain == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	var skill: SandMoundSkill = SandMoundSkill.new()
	if not skill.can_apply(_ant):
		return
	_cast_col_x = int(floor(_ant.global_position.x / float(_terrain.cell_size)))
	skill.apply(_ant)
	_applied = true
	_applied_frame = _frame
	print("[SandMoundClimbOverLedgeTest] applied at frame=%d pos=%s col=%d" % [_frame, _ant.global_position, _cast_col_x])

func _check_complete() -> void:
	if not _applied or _ant == null or _ant.state_machine == null:
		return
	# 빌드 종료(WorkerState 탈출) + 레지 위 안착 대기. cap은 보통 첫 tick(~15 frame) 내.
	if _ant.state_machine.current_state is WorkerState:
		return
	if not _ant.is_on_floor():
		return
	if _terrain == null:
		_fail("terrain missing for cap check")
		return
	var cs: int = _terrain.cell_size
	var ledge_top_y: float = float(LEDGE_ROW * cs)
	var y: float = _ant.global_position.y
	# (1) 개미가 레지 위 걷는 면으로 올라섰는지.
	if y > ledge_top_y + 8.0:
		_fail("ant did not climb onto ledge — y=%.1f > ledge_top=%.1f tile_count=%d" % [y, ledge_top_y, _tile_count()])
		return
	# (2) 시전 column의 레지 셀(row 17) 텍스처 = top (cap).
	var ledge_sprite: Sprite2D = _terrain._cell_sprite(Vector2i(_cast_col_x, LEDGE_ROW))
	if ledge_sprite == null or ledge_sprite.texture == null:
		_fail("ledge tile missing at col=%d row=%d" % [_cast_col_x, LEDGE_ROW])
		return
	if not String(ledge_sprite.texture.resource_path).ends_with("biscuit_ladder_top_square.png"):
		_fail("ledge surface not capped to top: %s" % ledge_sprite.texture.resource_path)
		return
	# (3) 동적 rung 전부 middle + 최저 rung row 추적.
	var lowest_y: int = -2147483648
	for c in _terrain._placed.keys():
		var cell: Vector2i = c as Vector2i
		var sp: Sprite2D = _first_sprite(_terrain._placed[cell])
		if sp == null or sp.texture == null or not String(sp.texture.resource_path).ends_with("biscuit_ladder_middle_square.png"):
			_fail("dynamic rung not middle at %s" % cell)
			return
		if cell.y > lowest_y:
			lowest_y = cell.y
	if lowest_y == -2147483648:
		_fail("no dynamic rung placed")
		return
	# (4) 바닥 지형 면(최저 rung 바로 아래) = root.
	var ground_sprite: Sprite2D = _terrain._cell_sprite(Vector2i(_cast_col_x, lowest_y + 1))
	if ground_sprite == null or ground_sprite.texture == null:
		_fail("lower surface tile missing at col=%d row=%d" % [_cast_col_x, lowest_y + 1])
		return
	if not String(ground_sprite.texture.resource_path).ends_with("biscuit_ladder_root_square.png"):
		_fail("lower surface not root: %s" % ground_sprite.texture.resource_path)
		return
	print("[SandMoundClimbOverLedgeTest] PASS y=%.1f <= ledge_top=%.1f ledge=top rungs=middle ground=root tile_count=%d" % [y, ledge_top_y, _tile_count()])
	_result_emitted = true
	get_tree().quit(0)

func _first_sprite(body_v: Variant) -> Sprite2D:
	var body: Node = body_v as Node
	if body == null:
		return null
	for ch in body.get_children():
		if ch is Sprite2D:
			return ch as Sprite2D
	return null

func _tile_count() -> int:
	return _terrain.tile_count() if _terrain != null else -1

func _ant_y() -> float:
	return _ant.global_position.y if (_ant != null and is_instance_valid(_ant)) else -1.0

func _state_name() -> String:
	if _ant == null or _ant.state_machine == null or _ant.state_machine.current_state == null:
		return "null"
	return _ant.state_machine.current_state.get_class()

func _fail(msg: String) -> void:
	print("[SandMoundClimbOverLedgeTest] FAIL %s" % msg)
	_result_emitted = true
	get_tree().quit(1)
