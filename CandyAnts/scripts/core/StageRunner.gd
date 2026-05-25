class_name StageRunner extends Node

const GameAction := preload("res://scripts/input/GameAction.gd")
const RR_STEP: int = 5

@export var stage_data: StageData = null
@export var candy_path: NodePath
@export var home_path: NodePath
@export var spawner_path: NodePath
@export var hud_path: NodePath
@export var toolbar_path: NodePath
@export var ant_scene: PackedScene = null
@export var spawn_parent_path: NodePath

var score_system: ScoreSystem = null

var _candy: Candy = null
var _home: Home = null
var _spawner: AntSpawner = null
var _hud: Node = null
var _toolbar: Node = null
var _spawn_parent: Node = null

var _time_left: float = 0.0
var _completed: bool = false
var _spawner_finished: bool = false

func _ready() -> void:
	if stage_data == null:
		push_error("[StageRunner] stage_data is null")
		return

	_candy = get_node_or_null(candy_path) as Candy
	_home = get_node_or_null(home_path) as Home
	_spawner = get_node_or_null(spawner_path) as AntSpawner
	_hud = get_node_or_null(hud_path)
	_toolbar = get_node_or_null(toolbar_path)
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
	# CRITICAL ORDERING: spawn_finished connect는 start() 전에. AntSpawner.start는
	# total<=0 또는 ant_scene==null인 degraded configuration에서 spawn_finished를
	# 동기 emit하므로 connect를 늦추면 no_more_ants 가드의 _spawner_finished가
	# 영구 false로 남아 time_out fallback만 발화 (codex impl review MEDIUM R1 2026-05-10).
	_spawner_finished = false
	if _spawner != null:
		if _spawner.ant_scene == null:
			_spawner.ant_scene = ant_scene
		_spawner.total = stage_data.total_ants
		if _home != null and _spawner.spawn_position == Vector2.ZERO:
			_spawner.spawn_position = _home.get_spawn_position()
		if not _spawner.spawn_finished.is_connected(_on_spawner_finished):
			_spawner.spawn_finished.connect(_on_spawner_finished)
		# codex plan-review v1 MED-2: 직접 대입 대신 set_release_rate 호출 →
		# AntSpawner가 release_rate_changed emit → ReleaseRateStepper.Value Label 동기.
		# .tscn 기본 Value text가 빈 문자열인 risk를 첫 frame에 채움.
		_spawner.set_release_rate(stage_data.release_rate_initial)
		_spawner.start(_spawn_parent)

	_time_left = stage_data.time_limit_seconds
	_completed = false

	# Phase 11: HUD ReleaseRateStepper의 KB/Pad RELEASE_RATE_UP/DOWN 소비자.
	# PAUSE_TOGGLE은 StepFrame 소비, 본 핸들러는 release_rate 만 처리.
	if not EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.connect(_on_action)

	# Phase 6: stage 결과 표시는 SceneFlow/Overlay 책임. StageRunner는 emit만 함.

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
		# Phase 20 — sfx_request emit (id only). receiver는 phase 21에서 connect.
		EventBus.sfx_request.emit(&"stage_cleared")
		EventBus.stage_cleared.emit(_make_result(true, ""))
		_disable_toolbar()
		return

	if (_spawner_finished
		and _living_ant_count() == 0
		and score_system.in_transit_pieces == 0
		and candy_hp > 0):
		_completed = true
		# Phase 20 — sfx_request emit (id only). receiver는 phase 21에서 connect.
		EventBus.sfx_request.emit(&"stage_failed")
		EventBus.stage_failed.emit(_make_result(false, "no_more_ants"))
		_disable_toolbar()
		return

	if _time_left <= 0.0:
		_completed = true
		# Phase 20 — sfx_request emit (id only). receiver는 phase 21에서 connect.
		EventBus.sfx_request.emit(&"stage_failed")
		EventBus.stage_failed.emit(_make_result(false, "time_out"))
		_disable_toolbar()

func _disable_toolbar() -> void:
	# codex plan-review v1 HIGH-2: direct ref 라우팅 — global group lookup 사용 X.
	# Stage01은 toolbar_path 미설정 → _toolbar null → 안전한 no-op.
	if _toolbar != null and _toolbar.has_method("set_all_disabled"):
		_toolbar.set_all_disabled(true)

func _on_action(name: StringName, _payload: Dictionary) -> void:
	if _completed or _spawner == null:
		return
	# codex plan-review v2 NEW-M1: pause 중 RELEASE_RATE_UP/DOWN 차단.
	# Stepper는 INHERIT process_mode라 mouse click이 자동 차단되지만, KB(F1/F2)/Pad(D-Pad↑↓)는
	# InputRouter → action_triggered 경로라 본 가드가 일관성 보장.
	# PAUSE_TOGGLE은 StepFrame이 소비 → 본 핸들러는 release_rate 만 처리하므로 blanket guard 안전.
	var tree: SceneTree = get_tree()
	if tree != null and tree.paused:
		return
	if name == GameAction.RELEASE_RATE_UP:
		_spawner.set_release_rate(_spawner.release_rate + RR_STEP)
	elif name == GameAction.RELEASE_RATE_DOWN:
		_spawner.set_release_rate(_spawner.release_rate - RR_STEP)

func _make_result(cleared: bool, reason: String) -> Dictionary:
	return {
		"stage_id": stage_data.id,
		"cleared": cleared,
		"saved": score_system.saved_pieces,
		"lost": score_system.lost_pieces,
		"original_hp": score_system.original_hp,
		"score": score_system.score(),
		"time_left": _time_left,
		"reason": reason,
		# Phase 20 — Array[float], 빈 배열이면 글로벌 Scoring.STAR_THRESHOLDS fall-back.
		"star_thresholds": stage_data.star_thresholds,
	}

func _living_ant_count() -> int:
	# 활성 stage subtree로 스코프. `ants` group은 모든 stage의 ant가 누적되는 전역
	# group이라 1-frame stage overlap 시 이전 stage의 큐드된 ant가 남아 새 StageRunner의
	# no_more_ants 판정을 지연/오염시킬 수 있음. _spawn_parent 자손만 카운트해 차단
	# (codex plan-review HIGH 2026-05-10).
	if _spawn_parent == null:
		return 0
	var count: int = 0
	for n in get_tree().get_nodes_in_group("ants"):
		if not is_instance_valid(n):
			continue
		if _spawn_parent.is_ancestor_of(n):
			count += 1
	return count

func _on_spawner_finished() -> void:
	_spawner_finished = true

func _exit_tree() -> void:
	# Phase 5 sweep — ScoreSystem(RefCounted) signal leak 차단. stage reload 시
	# 이전 score_system이 EventBus에 그대로 매달려 새 instance와 동시 카운트하는
	# 누수 방지 (GAME_FLOW_PROPOSAL_V5 §3.1 Pre-Phase 6 hot-fix).
	if score_system != null:
		score_system.stop()
	if EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.disconnect(_on_action)
