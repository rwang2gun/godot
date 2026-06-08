class_name WorkerState extends AntState

# Phase 16 v4: const CELL_SIZE 삭제 — placement 함수는 terrain.cell_size를 dynamic read.
# Builder 기존 분기도 terrain.cell_size 사용 → Stage 02/03(terrain.cell_size=16 default)
# 회귀 0건. dev_*_layout 사용 stage(cell_size=32)는 새 단위로 placement.

const TICK_SECONDS: float = 0.2
# 계단(builder) 최대 스텝 수 — up-first 1칸 + 대각 (N-1)칸. 다른 건설 스킬과 동일하게 5칸 캡
# (2026-06-04, 구 12). (Phase 3: builder는 무장③이라 PlacementPreview 탭-타임 ghost 폐지 → 이중 SoT 해소.)
const BUILDER_MAX_STEPS: int = 5

const SAND_MOUND_TICK: float = 0.25
const SAND_MOUND_MAX_HEIGHT: int = 5

const BRIDGE_TICK: float = 0.20
# 다리 최대 길이(칸) — 5칸 캡 (2026-06-04, 구 8). (Phase 3: bridge는 무장③이라 PlacementPreview 탭-타임 ghost 폐지 → 이중 SoT 해소.)
const BRIDGE_MAX_LENGTH: int = 5

# Phase 18 — Basher(수평 굴착) + Digger(수직 굴착) 상수.
# DIGGER_FREEFALL_CELLS (2026-06-06): 굴착 사이 정상 1칸 드롭(연속 터널)과 갱도가 빈 공간으로 뚫린 뒤의
#   자유낙하를 가르는 임계(칸). 1칸 인접 드롭은 WorkerState 유지(연속 굴착), 임계 초과 낙하는 자유낙하로 보고
#   FallerState로 이양해 기절 판정을 받게 한다(구 DIGGER_OFF_FLOOR_LIMIT void timeout + 무조건 WorkerState 유지 폐기).
const BASHER_TICK: float = 0.18
# 전방 굴착 최대 칸수 — 5칸 캡 (2026-06-05 요청, 구 12). 무장 basher가 흙 벽 도달 시 전방 5칸까지 뚫고 해제.
# 벽이 5칸보다 얇으면 공기 만나 자연 종료(_basher_forward_has_earth=false). 기존 정본 스테이지 벽은 모두 ≤5칸
# (S7=4, S9=2)이라 회귀 없음.
const BASHER_MAX_CELLS: int = 5
const DIGGER_TICK: float = 0.20
const DIGGER_MAX_CELLS: int = 12
# 굴착 사이 정상 1칸 드롭과 빈 공간 자유낙하를 가르는 임계(칸). 1.5칸 = 인접 굴착 드롭(1칸)은 안 넘고,
# 갱도가 뚫린 자유낙하만 초과 → FallerState 이양(앵커 넘겨 기절 거리 정확 측정).
const DIGGER_FREEFALL_CELLS: float = 1.5

# Cutter 전방 열 절단 (2026-06-05 개정). Basher(전방 흙 5칸 굴착)의 식물 버전 — 매 tick 전방 plant 1열
# (그 열의 연속 세로 덩쿨, Terrain.shatter_plant_column)을 제거하고 1 cell 전진하며, CUTTER_MAX_COLUMNS까지
# 전방으로 march한다. 구 flood-fill 일괄 절단(4-방향 연결 클러스터 전체, 두께 무제한)을 폐기 — "1열씩 최대
# 5열". 전방 열에 plant가 없으면(벽 끝/공기/earth) 자연 종료. CUTTER_TICK = 열당 처리 간격(첫 절단 전 wind-up).
const CUTTER_TICK: float = 0.18
# 전방 절단 최대 열수 — 5열 캡 (basher BASHER_MAX_CELLS와 동형). 덤불이 5열보다 두꺼우면 앞 5열만 열고 종료.
const CUTTER_MAX_COLUMNS: int = 5

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
# Phase 18 → 2026-06-06 개정 — Digger 자유낙하 감지용 off-floor 앵커.
# off-floor 진입 첫 frame에 그 시점 y를 _dig_fall_anchor_y에 기록하고, 이후 낙하 거리가 DIGGER_FREEFALL_CELLS를
# 넘으면 갱도가 빈 공간으로 뚫린 자유낙하로 보고 FallerState로 이양한다(앵커를 넘겨 기절 거리 정확 측정).
# on_floor 복귀 시 _dig_off_floor=false로 리셋해 다음 off-floor cycle에 앵커를 다시 잡는다.
# basher 모드에서는 미사용 (off-floor 즉시 _aborted라 앵커 불필요).
var _dig_off_floor: bool = false
var _dig_fall_anchor_y: float = 0.0
# Builder up-first (2026-06-03): 첫 계단 타일은 절벽 끝 위에 수직 배치(이후 대각). 절벽에 flush하게
# 시작해 floating 갭 제거 + 목표 플랫폼과 같은 높이로 끝나도록 한다.
var _builder_first_tile: bool = false

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
	_remaining = BUILDER_MAX_STEPS
	_tick_accum = 0.0
	_aborted = false
	_builder_first_tile = true
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
	_dig_off_floor = false
	a.velocity = Vector2.ZERO

func _enter_cutter(a: Ant) -> void:
	_remaining = CUTTER_MAX_COLUMNS
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

# builder 대각선 상승 계단 (2026-06-02 정합성 개정 + 2026-06-03 up-first).
# 절벽 끝에서 "위 먼저" 시작: 첫 타일은 현재 body cell(절벽 끝 바로 위)에 수직 배치하고 한 칸 위로 올라선다
# → 계단이 절벽에 flush하게 시작(구 동작은 첫 타일이 절벽 코너에서 대각 우상단으로 떨어져 floating).
# 이후 타일은 전방+위 대각 상승: 새 발판 target = body_cell + (dir, 0) → 다음 stand 위치(body+(dir,-1))의 새 floor.
# 정지: (a) 전방-아래가 지형이고 전방이 비면 = 이미 올라설 평지(목표 플랫폼)에 같은 높이로 도달 → 계단 종료
#       (up-first로 마지막 계단이 플랫폼과 같은 높이가 되어 자연스럽게 walk-onto). (b) 올라설 자리(dest_body)
#       막힘 = 레지/벽/천장. (c) target 점유 = add_tile 실패. 어느 쪽이든 _aborted=정상 종료 → return_to_walking.
func _place_one_tile(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	# (a) 전방-아래 지형 + 전방 빈칸 → 같은 높이의 평지에 도달, 계단 종료(걷기 복귀). up-first가 마지막
	#     계단을 목표 플랫폼과 같은 높이로 맞추므로 여기서 멈춰 overshoot(허공으로 계속 쌓기)를 막는다.
	if terrain.is_cell_occupied(body_cell + Vector2i(a.direction, 1)) \
			and not terrain.is_cell_occupied(body_cell + Vector2i(a.direction, 0)):
		_aborted = true
		return
	# up-first: 첫 타일은 절벽 끝 위(현재 body cell)에 수직 배치 → 한 칸 위로만 상승(전방 이동 없음).
	if _builder_first_tile:
		_builder_first_tile = false
		if not terrain.add_tile(body_cell, Terrain.DYNAMIC_TILE_STAIR, a.direction):
			_aborted = true
			return
		terrain.deactivate_hazards_for_placement(body_cell)
		_place_stair_fill_below(terrain, body_cell, a.direction)
		a.global_position += Vector2(0.0, float(-cs))
		_remaining -= 1
		EventBus.sfx_request.emit(&"skill_build")
		return
	# 대각 상승 (전방 1칸 + 위 1칸).
	var target: Vector2i = body_cell + Vector2i(a.direction, 0)
	var dest_body: Vector2i = body_cell + Vector2i(a.direction, -1)
	if terrain.is_cell_occupied(dest_body):
		_aborted = true
		return
	var ok: bool = terrain.add_tile(target, Terrain.DYNAMIC_TILE_STAIR, a.direction)
	if not ok:
		_aborted = true
		return
	# Phase 17 — Bridge/Water 정책 (D8). hazard 없는 stage는 no-op.
	terrain.deactivate_hazards_for_placement(target)
	_place_stair_fill_below(terrain, target, a.direction)
	a.global_position += Vector2(float(a.direction) * cs, float(-cs))
	_remaining -= 1
	EventBus.sfx_request.emit(&"skill_build")

# 디아그램(2026-06-03): stair01(표면) 바로 아래 칸이 비어 있으면 stair02(받침)를 채운다. 점유 시 no-op.
# 받침은 시각/지지용 — 등반 대상(_stair_cells)이 아니다(STAIR_FILL). 실패해도 계단 자체엔 영향 없음.
func _place_stair_fill_below(terrain: Terrain, stair_cell: Vector2i, dir: int) -> void:
	var below: Vector2i = stair_cell + Vector2i(0, 1)
	if terrain.is_cell_occupied(below):
		return
	terrain.add_tile(below, Terrain.DYNAMIC_TILE_STAIR_FILL, dir)
	terrain.deactivate_hazards_for_placement(below)

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
				EventBus.sfx_request.emit(&"skill_build")
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
	EventBus.sfx_request.emit(&"skill_build")

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
	EventBus.sfx_request.emit(&"skill_build")

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

# Phase 18 → 2026-06-06 — Digger 수직 굴착. ant 바로 아래 floor row cell을 DIGGER_MAX_CELLS까지 tick 단위 제거.
# ant 위치는 갱신 안 함 — 다음 physics tick에 is_on_floor=false → 중력으로 자연 낙하.
# 굴착 사이 1칸 드롭(연속 터널)은 WorkerState 유지하지만, 갱도가 빈 공간으로 뚫려 DIGGER_FREEFALL_CELLS를
# 넘는 자유낙하가 시작되면 FallerState로 이양한다(굴착 모션 자유낙하가 기절 판정을 건너뛰던 버그 수정 —
# 구 v4 Option A의 무조건 WorkerState 유지 + DIGGER_OFF_FLOOR_LIMIT void timeout 폐기).
func _update_digger(a: Ant, delta: float) -> void:
	if _aborted or _remaining <= 0:
		a.return_to_walking()
		return
	a.velocity.y += a.gravity * delta
	a.velocity.x = 0.0
	a.move_and_slide()
	if not a.is_on_floor():
		# off-floor 진입 첫 frame에 앵커 기록 — 굴착 사이 1칸 드롭(연속 터널)의 기준점.
		if not _dig_off_floor:
			_dig_off_floor = true
			_dig_fall_anchor_y = a.global_position.y
		# 앵커 대비 DIGGER_FREEFALL_CELLS(1.5칸)를 넘게 떨어지면 갱도가 빈 공간으로 뚫린 자유낙하 → FallerState 이양.
		# 앵커를 넘겨 이미 떨어진 거리까지 포함해 기절 거리를 정확히 측정한다. 1칸 이하 인접 드롭은 임계 미달 →
		# WorkerState 유지로 연속 굴착(다음 earth 셀에 안착 후 tick 재개).
		var cs: int = _digger_cell_size(a)
		if a.global_position.y - _dig_fall_anchor_y > float(cs) * DIGGER_FREEFALL_CELLS:
			_aborted = true
			a.state_machine.change_state(FallerState.new(_dig_fall_anchor_y))
		return
	# on_floor — 앵커 리셋 후 tick 소비.
	_dig_off_floor = false
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
	EventBus.sfx_request.emit(&"skill_dig")

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
	EventBus.sfx_request.emit(&"skill_dig")

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

# Digger 자유낙하 임계 계산용 cell_size — terrain 부재 시 48 기본(다른 placement helper와 동일 fallback).
func _digger_cell_size(a: Ant) -> int:
	var terrain: Terrain = _find_terrain(a)
	return terrain.cell_size if terrain != null else 48

# Cutter 전방 열 절단 march (2026-06-05 개정, Basher 동형). 매 tick 전방 plant 1열(세로 연속 덩쿨)을 제거하고
# 1 cell 전진하며 CUTTER_MAX_COLUMNS까지 나아간다. 전방 열에 plant 없으면(벽 끝/공기/earth) 자연 종료 → Walker.
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
		_cut_cutter_column(a)
	if _aborted or _remaining <= 0:
		a.return_to_walking()

# 전방 plant 1열(세로 연속 덩쿨)을 제거하고 basher와 동일하게 1 cell 전진. _update_cutter가 직전에 전방
# plant를 확인했으므로 정상 경로에선 shatter가 1개 이상 제거한다(공기열은 상위에서 이미 abort).
func _cut_cutter_column(a: Ant) -> void:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		_aborted = true
		return
	var cs: int = terrain.cell_size
	terrain.shatter_plant_column(_cutter_forward_cell(a, terrain))
	a.global_position += Vector2(float(a.direction) * cs, 0.0)
	_remaining -= 1
	EventBus.sfx_request.emit(&"skill_dig")

func _cutter_forward_cell(a: Ant, terrain: Terrain) -> Vector2i:
	var cs: int = terrain.cell_size
	var body_cell: Vector2i = Vector2i(
		int(floor(a.global_position.x / cs)),
		int(floor((a.global_position.y - 2.0) / cs))
	)
	return body_cell + Vector2i(a.direction, 0)

func _cutter_forward_has_plant(a: Ant) -> bool:
	var terrain: Terrain = _find_terrain(a)
	if terrain == null:
		return false
	return terrain.get_cell_kind(_cutter_forward_cell(a, terrain)) == "plant"
