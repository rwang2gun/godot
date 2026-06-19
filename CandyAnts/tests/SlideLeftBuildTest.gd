extends Node2D

# slideL(왼쪽 경사면) 좌향 대각 계단 검증 — BuilderDiagonalTest(우향 slideR)의 좌우 미러.
# 우측 평지에 개미를 좌향(direction=-1)으로 두고 SlideLSkill 부여 → armed(builder_armed_dir=-1) →
# 좌측 끝 낭떠러지(col3) 도달 시 좌향 대각 계단 자동 건설(전방=왼쪽 + 위). 부여는 갭서 충분히 떨어진
# 우측(col10 이하)에서 → 즉시건설 아닌 armed 지연을 거쳐 좌측 cliff에서 발화하는 경로까지 검증한다.
# PASS: 부여 시점 대비 y가 RISE_CELLS(4)칸 이상 상승. 평지 slideL이면 y 불변 → FAIL(좌향 대각 식별력).
# (코드 자족 셋업 — ArmedSkillMutexTest 패턴: Terrain.new()+add_tile로 보행면 구성, scene/layout 불요.)

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const CS: int = 48
const FLOOR_ROW: int = 8
const FLOOR_COL_MIN: int = 4     # 좌측 끝 — 여기서 왼쪽(col3)은 타일 없음=낭떠러지(좌향 계단 시작점).
const FLOOR_COL_MAX: int = 16    # 우측 끝 — 개미 스폰 근처.
const SPAWN_COL: int = 14
const TRIGGER_X: float = float(10 * CS)   # 개미가 좌향으로 col10(x=480) 이하 도달 시 부여(갭서 충분히 우측=armed 지연).
const RISE_CELLS: int = 4
const DEADLINE_FRAMES: int = 1800

var _terrain: Terrain = null
var _ant: Ant = null
var _applied: bool = false
var _start_y: float = 0.0
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	_terrain = Terrain.new()
	_terrain.name = "Terrain"
	_terrain.set_cell_size(CS)
	add_child(_terrain)
	# 우측 평지(cols 4~16, row8) — 개미 좌향 보행면. 좌측 col3 이하는 타일 없음=낭떠러지.
	for c in range(FLOOR_COL_MIN, FLOOR_COL_MAX + 1):
		_terrain.add_tile(Vector2i(c, FLOOR_ROW), Terrain.DYNAMIC_TILE_BRIDGE)
	_ant = ANT_SCENE.instantiate() as Ant
	_ant.direction = -1
	_ant.global_position = Vector2(SPAWN_COL * CS + 24, FLOOR_ROW * CS - 8)
	add_child(_ant)
	print("[SlideLeftBuildTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _ant == null or not is_instance_valid(_ant) or _ant.state_machine == null:
		return
	_apply_when_ready()
	_check_rise()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — applied=%s rise=%.1f tiles=%d" % [_applied, _rise(), _terrain.tile_count()])

func _apply_when_ready() -> void:
	if _applied:
		return
	if not (_ant.state_machine.current_state is WalkerState):
		return
	if not _ant.is_on_floor():
		return
	if _ant.global_position.x > TRIGGER_X:
		return   # 아직 갭서 충분히 좌측으로 안 옴 — armed 지연(즉시건설 아님) 입증 위해 대기.
	var skill: SlideLSkill = SlideLSkill.new()
	if not skill.can_apply(_ant):
		return
	_start_y = _ant.global_position.y
	skill.apply(_ant)
	_applied = true
	print("[SlideLeftBuildTest] applied slideL at frame=%d pos=%s dir=%d armed_dir=%d" % [
		_frame, _ant.global_position, _ant.direction, _ant.builder_armed_dir])

func _check_rise() -> void:
	if not _applied or _ant == null or not is_instance_valid(_ant):
		return
	if _rise() >= float(RISE_CELLS * CS):
		print("[SlideLeftBuildTest] PASS rise=%.1f tiles=%d frame=%d" % [_rise(), _terrain.tile_count(), _frame])
		_done = true
		get_tree().quit(0)

func _rise() -> float:
	if _ant == null or not is_instance_valid(_ant):
		return -1.0
	return _start_y - _ant.global_position.y   # 상승 = y 감소

func _fail(msg: String) -> void:
	print("[SlideLeftBuildTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
