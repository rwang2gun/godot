class_name LadderClimbState extends AntState

# 막대과자 사다리(SAND_MOUND rung) 후속 개미 수직 등반 (2026-06-03).
# 시전 개미는 WorkerState("sand_mound")로 rung을 깔며 직접 올라 레지 위로 cap한다. 후속 walker는
# 그 rung 벽에 막히면(is_on_wall) 이 상태로 전이해, StairClimbState처럼 move_and_slide를 우회하고
# rung 기둥(_col)을 **rung 셀만** 수직으로 글라이드 관통해 오른다.
#
# 지지(support) = **현재 행의 rung이 살아있을 것** — 매 frame `is_ladder_cell(_col, body_row)` 단일 셀 검사.
# rung을 굴착/파괴(basher/digger)로 잃으면 그 즉시 FallerState로 전환(충돌 우회 글라이드로 무관 지형 관통·
# 부분 파괴 통과를 원천 차단; codex 2026-06-03 R1~R3 HIGH). 아래쪽 잔존 rung에 의존하지 않는다.
#
# 종료(꼭대기): 위 칸이 더는 rung이 아니면 **글라이드하지 않고 즉시 착지 이동**한다(비-rung 레지/플랫폼 칸을
# 글라이드 관통하지 않음 → 지지 검사가 항상 rung 단일 셀로 단순·타이트).
#   - cap: 위 칸이 점유(레지)이고 그 위가 빔(노출 walkable top) → 레지 위(위-2칸)로 올라서고 보행 복귀.
#   - open: 위 칸이 빔(허공 stack 꼭대기) → 그 칸(위-1)으로 올라서고 보행 복귀.
#   - blocked: 위도 위-위도 막힘(천장) → 더 못 올라감 → 현재 자리에서 보행 복귀(레벨 설계 회피 대상).
# 시전 개미의 cap(텔레포트 y-=2cs)과 일관 — 마지막 1~2칸은 즉시 이동, 그 아래 rung 구간만 부드럽게 글라이드.

# 한 수직 스텝(1칸) 글라이드 속도 배율. walk_speed 그대로면 보행과 동일 체감.
const SPEED_SCALE: float = 1.0
# 런어웨이 안전망 — 정상 등반은 cell당 ~수십 frame, 최대 사다리(5 rung+cap)도 수백 frame이면 끝난다.
const LADDERCLIMB_MAX_FRAMES: int = 2400

# enter 시점 lock — 등반 도중 blocker bounce 등으로 ant.direction이 뒤집혀도 등반 기둥·방향 유지.
var _dir: int = 1
var _col: int = 0            # 등반 대상 rung 기둥 cell.x (enter 시 전방 rung 셀 = lock).
var _start: Vector2 = Vector2.ZERO
var _dest: Vector2 = Vector2.ZERO
var _t: float = 0.0          # 현재 수직 스텝 진행도 0~1
var _seg_len: float = 1.0
var _frames: int = 0
# 개미 충돌 박스 half-height — 꼭대기 착지 시 "발밑 셀 위 보행 안착" y 계산용(enter에서 실측 캐시, fallback 7.5).
var _half_h: float = 7.5

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	a.velocity = Vector2.ZERO
	_dir = a.direction if a.direction != 0 else 1
	_frames = 0
	_half_h = _resolve_half_height(a)
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		a.return_to_walking()
		return
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = _body_cell(a, cs)
	# 등반 기둥 = 전방 rung 셀의 column. 이후 스텝은 이 기둥 중앙에 x를 맞춰 수직 상승.
	_col = body_cell.x + _dir
	# 첫 세그먼트 = **같은 행** rung 칸((_col, 현재행))으로 **수평 진입** (codex 2026-06-03 R4 HIGH).
	# 보행 레인→상단 rung으로의 대각 글라이드는 코너의 비-rung 솔리드를 관통할 수 있으므로, 먼저 수평으로
	# rung 기둥에 진입한 뒤(진입 칸은 rung=불변 유지) update의 snap에서 _advance가 수직 등반을 시작한다.
	_begin_glide(a, cs, body_cell.y)

func exit() -> void:
	# (사다리 등반은 스프라이트 회전 없음 — StairClimb과 달리 복원 불필요.)
	pass

func update(_delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	_frames += 1
	if _frames > LADDERCLIMB_MAX_FRAMES:
		a.return_to_walking()
		return
	var terrain: Terrain = _find_terrain(a)
	var cs: int = terrain.cell_size if terrain != null else 48
	# 지지 재검증 — **매 frame**: 현재 행의 rung이 살아있어야 글라이드 지속. 그 rung이 파괴/소멸되면
	# 즉시 중력에 맡긴다(codex R1~R3 HIGH). 단일 셀 검사라 아래쪽 잔존 rung으로 통과 못 함.
	if terrain == null or not terrain.is_ladder_cell(Vector2i(_col, _body_cell(a, cs).y)):
		a.state_machine.change_state(FallerState.new())
		return
	_t += a.effective_speed() * SPEED_SCALE * _delta / _seg_len
	if _t >= 1.0:
		# 목적 rung 셀에 정확히 스냅(오버슈트 0) → 다음 글라이드/착지 결정.
		a.global_position = _dest
		a.velocity = Vector2.ZERO
		_advance(a, terrain, cs, _body_cell(a, cs).y)
		return
	a.global_position = _start.lerp(_dest, _t)

# 현재 행(row)에서 한 칸 위를 보고: rung이면 글라이드 지속, 아니면 꼭대기 처리(즉시 착지).
# row는 호출자가 결정(enter=진입 행, snap=목적 rung 행) — body_cell.x가 기둥 밖(진입 시)이어도 _col로 판단.
func _advance(a: Ant, terrain: Terrain, cs: int, row: int) -> void:
	if terrain == null:
		a.return_to_walking()
		return
	var up: Vector2i = Vector2i(_col, row - 1)
	if terrain.is_ladder_cell(up):
		_begin_glide(a, cs, row - 1)   # 위도 rung → 한 칸 글라이드.
		return
	# 꼭대기 — 즉시 착지(비-rung 칸을 글라이드 관통하지 않는다).
	var above_up: Vector2i = Vector2i(_col, row - 2)
	if terrain.is_cell_occupied(up) and not terrain.is_cell_occupied(above_up):
		_land_at(a, cs, row - 2)        # cap: 레지 위(위-2칸)로 올라섬.
	elif not terrain.is_cell_occupied(up):
		_land_at(a, cs, row - 1)        # open: 허공 stack 꼭대기(위-1칸).
	else:
		# blocked(천장): 위도 위-위도 막힘 = 올라설 수 없는 벽. flip 후 보행 복귀해 등반-재진입 진동을 막는다.
		# (정상 사다리는 항상 cap/open top이라 미발생 — 천장 바로 위 rung 같은 레벨 설계 오류 방어.)
		a.flip()
		a.return_to_walking()

func _begin_glide(a: Ant, cs: int, dest_row: int) -> void:
	_start = a.global_position
	_dest = Vector2(float(_col) * cs + cs / 2.0, float(dest_row) * cs + cs / 2.0)
	_seg_len = _start.distance_to(_dest)
	if _seg_len <= 0.001:
		# 이미 목적지(이론상 미발생) — 무한 루프 방지로 보행 복귀.
		a.return_to_walking()
		return
	_t = 0.0

func _land_at(a: Ant, cs: int, row: int) -> void:
	# 개미가 row 칸에 몸을 두고 **발밑 셀(row+1) 위에 보행 안착**하도록 y를 맞춘다. 셀 정중앙(row*cs+cs/2)에
	# 놓으면 발밑 rung/레지 위로 (cs/2 - half_h)만큼(48px 셀=16.5px, 32px=8.5px) 떠서, 보행 복귀 직후
	# is_on_floor()=false → FallerState로 "꼭대기 낙하"한다(StairClimb·시전 cap의 상대 이동과 달리 절대
	# 셀-중앙 스냅이었던 게 원인, 2026-06-17). x는 기둥 중앙 정렬 유지.
	a.global_position = Vector2(
		float(_col) * cs + cs / 2.0,
		float(row + 1) * cs - _half_h
	)
	a.velocity = Vector2.ZERO
	a.return_to_walking()

func _body_cell(a: Ant, cs: int) -> Vector2i:
	return Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)

# 개미 충돌 박스 half-height 실측 — RectangleShape2D.size.y/2. 부재 시 Ant.tscn 기본(15px)의 절반 7.5.
func _resolve_half_height(a: Ant) -> float:
	var col: CollisionShape2D = a.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		return (col.shape as RectangleShape2D).size.y * 0.5
	return 7.5

func _find_terrain(a: Ant) -> Terrain:
	# WalkerState/StairClimbState._find_terrain와 동일 — ancestor chain에서 Terrain 노드 탐색.
	var n: Node = a.get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null
