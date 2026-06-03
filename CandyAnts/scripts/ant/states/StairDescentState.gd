class_name StairDescentState extends AntState

# 계단(builder STAIR) 부드러운 45° 하강 (2026-06-03). 등반(StairClimbState)의 하강 대칭.
# 계단 표면에서 하강 방향으로 진행 시 "수직 낙하 + 허공 보행 반복" 대신, 매 frame 전방+아래 대각으로
# global_position을 보간 이동 + 낙하 자세(fall 애니) 45° 회전으로 슬로프를 미끄러져 내려간다.
# move_and_slide를 쓰지 않는다 — 목적 셀(전방+아래)이 게이트로 보장되므로 직접 보간이 안전(climb와 동일).

const SPEED_SCALE: float = 1.2   # 보행 대비 1.2배 — 하강 미끄럼은 보행보다 20% 빠르게(2026-06-03 요청).
# 회전 각(도). 하강 슬로프 맞춤: "/" 하강(_dir=-1) → -45°, "\" 하강(_dir=+1) → +45° = 45*_dir.
const DESCEND_ANGLE_DEG: float = 45.0
const STAIRDESCENT_MAX_FRAMES: int = 2400

var _dir: int = 1
var _start: Vector2 = Vector2.ZERO
var _dest: Vector2 = Vector2.ZERO
var _t: float = 0.0
var _seg_len: float = 1.0
var _frames: int = 0

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	a.velocity = Vector2.ZERO
	_dir = a.direction if a.direction != 0 else 1
	_frames = 0
	_apply_rotation(a)
	if not _begin_segment(a):
		a.return_to_walking()

func exit() -> void:
	# 종료 시 스프라이트 회전 복원(보행 시 기울어진 잔상 방지) — climb와 동일.
	var a: Ant = ant as Ant
	if a != null and a._sprite != null:
		a._sprite.rotation = 0.0

func update(_delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	_frames += 1
	if _frames > STAIRDESCENT_MAX_FRAMES:
		a.return_to_walking()
		return
	_t += a.effective_speed() * SPEED_SCALE * _delta / _seg_len
	if _t >= 1.0:
		# 글라이드 중 타 개미가 _dest 셀을 점유했으면 스냅하지 않고 보행 복귀(climb와 동일 레이스 가드).
		if _dest_blocked(a):
			a.return_to_walking()
			return
		a.global_position = _dest
		a.velocity = Vector2.ZERO
		# 다음 계단이 이어지면 연속 하강, 아니면(바닥 단 도달) 보행 복귀.
		if not _begin_segment(a):
			a.return_to_walking()
		return
	a.global_position = _start.lerp(_dest, _t)

func _dest_blocked(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var dest_cell: Vector2i = Vector2i(
		int(floor(_dest.x / cs)),
		int(floor((_dest.y - 2.0) / cs))
	)
	return terrain.is_cell_occupied(dest_cell)

# 현재 위치에서 대각 1스텝(전방+아래)을 시작할 수 있는지 게이트 검사 + _start/_dest 설정.
# 게이트는 Ant.stair_descent_ahead(_dir) 단일 SoT — Walker/Carrying 진입 게이트와 공유.
# **셀 정렬 스냅**: 하강은 보행 중 비정렬 위치에서 트리거될 수 있어, 글라이드 시작점을 현재 계단의
# 정렬된 standing 위치로 스냅한다(상대 글라이드 누적 오프셋 → 바닥 어긋남·flip·재등반 오실레이션 방지).
func _begin_segment(a: Ant) -> bool:
	if not a.stair_descent_ahead(_dir):
		return false
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var stand: Vector2i = body_cell + Vector2i(0, 1)            # 현재 서 있는 계단
	var land: Vector2i = body_cell + Vector2i(_dir, 2)          # 다음 착지 계단(전방+아래)
	# 계단 셀 위 standing 위치(발=셀 상단, x=셀 중앙) — body_cell = floor((y-2)/cs)와 정합.
	_start = Vector2(float(stand.x) * cs + cs / 2.0, float(stand.y) * cs)
	_dest = Vector2(float(land.x) * cs + cs / 2.0, float(land.y) * cs)
	a.global_position = _start                                  # 정렬 스냅(드리프트 제거)
	_seg_len = float(cs) * sqrt(2.0)
	_t = 0.0
	return true

func _apply_rotation(a: Ant) -> void:
	if a._sprite != null:
		a._sprite.rotation = deg_to_rad(DESCEND_ANGLE_DEG) * float(_dir)

func _find_terrain(a: Ant) -> Terrain:
	var n: Node = a.get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null
