class_name AntSpawner extends Node

signal spawn_finished

@export var ant_scene: PackedScene = null
@export var spawn_position: Vector2 = Vector2.ZERO
@export var total: int = 10
@export var release_rate: int = 50

var _spawned: int = 0
var _timer: Timer = null
var _spawn_parent: Node = null

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
	_timer.start()

func set_release_rate(new_rate: int) -> void:
	release_rate = clampi(new_rate, 1, 99)
	if _timer != null:
		_timer.wait_time = _interval_for(release_rate)
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
	_spawn_parent.add_child(ant)
	_spawned += 1
