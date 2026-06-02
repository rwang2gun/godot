extends Node

# Builder 대각선 상승 검증 (2026-06-02 builder 정합성 개정).
# 첫 walker ant에 BuilderSkill 적용 → 대각선 계단으로 ASCEND(전방+위).
# PASS: deadline 내, builder ant가 적용 시점 대비 y가 RISE_CELLS(4)칸 이상 상승.
#   - 평지 builder였다면 y 불변 → rise≈0 → FAIL. 대각선이어야만 통과한다(회귀 식별력 확보).
# 라운드트립/사탕 도달은 검증 범위 밖(overshoot 의존 회피) — 캠페인 스테이지 저작 시 별도 검증.

const DEADLINE_FRAMES: int = 1800
const TRIGGER_X: float = 330.0   # cell ~10 (좌측 platform 위, 우측 상승 여유 있음)
const CELL: int = 32
const RISE_CELLS: int = 4

var _ant: Ant = null
var _applied: bool = false
var _start_y: float = 0.0
var _frame: int = 0
var _done: bool = false
var _terrain: Terrain = null
var _stage: Node = null

func _ready() -> void:
	EventBus.stage_failed.connect(_on_failed)
	print("[BuilderDiagonalTest] driver ready trigger_x=", TRIGGER_X, " rise_cells=", RISE_CELLS)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_apply_when_ready()
	_check_rise()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%s rise=%.1f tiles=%d" % [_applied, _rise(), _tile_count()])

func _check_rise() -> void:
	if not _applied or _ant == null or not is_instance_valid(_ant):
		return
	if _rise() >= float(RISE_CELLS * CELL):
		print("[BuilderDiagonalTest] PASS rise=%.1f tiles=%d frame=%d" % [_rise(), _tile_count(), _frame])
		_done = true
		get_tree().quit(0)

func _rise() -> float:
	if _ant == null or not is_instance_valid(_ant):
		return -1.0
	return _start_y - _ant.global_position.y   # 상승 = y 감소

func _tile_count() -> int:
	return _terrain.tile_count() if _terrain != null else -1

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../BuilderStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	# 적용 후에는 builder ant ref를 고정(다른 ant로 교체 금지).
	if _applied:
		return
	if _ant != null and is_instance_valid(_ant):
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a != null:
			_ant = a
			return

func _apply_when_ready() -> void:
	if _applied or _ant == null or _ant.state_machine == null:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if _ant.global_position.x < TRIGGER_X:
		return
	if not _ant.is_on_floor():
		return
	var skill: BuilderSkill = BuilderSkill.new()
	if not skill.can_apply(_ant):
		return
	_start_y = _ant.global_position.y
	skill.apply(_ant)
	_applied = true
	print("[BuilderDiagonalTest] applied builder at frame=%d pos=%s" % [_frame, _ant.global_position])

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	# stage_failed(no_more_ants/time_out)가 와도 상승만 확인되면 PASS.
	if _applied and _rise() >= float(RISE_CELLS * CELL):
		print("[BuilderDiagonalTest] PASS (post-failed) rise=%.1f reason=%s" % [_rise(), result["reason"]])
		_done = true
		get_tree().quit(0)
		return
	_fail("stage_failed reason=%s applied=%s rise=%.1f" % [result["reason"], _applied, _rise()])

func _fail(msg: String) -> void:
	print("[BuilderDiagonalTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
