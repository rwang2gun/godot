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
# 읽어 고정(스테이지 중 모드 전환 없음). interval/다음 스폰 프레임을 _physics_process가 소비.
var _det_active: bool = false
var _interval_frames: int = 0
var _next_spawn_frame: int = 0

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
		_interval_frames = SimConfig.seconds_to_frames(_interval_for(release_rate))
		_next_spawn_frame = Engine.get_physics_frames() + _interval_frames
		return
	_timer.start()

func _physics_process(_delta: float) -> void:
	if not _det_active:
		return
	# Timer._on_timeout 등가 — 데드라인 도달 시 스폰. interval만큼씩 다음 프레임 갱신(드리프트 없는 누적).
	while Engine.get_physics_frames() >= _next_spawn_frame:
		if _spawned >= total:
			_det_active = false
			spawn_finished.emit()
			return
		_spawn_one()
		_next_spawn_frame += max(1, _interval_frames)

func set_release_rate(new_rate: int) -> void:
	release_rate = clampi(new_rate, 1, 99)
	if _timer != null:
		_timer.wait_time = _interval_for(release_rate)
	# 결정론 모드 활성 중 rate 변경 시 interval_frames 갱신. 다음 스폰 데드라인은 차기 _physics_process가 새 간격으로.
	if _det_active:
		_interval_frames = SimConfig.seconds_to_frames(_interval_for(release_rate))
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
