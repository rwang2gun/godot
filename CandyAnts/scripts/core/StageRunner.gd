class_name StageRunner extends Node

@export var stage_data: StageData = null
@export var candy_path: NodePath
@export var home_path: NodePath
@export var spawner_path: NodePath
@export var hud_path: NodePath
@export var ant_scene: PackedScene = null
@export var spawn_parent_path: NodePath

var score_system: ScoreSystem = null

var _candy: Candy = null
var _home: Home = null
var _spawner: AntSpawner = null
var _hud: Node = null
var _spawn_parent: Node = null

var _time_left: float = 0.0
var _completed: bool = false

func _ready() -> void:
	if stage_data == null:
		push_error("[StageRunner] stage_data is null")
		return

	_candy = get_node_or_null(candy_path) as Candy
	_home = get_node_or_null(home_path) as Home
	_spawner = get_node_or_null(spawner_path) as AntSpawner
	_hud = get_node_or_null(hud_path)
	_spawn_parent = get_node_or_null(spawn_parent_path)
	if _spawn_parent == null:
		_spawn_parent = self

	# SkillRegistry 검증
	var errors: Array[String] = SkillRegistry.validate_stage(stage_data)
	if not errors.is_empty():
		push_error("[StageRunner] SkillRegistry errors: %s" % str(errors))

	# Candy 초기화
	if _candy != null:
		_candy.hp = stage_data.candy_hp

	# ScoreSystem
	score_system = ScoreSystem.new()
	score_system.start(stage_data.candy_hp)

	# Spawner 설정
	if _spawner != null:
		if _spawner.ant_scene == null:
			_spawner.ant_scene = ant_scene
		_spawner.total = stage_data.total_ants
		_spawner.release_rate = stage_data.release_rate_initial
		if _home != null and _spawner.spawn_position == Vector2.ZERO:
			_spawner.spawn_position = _home.get_spawn_position()
		_spawner.start(_spawn_parent)

	_time_left = stage_data.time_limit_seconds
	_completed = false

	EventBus.stage_cleared.connect(_on_stage_cleared)
	EventBus.stage_failed.connect(_on_stage_failed)

	print("[StageRunner] starting Stage ", stage_data.id, " total=", stage_data.total_ants, " hp=", stage_data.candy_hp)

func _process(delta: float) -> void:
	if _completed or stage_data == null:
		return

	_time_left = max(0.0, _time_left - delta)
	if _hud != null and _hud.has_method("update_time"):
		_hud.update_time(_time_left)

	var candy_hp: int = _candy.hp if _candy != null else 0
	if score_system.is_cleared(candy_hp):
		_completed = true
		EventBus.stage_cleared.emit(score_system.score())
		return

	if _time_left <= 0.0:
		_completed = true
		EventBus.stage_failed.emit("time_out")

func _on_stage_cleared(score: float) -> void:
	print("[StageRunner] cleared score=", score)
	_show_dialog("Stage Cleared!  Score: %d%%" % int(round(score * 100.0)))

func _on_stage_failed(reason: String) -> void:
	print("[StageRunner] failed reason=", reason)
	_show_dialog("Stage Failed (%s)  Score: %d%%" % [reason, int(round(score_system.score() * 100.0))])

func _show_dialog(text: String) -> void:
	if _hud != null and _hud.has_method("show_dialog"):
		_hud.show_dialog(text)
