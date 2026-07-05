class_name AntSpawner extends Node

signal spawn_finished

@export var ant_scene: PackedScene = null
@export var spawn_position: Vector2 = Vector2.ZERO
@export var total: int = 10
@export var release_rate: int = 50
@export var spawn_direction: int = 1
@export var spawn_direction_alternate: bool = false

var _spawned: int = 0
var _timer: Timer = null
var _spawn_parent: Node = null

# 결정론 모드 스폰 — 벽시계 Timer 대신 물리-프레임 게이팅. _det_active는 start() 시점에 SimConfig를
# 읽어 고정(스테이지 중 모드 전환 없음).
# 드리프트 0 (codex R1-HIGH): 정수 프레임 간격을 누적하지 않고 **분수-초 절대 데드라인**(_next_spawn_elapsed_s)을
# 누적한다. 발화는 "경과초(=정수프레임/fps) ≥ 데드라인초"일 때 = Timer "누적 경과 ≥ wait_time" 의미와 일치
# (early-fire 0, 누적오차 0). 비정수 interval(예: release_rate=30 → 1.4229s)에서도 N번째 스폰이 정확히 Σinterval.
var _det_active: bool = false
var _start_frame: int = 0
var _next_spawn_elapsed_s: float = 0.0

func _ready() -> void:
	_ensure_timer()

func _ensure_timer() -> void:
	if _timer != null:
		return
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = _interval_for(release_rate)
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)

func start(parent: Node) -> void:
	_ensure_timer()
	_spawn_parent = parent
	_spawned = 0
	if total <= 0 or ant_scene == null:
		spawn_finished.emit()
		return
	# 결정론 모드: Timer 대신 물리-프레임 게이팅. Timer.start()와 동일하게 *interval 후* 첫 스폰
	# (one_shot=false Timer는 즉시가 아니라 wait_time 경과 후 첫 timeout). 모드는 start 시점에 고정.
	_det_active = SimConfig.deterministic
	if _det_active:
		_start_frame = Engine.get_physics_frames()
		_next_spawn_elapsed_s = _interval_for(release_rate)
		return
	_timer.start()

func _physics_process(_delta: float) -> void:
	if not _det_active:
		return
	# Timer._on_timeout 등가 — "경과초 ≥ 다음 데드라인초"일 때 스폰. 데드라인은 분수-초 절대 누적이라
	# 드리프트가 쌓이지 않는다(R1-HIGH). 다음 데드라인은 *현재* release_rate의 interval을 더해 갱신
	# (rate 변경은 다음 사이클부터 반영 = Timer.wait_time 변경 의미와 동일).
	var elapsed_s: float = float(Engine.get_physics_frames() - _start_frame) / float(Engine.physics_ticks_per_second)
	while elapsed_s >= _next_spawn_elapsed_s:
		if _spawned >= total:
			_det_active = false
			spawn_finished.emit()
			return
		_spawn_one()
		_next_spawn_elapsed_s += _interval_for(release_rate)

func set_release_rate(new_rate: int) -> void:
	release_rate = clampi(new_rate, 1, 99)
	if _timer != null:
		_timer.wait_time = _interval_for(release_rate)
	# 결정론 모드: 다음 데드라인 갱신 시 _physics_process가 현재 release_rate를 직접 읽으므로 별도 캐시 불필요.
	EventBus.release_rate_changed.emit(release_rate)

func _interval_for(rate: int) -> float:
	var r: float = clampf(float(rate), 1.0, 99.0)
	return lerpf(2.0, 0.05, (r - 1.0) / 98.0)

func _on_timeout() -> void:
	if _spawned >= total:
		_timer.stop()
		spawn_finished.emit()
		return
	_spawn_one()

func _spawn_one() -> void:
	if ant_scene == null or _spawn_parent == null:
		push_error("[AntSpawner] _spawn_one missing ant_scene or _spawn_parent")
		return
	var ant: Ant = ant_scene.instantiate() as Ant
	if ant == null:
		push_error("[AntSpawner] ant_scene did not instantiate as Ant")
		return
	ant.global_position = spawn_position
	# Codex MEDIUM 대응 — zero-based index 사용. _spawned 증가는 add_child 후.
	var spawn_index: int = _spawned
	var dir: int = spawn_direction
	if spawn_direction_alternate and (spawn_index % 2 == 1):
		dir = -spawn_direction
	ant.direction = dir
	ant.spawn_index = spawn_index
	_spawn_parent.add_child(ant)
	_spawned += 1
