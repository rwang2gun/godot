class_name StairClimbState extends AntState

# 계단(builder STAIR) 부드러운 45° 보행 등반 (2026-06-03, 구 WalkerState 순간이동 step-up 폐기).
# 사각 48×48 충돌 블록은 그대로 두되, 전방 계단 셀의 벽면에 막혀 멈춘 walker를 이 상태로 전이시켜
# 매 frame 대각선(전방+위)으로 global_position을 직접 보간 이동 + 스프라이트 45° 회전으로 매끄럽게 오른다.
# 진짜 슬로프 충돌(move_and_slide)은 쓰지 않는다 — 전방 사각 블록에 막히고, 세션4가 floor_max_angle
# 경계 epsilon 리스크로 슬로프를 기각했기 때문. 목적 셀(전방+위)이 게이트로 빈칸 보장되므로 직접 이동이 안전.

# 한 대각 스텝(전방+위 1칸) 글라이드 속도 배율. walk_speed 그대로 쓰면 보행과 동일 체감.
const SPEED_SCALE: float = 1.0
# 회전 각(도). +Y가 아래라 "/" 상승은 반시계(음각) — _apply_rotation에서 -_dir 부호로 적용.
const CLIMB_ANGLE_DEG: float = 45.0
# 런어웨이 안전망 — 정상 등반은 스텝당 ~45 frame, 최대 계단도 수백 frame이면 끝난다.
# 이 한계 초과면(가령 등반 도중 타 개미 굴착으로 목적 셀 소멸 등) 방어적으로 보행 복귀.
const STAIRCLIMB_MAX_FRAMES: int = 2400

# enter 시점 lock — 등반 도중 blocker bounce 등으로 ant.direction이 뒤집혀도 등반 방향·회전 유지.
var _dir: int = 1
var _start: Vector2 = Vector2.ZERO
var _dest: Vector2 = Vector2.ZERO
var _t: float = 0.0          # 현재 대각 스텝 진행도 0~1
var _seg_len: float = 1.0    # 대각 스텝 길이 = cell_size * sqrt(2)
var _frames: int = 0

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	a.velocity = Vector2.ZERO
	_dir = a.direction if a.direction != 0 else 1
	_frames = 0
	_apply_rotation(a)
	# 첫 대각 스텝 무장. 진입 게이트가 통과했으므로 정상 true지만, 방어적으로 실패 시 보행 복귀.
	if not _begin_segment(a):
		a.return_to_walking()

func exit() -> void:
	# 모든 종료 경로(정상 완료/안전망)에서 스프라이트 회전 복원 — 보행 시 기울어진 잔상 방지.
	var a: Ant = ant as Ant
	if a != null and a._sprite != null:
		a._sprite.rotation = 0.0

func update(_delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	_frames += 1
	if _frames > STAIRCLIMB_MAX_FRAMES:
		a.return_to_walking()
		return
	# 대각선 따라 effective_speed*delta px 전진 → 스텝 길이로 정규화해 _t 증가.
	# effective_speed = 운반 중이면 carry 페널티(0.78x) 포함 → carry 등반이 carry 보행과 동일 체감.
	_t += a.effective_speed() * SPEED_SCALE * _delta / _seg_len
	if _t >= 1.0:
		# 글라이드(다중 frame)는 move_and_slide를 우회하므로, 그 사이 타 개미(builder/basher/sand_mound)가
		# _dest 셀을 점유하면 스냅 시 solid에 박힌다. 스냅 직전 재검사 — 점유됐으면 스냅하지 않고 보행 복귀해
		# move_and_slide가 충돌을 해소하게 한다 (codex 2026-06-03 MEDIUM — 터레인 변형 레이스).
		if _dest_blocked(a):
			a.return_to_walking()
			return
		# 목적 셀에 정확히 스냅(오버슈트 0) — body_cell 계산 결정성 유지.
		a.global_position = _dest
		a.velocity = Vector2.ZERO
		# 다음 계단 스텝이 이어지면 연속 등반, 아니면(꼭대기/평지 도달) 보행 복귀.
		if not _begin_segment(a):
			a.return_to_walking()
		return
	a.global_position = _start.lerp(_dest, _t)

# _dest body 셀이 (글라이드 중) 점유됐는지 — 스냅 전 박힘 방지 재검사.
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

# 현재 위치에서 대각 1스텝(전방+위)을 시작할 수 있는지 게이트 검사 + _start/_dest 설정.
# 게이트는 Ant.stair_climb_ahead(_dir) 단일 SoT — WalkerState/CarryingState 진입 게이트와 동일.
# **전방 벽 점유 필수**라 계단 꼭대기 허공에선 연속 스텝이 멈춘다(codex 2026-06-03 HIGH — over-climb 차단).
func _begin_segment(a: Ant) -> bool:
	if not a.stair_climb_ahead(_dir):
		return false
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	_start = a.global_position
	_dest = a.global_position + Vector2(float(_dir) * cs, float(-cs))
	_seg_len = float(cs) * sqrt(2.0)
	_t = 0.0
	return true

func _apply_rotation(a: Ant) -> void:
	# "/" 상승(_dir=+1)은 반시계(음각), "\" 상승(_dir=-1)은 시계(양각). 부호·값은 시각 튜닝 대상.
	if a._sprite != null:
		a._sprite.rotation = deg_to_rad(CLIMB_ANGLE_DEG) * float(-_dir)

func _find_terrain(a: Ant) -> Terrain:
	# WalkerState/WorkerState._find_terrain와 동일 — ancestor chain에서 Terrain 노드 탐색.
	var n: Node = a.get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null
