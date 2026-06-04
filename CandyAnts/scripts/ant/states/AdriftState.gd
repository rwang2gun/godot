class_name AdriftState extends AntState

# 물 표류 상태 (2026-06-04) — WaterHazard 진입 개미의 종착 상태.
# 기존 LostState(즉사·queue_free) 대신: 보유 사탕은 동일하게 손실 정산하되 개미는 제거하지 않고
# 수면에 떠서(swim) 표류시킨다. terminal — Ant.is_alive()=false 로 분류해 스킬·추가 hazard·
# out-of-bounds 처리를 일괄 차단한다.
#
# 표류 이동(2026-06-04 개선): 진입 셀에서 좌우로 활성 물 셀이 이어지는 끝(span)까지 왕복 표류한다.
# 연속된 수면 타일이면 그 구간 전체를 가로지르고, 단일 타일이면 제자리에서 출렁인다(span 폭 0).
# 수면 정렬: swim 프레임(308×261)은 캔버스 하단 정렬이라 origin을 수면 셀 상단보다 SURFACE_SINK 만큼
# 내려 캐릭터 하반신이 수면에 잠기도록(살짝 떠 있던 문제 교정) 한다.
#
# 스테이지 종료 회계: adrift 개미는 StageRunner._living_ant_count 에서 제외되어 "남은 개미 0"
# (no_more_ants) 판정을 막지 않는다 — 스테이지는 정상적으로 종료되고 그 시점까지 개미가 떠 있다.

const DRIFT_SPEED: float = 14.0      # 수평 표류 속도(px/s)
const BOB_AMPLITUDE: float = 3.0     # 수면 출렁임 진폭(px)
const BOB_SPEED: float = 2.2         # 출렁임 각속도(rad/s)
# 수면선 대비 origin 침하량(px). swim 스프라이트(scale 1.25) 기준 하반신이 잠기도록 튜닝.
# 값↑ = 더 잠김, 값↓ = 더 떠오름. (스케일을 바꾸면 함께 조정.)
const SURFACE_SINK: float = 28.0

var _fallback_surface_y: float = NAN
var _terrain: Terrain = null
var _cs: float = 48.0
var _surface_row: int = 0
var _anchor_y: float = NAN   # 표류 기준 origin 높이(출렁임의 중심).
var _min_x: float = 0.0
var _max_x: float = 0.0
var _can_drift: bool = false
var _bob_t: float = 0.0
var _drift_dir: int = 1

func _init(fallback_surface_y: float = NAN) -> void:
	# fallback_surface_y = 진입 물 셀 상단 y(WaterHazard 전달). terrain 미발견 시에만 사용.
	_fallback_surface_y = fallback_surface_y

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	if a.has_candy:
		# 회계는 LostState/DeadState와 동일 — 운반 조각 1개 손실 정산(ScoreSystem._on_lost가 in_transit -1).
		EventBus.sfx_request.emit(&"candy_lost")
		EventBus.candy_piece_lost.emit(a)
		a.has_candy = false
	# Blocker hitbox 정리 — call_deferred(Area2D 콜백 안전, 멱등).
	a.call_deferred("set_blocker_active", false)
	a.velocity = Vector2.ZERO
	_drift_dir = a.direction if a.direction != 0 else 1
	_resolve_surface(a)

func _resolve_surface(a: Ant) -> void:
	_terrain = a._find_terrain()
	if _terrain == null:
		# terrain 미발견 — 진입 지점에서 부유(드리프트 없음).
		var base_y: float = _fallback_surface_y if not is_nan(_fallback_surface_y) else a.global_position.y
		_anchor_y = base_y + SURFACE_SINK
		_can_drift = false
		return
	_cs = float(_terrain.cell_size)
	var col: int = floori(a.global_position.x / _cs)
	var row: int = floori(a.global_position.y / _cs)
	# 진입 셀이 물이 아니면(살짝 위에서 진입) 아래로 탐색해 물 셀을 찾는다.
	var guard: int = 0
	while not _terrain.is_active_water_cell(Vector2i(col, row)) and guard < 6:
		row += 1
		guard += 1
	if not _terrain.is_active_water_cell(Vector2i(col, row)):
		# 물 셀 미발견 — fallback 부유.
		var base_y2: float = _fallback_surface_y if not is_nan(_fallback_surface_y) else a.global_position.y
		_anchor_y = base_y2 + SURFACE_SINK
		_can_drift = false
		return
	# 최상단(수면) 행으로 상승.
	while _terrain.is_active_water_cell(Vector2i(col, row - 1)):
		row -= 1
	_surface_row = row
	_anchor_y = float(row) * _cs + SURFACE_SINK
	# 수면 연속 구간(span) — 좌우로 활성 물 셀이 이어지는 끝까지.
	var min_col: int = col
	while _terrain.is_active_water_cell(Vector2i(min_col - 1, _surface_row)):
		min_col -= 1
	var max_col: int = col
	while _terrain.is_active_water_cell(Vector2i(max_col + 1, _surface_row)):
		max_col += 1
	# 개미 중심이 양끝 물 셀의 중심 사이를 왕복하도록 경계 설정.
	_min_x = (float(min_col) + 0.5) * _cs
	_max_x = (float(max_col) + 0.5) * _cs
	_can_drift = (_max_x - _min_x) >= 1.0
	a.global_position.x = clamp(a.global_position.x, _min_x, _max_x)

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	if _can_drift:
		# 수면 span 안에서 좌우 왕복 — 끝에 닿으면 방향 반전(연속 수면 타일이면 그 구간을 가로지른다).
		var nx: float = a.global_position.x + DRIFT_SPEED * float(_drift_dir) * delta
		if nx <= _min_x:
			nx = _min_x
			_drift_dir = 1
			a.direction = 1
		elif nx >= _max_x:
			nx = _max_x
			_drift_dir = -1
			a.direction = -1
		a.global_position.x = nx
	# 수면 출렁임(시각). move_and_slide 미사용 — 순수 kinematic 부유.
	_bob_t += delta * BOB_SPEED
	if not is_nan(_anchor_y):
		a.global_position.y = _anchor_y + sin(_bob_t) * BOB_AMPLITUDE
	a.velocity = Vector2.ZERO
