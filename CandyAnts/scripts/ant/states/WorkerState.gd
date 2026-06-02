class_name WorkerState extends AntState

# Phase 16 v4: const CELL_SIZE 삭제 — placement 함수는 terrain.cell_size를 dynamic read.
# Builder 기존 분기도 terrain.cell_size 사용 → Stage 02/03(terrain.cell_size=16 default)
# 회귀 0건. dev_*_layout 사용 stage(cell_size=32)는 새 단위로 placement.

const TICK_SECONDS: float = 0.2
const TOTAL_TILES: int = 12

const SAND_MOUND_TICK: float = 0.25
const SAND_MOUND_MAX_HEIGHT: int = 5

const BRIDGE_TICK: float = 0.20
const BRIDGE_MAX_LENGTH: int = 8

# Phase 18 — Basher(수평 굴착) + Digger(수직 굴착) 상수.
# DIGGER_OFF_FLOOR_LIMIT: void 무한 낙하 안전망 (D11, codex R1 H1). 3초 @ 60fps.
# 정상 1~5 cell drop(1~60 frames)에서 trigger X. hazard도 없는 완전한 void에서만 발동.
const BASHER_TICK: float = 0.18
const BASHER_MAX_CELLS: int = 12
const DIGGER_TICK: float = 0.20
const DIGGER_MAX_CELLS: int = 12
const DIGGER_OFF_FLOOR_LIMIT: int = 180

# Phase 19 — Cutter 수평 절단(식물). Basher 패턴 답습, kind 검사만 "plant"로 교체.
const CUTTER_TICK: float = 0.18
const CUTTER_MAX_CELLS: int = 12

var _work_type: String = ""
var _remaining: int = 0
var _tick_accum: float = 0.0
var _aborted: bool = false
# biscuit-ladder(구 sand_mound): 시전 1회 아래 면 root 교체 완료 플래그.
var _ladder_root_done: bool = false
# Phase 16 v7 — bridge floor-contact guard: 첫 tile 전 off-floor는 1-frame grace.
# ant가 다시 floor 위로 안착하면 reset되어 다음 off-floor cycle에 또 grace 1회 사용 가능.
# tile placement는 항상 off-floor frame에서 차단(grace frame은 return으로 skip, abort frame은
# placement loop 진입 전 종료). 진짜 fall은 연속 off-floor 2 frame으로 즉시 abort.
var _bridge_floor_grace_used: bool = false
# Phase 18 — Digger off-floor 누적 카운터. on_floor 시 0 reset, off-floor 시 +1.
# DIGGER_OFF_FLOOR_LIMIT 초과 시 _aborted + FallerState 직접 전이 (D11 void termination).
# basher 모드에서는 미사용 (off-floor 즉시 _aborted라 카운팅 불필요).
var _off_floor_frames: int = 0

func _init(work_type: String = "builder") -> void:
	_work_type = work_type

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	# has_candy / has_been_carrying 절대 변경 안 함 (Codex HIGH #4 가드).
	if _work_type == "builder":
		_enter_builder(a)
	elif _work_type == "blocker":
		_enter_blocker(a)
	elif _work_type == "sand_mound":
		_enter_sand_mound(a)
	elif _work_type == "bridge":
		_enter_bridge(a)
	elif _work_type == "basher":
		_enter_basher(a)
	elif _work_type == "digger":
		_enter_digger(a)
	elif _work_type == "cutter":
		_enter_cutter(a)
	else:
		_aborted = true

func _enter_builder(a: Ant) -> void:
	_remaining = TOTAL_TILES
	_tick_accum = 0.0
	_aborted = false
	a.velocity = Vector2.ZERO

func _enter_blocker(a: Ant) -> void:
	_aborted = false
	a.velocity = Vector2.ZERO
	a.set_blocker_active(true)

func _enter_sand_mound(a: Ant) -> void:
	_remaining = SAND_MOUND_MAX_HEIGHT
	_tick_accum = 0.0
	_aborted = false
	_ladder_root_done = false
	a.velocity = Vector2.ZERO

func _enter_bridge(a: Ant) -> void:
	_remaining = BRIDGE_MAX_LENGTH
	_tick_accum = 0.0
	_aborted = false
	_bridge_floor_grace_used = false
	a.velocity = Vector2.ZERO

func _enter_basher(a: Ant) -> void:
	_remaining = BASHER_MAX_CELLS
	_tick_accum = 0.0
	_aborted = false
	a.velocity = Vector2.ZERO

func _enter_digger(a: Ant) -> void:
	_remaining = DIGGER_MAX_CELLS
	_tick_accum = 0.0
	_aborted = false
	_off_floor_frames = 0
	a.velocity = Vector2.ZERO

func _enter_cutter(a: Ant) -> void:
	_remaining = CUTTER_MAX_CELLS
	_tick_accum = 0.0
	_aborted = false
	a.velocity = Vector2.ZERO

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	if _work_type == "blocker":
		_update_blocker(a, delta)
		return
	elif _work_type == "sand_mound":
		_update_sand_mound(a, delta)
		return
	elif _work_type == "bridge":
		_update_bridge(a, delta)
		return
	elif _work_type == "basher":
		_update_basher(a, delta)
		return
	elif _work_type == "digger":
		_update_digger(a, delta)
		return
	elif _work_type == "cutter":
		_update_cutter(a, delta)
		return

	# builder 분기 (기존 로직 유지, cell_size만 dynamic)
	if _aborted or _remaining <= 0:
		a.return_to_walking()
		return

	# 중력 + 바닥 유지 (placement 사이에 ant가 떠있는 시점에도 안정)
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()

	if a.is_on_wall():
		_aborted = true
		a.return_to_walking()
		return

	_tick_accum += delta
	while _tick_accum >= TICK_SECONDS and _remaining > 0 and not _aborted:
		_tick_accum -= TICK_SECONDS
		_place_one_tile(a)

	if _remaining <= 0 and not _aborted:
		a.return_to_walking()

func _update_blocker(a: Ant, delta: float) -> void:
	# 영구 정지. 절벽 끝에서만 Faller로 자연 해제.
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	if not a.is_on_floor():
		a.set_blocker_active(false)
		a.state_machine.change_state(FallerState.new())

func _update_sand_mound(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.return_to_walking()
		return
	# 정지 — 좌우 무이동. 중력은 적용(tile 사이 떠있을 때 대비).
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	_tick_accum += delta
	while _tick_accum >= SAND_MOUND_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= SAND_MOUND_TICK
		_place_sand_mound_tile(a)
	if _remaining <= 0 and not _aborted:
		a.return_to_walking()

func _update_bridge(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.return_to_walking()
		return
	# 정지 — velocity.x=0 유지, 중력만 적용.
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	# 벽 충돌 시 abort (builder 정책 답습).
	if a.is_on_wall():
		_aborted = true
		a.return_to_walking()
		return
	# v7 — floor-contact guard.
	# 첫 tile 전 off-floor는 1-frame grace만 허용하되 tile placement는 절대 수행하지 않는다.
	# tile 1개 이상 배치 후 off-floor이거나 grace 이후에도 off-floor이면 즉시 중단한다.
	# Grace는 ant가 다시 floor 위로 안착하면 reset되어 1-frame 물리 진동을 false abort에서 보호한다.
	if not a.is_on_floor():
		var placed_count: int = BRIDGE_MAX_LENGTH - _remaining
		if placed_count == 0 and not _bridge_floor_grace_used:
			_bridge_floor_grace_used = true
			return
		_aborted = true
		a.return_to_walking()
		return
	_bridge_floor_grace_used = false   # 안착 → grace 재충전
	_tick_accum += delta
	while _tick_accum >= BRIDGE_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= BRIDGE_TICK
		if _far_side_floor_reached(a):
			_aborted = true   # 정상 종료 (반대편 floor 도달)
			break
		_place_bridge_tile(a)
	if _aborted or _remaining <= 0:
		a.return_to_walking()

func exit() -> void:
	# blocker 정리 — Faller/Walker/Saved/Dead 어떤 경로든 BlockerHitbox 비활성. 멱등.
	if _work_type == "blocker":
		var a: Ant = ant as Ant
		if a != null:
			a.set_blocker_active(false)
	# sand_mound/bridge는 terminal cleanup 불필요 — Walker 복귀 시 자연 해제.

func _place_one_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	# 수평 다리 — ant 발 밑(한 칸 아래) 행에 forward로 12셀.
	var cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = cell + Vector2i(a.direction, 1)
	var ok: bool = terrain.add_tile(target, Terrain.DYNAMIC_TILE_STAIR, a.direction)
	if not ok:
		_aborted = true
		return
	# Phase 17 — Bridge/Water 정책 (D8). hazard 없는 stage는 no-op.
	terrain.deactivate_hazards_for_placement(target)
	a.global_position += Vector2(a.direction * cs, 0.0)
	_remaining -= 1

# biscuit-ladder 지형 통합 빌드 (2026-06-02, 구 sand_mound climb-over 폐기):
# - 위 칸이 비면: middle rung 배치 + 1칸 상승.
# - 위 칸이 채워짐:
#     · surface(노출 walkable top = 그 위 칸이 빈 셀 + 그 면이 reskin 가능한 정적 지형 Sprite)
#       → 갭 middle 메움 + 위 면 텍스처 top + 개미 그 위로 올라서고 종료.
#     · solid(위도 막힘) 또는 cap 불가(body_cell 점유·slope·plant·동적·미등록) → 아무 변경 없이 즉시 종료.
# - 빈 칸으로만 최대 SAND_MOUND_MAX_HEIGHT(5)칸 쌓고 종료(허공 캡 없음).
# - 발밑 지형 면 → root는 **최초 성공 commit(첫 rung/cap) 직후 1회**(_apply_ladder_root_once). 실패/즉시
#   abort 시도는 root를 남기지 않는다(모든 reskin/placement가 commit 경계 안).
func _place_sand_mound_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var above: Vector2i = body_cell + Vector2i(0, -1)
	if terrain.is_cell_occupied(above):
		# 위 칸 점유 → cap 또는 solid 종료. cap은 **atomic**: 모든 사전조건(노출 walkable top + body_cell
		# 비어 rung 배치 가능 + above가 cap 가능한 earth 면)을 부작용 없이 먼저 검사하고, 전부 통과할 때만
		# rung 배치·top reskin·root reskin·hazard 비활성·개미 이동을 한 묶음으로 수행한다. 하나라도 불충족이면
		# solid로 취급해 **아무것도 바꾸지 않고** 종료 — 반쪽 cap(개미만 텔레포트)·실패 시 root 잔존을 원천 차단.
		if _can_cap_ledge(terrain, body_cell):
			# 사전검사로 둘 다 성공이 보장됨(동기 tick 내 재진입 없음). 방어적으로 결과도 확인.
			var placed: bool = terrain.add_tile(body_cell, Terrain.DYNAMIC_TILE_SAND_MOUND)
			var capped: bool = terrain.reskin_cell_to_ladder(above, Terrain.LADDER_TIER_TOP)
			if placed and capped:
				terrain.deactivate_hazards_for_placement(body_cell)
				_apply_ladder_root_once(terrain, body_cell)
				a.global_position.y -= float(cs) * 2.0
		# solid(위도 막힘) 또는 cap 불가(body_cell 점유·slope·plant·동적·미등록) → 종료(아무 변경 없음).
		_aborted = true
		return
	# 빈 칸 → middle rung 배치 + 1칸 상승.
	var ok: bool = terrain.add_tile(body_cell, Terrain.DYNAMIC_TILE_SAND_MOUND)
	if not ok:
		_aborted = true
		return
	terrain.deactivate_hazards_for_placement(body_cell)
	_apply_ladder_root_once(terrain, body_cell)
	a.global_position.y -= float(cs)
	_remaining -= 1

# 사다리 최초 성공 commit(첫 rung 또는 cap) 직후 1회만, 그 시점 발밑(body_cell+(0,1)) 지형 면을 root로 reskin.
# (codex 2026-06-02 R4 MEDIUM) 즉시 abort한 실패 시도는 root를 남기지 않는다 — root reskin이 commit 경계 안에 있다.
# best-effort cosmetic: 발밑이 earth 정적 지형 면이 아니면 no-op(false)이지만 플래그는 세워 재시도하지 않는다.
func _apply_ladder_root_once(terrain: Terrain, body_cell: Vector2i) -> void:
	if _ladder_root_done:
		return
	terrain.reskin_cell_to_ladder(body_cell + Vector2i(0, 1), Terrain.LADDER_TIER_ROOT)
	_ladder_root_done = true

# biscuit-ladder cap(surface) 진입 가능 여부 — **부작용 없는** atomic 사전검사.
# true면 add_tile(body_cell)·reskin(above,TOP)이 모두 성공함이 보장되므로 cap을 한 묶음으로 commit할 수 있다.
# 조건: (1) above 점유(레지) (2) above 위는 빈 칸(노출 walkable top) (3) body_cell 비어 rung 배치 가능
#       (is_cell_occupied == add_tile reject 조건과 동일) (4) above가 cap 가능한 earth 정적 Sprite 면.
static func _can_cap_ledge(terrain: Terrain, body_cell: Vector2i) -> bool:
	var above: Vector2i = body_cell + Vector2i(0, -1)
	if not terrain.is_cell_occupied(above):
		return false
	if terrain.is_cell_occupied(above + Vector2i(0, -1)):
		return false   # 위도 막힘 = solid 벽
	if terrain.is_cell_occupied(body_cell):
		return false   # rung 놓을 자리 없음 → 반쪽 cap 방지
	# (codex 2026-06-02 R5/R6) cap commit이 입히는 시각 자산(rung MIDDLE + 레지 TOP) 텍스처가 둘 다
	# load 가능해야 atomic. 하나라도 누락이면 cap이 invisible rung/거짓 top으로 반쪽 commit되므로 진입 차단.
	# (root는 best-effort cosmetic이라 게이트 제외 — _apply_ladder_root_once 참조.)
	if not terrain.has_ladder_texture(Terrain.LADDER_TIER_MIDDLE):
		return false
	if not terrain.has_ladder_texture(Terrain.LADDER_TIER_TOP):
		return false
	return terrain.can_reskin_cell_to_ladder(above)

func _place_bridge_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	# Builder 패턴 답습 — (y-2.0)/cs로 ant 본체 cell, target = body_cell + (dir, +1) (floor row).
	# Bridge는 수평이라 ant.y는 불변 + ant.x += dir*cs로 새 floor 위로 한 칸 이동.
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = body_cell + Vector2i(a.direction, 1)
	var ok: bool = terrain.add_tile(target)
	if not ok:
		_aborted = true
		return
	# Phase 17 — Bridge/Water 정책 (D8). hazard 없는 stage는 no-op.
	terrain.deactivate_hazards_for_placement(target)
	a.global_position += Vector2(float(a.direction) * cs, 0.0)
	_remaining -= 1

func _far_side_floor_reached(a: Ant) -> bool:
	# ant 진행 방향 1 cell forward에서 아래로 ray cast.
	# Layer 1 mask는 Terrain 동적 tile + StageLayoutBuilder 정적 cell 모두 감지.
	# Terrain.has_tile만으로는 정적 cell을 못 보므로 ray 방식 필수.
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var space: PhysicsDirectSpaceState2D = a.get_world_2d().direct_space_state
	if space == null:
		return false
	var feet: Vector2 = a.global_position + Vector2(0, 2)
	var forward_target: Vector2 = feet + Vector2(float(a.direction) * (cs + 2), 0)
	var down_query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		forward_target,
		forward_target + Vector2(0, cs + 4),
		1   # Layer 1 (floor mask)
	)
	down_query.exclude = [a.get_rid()]
	var hit: Dictionary = space.intersect_ray(down_query)
	return not hit.is_empty()

func _find_terrain(a: Ant) -> Terrain:
	# Stage scene tree에서 가장 가까운 Terrain 노드 검색. ancestor 탐색.
	var n: Node = a.get_parent()
	while n != null:
		var t: Terrain = n.get_node_or_null("Terrain") as Terrain
		if t != null:
			return t
		if n is Terrain:
			return n as Terrain
		n = n.get_parent()
	return null

# Phase 18 — Basher 수평 굴착. ant 진행 방향으로 **2칸 높이 통로**(body row + 위 row)를 BASHER_MAX_CELLS까지
# tick 단위로 뚫는다(2026-06-02 확장). 매 tick: body row 전방 cell 제거(필수) + 위 row 전방 cell 제거(best-effort,
# earth일 때만) + 발밑 floor 면을 basher root, 통로 위 ceiling 면을 basher top으로 reskin(best-effort, 시각만).
# 그 뒤 ant.x += dir*cs로 1 cell 전진. body row forward에 earth 없으면(wall 끝) 자연 종료.
# off-floor 시 즉시 _aborted → Faller (절벽 끝에서 활성화한 경우).
func _update_basher(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.return_to_walking()
		return
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	if not a.is_on_floor():
		_aborted = true
		a.state_machine.change_state(FallerState.new())
		return
	_tick_accum += delta
	while _tick_accum >= BASHER_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= BASHER_TICK
		if not _basher_forward_has_earth(a):
			_aborted = true
			break
		_destroy_basher_cell(a)
	if _aborted or _remaining <= 0:
		a.return_to_walking()

# Phase 18 — Digger 수직 굴착. ant 바로 아래 floor row cell을 DIGGER_MAX_CELLS까지 tick 단위 제거.
# ant 위치는 갱신 안 함 — 다음 physics tick에 is_on_floor=false → 중력으로 자연 낙하.
# off-floor 중에도 WorkerState 유지 (vertical tunnel 연속 굴착, v4 Option A). DIGGER_OFF_FLOOR_LIMIT
# 초과 시 _aborted + FallerState 직접 전이 (D11 void termination 안전망).
func _update_digger(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.return_to_walking()
		return
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	if not a.is_on_floor():
		_off_floor_frames += 1
		if _off_floor_frames > DIGGER_OFF_FLOOR_LIMIT:
			# D11 void termination — Walker 우회하지 않고 FallerState 직접 전이.
			_aborted = true
			a.state_machine.change_state(FallerState.new())
		return
	# on_floor — counter reset 후 tick 소비.
	_off_floor_frames = 0
	_tick_accum += delta
	while _tick_accum >= DIGGER_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= DIGGER_TICK
		if not _digger_below_has_earth(a):
			_aborted = true
			break
		_destroy_digger_cell(a)
	if _aborted or _remaining <= 0:
		a.return_to_walking()

# 전방 열(body_cell + (dir, ·)) 기준 2칸 통로 굴착 + 단면 reskin (2026-06-02):
#   R-2 ceiling: basher top reskin (통로 위 지형 면 — 시각만, best-effort)
#   R-1 위:      제거 (best-effort — earth일 때만, 공기/비-earth면 skip)
#   R   body:    제거 (필수 — 실패 시 abort, 통로 벽 종료)
#   R+1 floor:   basher root reskin (개미가 밟을 발밑 면 — 시각만, best-effort)
# body row 제거만이 진행/종료를 결정한다(_basher_forward_has_earth도 body row 기준). 나머지는 best-effort라
# 1칸 천장/허공 통로에서도 자연스럽게 동작한다. reskin은 충돌/점유/cell_kind 불변(텍스처만) — abort 후 잔존 없음.
func _destroy_basher_cell(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	# Builder 패턴 답습 — (y - 2.0)/cs로 ant 본체 cell.
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	# (1) body row 전방 — 필수. _update_basher가 직전에 forward earth를 확인했으므로 정상 true.
	var body_target: Vector2i = body_cell + Vector2i(a.direction, 0)
	if not terrain.destroy_tile_at(body_target, ["earth"]):
		_aborted = true
		return
	# (2) 위 row 전방 — 2칸 높이 통로. best-effort(earth면 제거, 공기/비-earth면 no-op, abort 안 함).
	terrain.destroy_tile_at(body_cell + Vector2i(a.direction, -1), ["earth"])
	# (3) 발밑 floor → root, 통로 위 ceiling → top. best-effort 텍스처 교체(적격 아니면 no-op).
	terrain.reskin_cell_to_basher(body_cell + Vector2i(a.direction, 1), Terrain.BASHER_FACE_ROOT)
	terrain.reskin_cell_to_basher(body_cell + Vector2i(a.direction, -2), Terrain.BASHER_FACE_TOP)
	# 1 cell 전진. Vector2 더하기로 Builder/Bridge/Sand-mound 스타일 통일.
	a.global_position += Vector2(float(a.direction) * cs, 0.0)
	_remaining -= 1

func _destroy_digger_cell(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	# floor row (ant 바로 아래).
	var target: Vector2i = body_cell + Vector2i(0, 1)
	var ok: bool = terrain.destroy_tile_at(target, ["earth"])
	if not ok:
		_aborted = true
		return
	# ant 위치는 무변경 — 다음 physics tick에 is_on_floor=false → 자연 낙하.
	_remaining -= 1

func _basher_forward_has_earth(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	return terrain.get_cell_kind(body_cell + Vector2i(a.direction, 0)) == "earth"

func _digger_below_has_earth(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	return terrain.get_cell_kind(body_cell + Vector2i(0, 1)) == "earth"

# Phase 19 — Cutter 수평 절단. Basher 구조 답습. forward body row cell이 "plant" kind일 때만 destroy.
# off-floor 시 즉시 _aborted → Faller (절벽 끝에서 활성화 안전망, Basher와 동일).
func _update_cutter(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.return_to_walking()
		return
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	if not a.is_on_floor():
		_aborted = true
		a.state_machine.change_state(FallerState.new())
		return
	_tick_accum += delta
	while _tick_accum >= CUTTER_TICK and _remaining > 0 and not _aborted:
		_tick_accum -= CUTTER_TICK
		if not _cutter_forward_has_plant(a):
			_aborted = true
			break
		_destroy_cutter_cell(a)
	if _aborted or _remaining <= 0:
		a.return_to_walking()

func _destroy_cutter_cell(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	var target: Vector2i = body_cell + Vector2i(a.direction, 0)
	var ok: bool = terrain.destroy_tile_at(target, ["plant"])
	if not ok:
		_aborted = true
		return
	a.global_position += Vector2(float(a.direction) * cs, 0.0)
	_remaining -= 1

func _cutter_forward_has_plant(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	return terrain.get_cell_kind(body_cell + Vector2i(a.direction, 0)) == "plant"
