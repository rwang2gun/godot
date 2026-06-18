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
# Phase 4 (intro-card-infra, STAGE_GUIDE_PLAN §2.3 방식2) — 스폰/타이머 시작 게이트.
# true(기본): _ready 끝에서 즉시 begin() — 직접 로드(헤드리스 테스트·플레이테스트 F6)·인트로 카드
#   없는 경로. 기존 모든 stage 씬·테스트가 이 기본값으로 종전과 동일하게 자동 시작한다.
# false: SceneFlow가 인트로 카드로 게이트할 때 add_child 전에 설정 → _ready가 spawn을 시작하지
#   않고, 카드 intro_dismissed 후 SceneFlow가 begin()을 호출한다.
@export var auto_begin: bool = true

var score_system: ScoreSystem = null

var _candy: Candy = null
var _home: Home = null
var _spawner: AntSpawner = null
var _hud: Node = null
var _toolbar: Node = null
var _spawn_parent: Node = null

var _time_left: float = 0.0
# 결정론 모드 타임아웃 — _process delta 누적 대신 begin() 시점 물리-프레임 기준 경과로 time_left 산출.
# delta 누적은 process/physics 프레임 비대칭에서 비결정적일 수 있어, 전역 물리 프레임 카운터에서 직접 계산.
var _begin_frame: int = 0
var _completed: bool = false
var _spawner_finished: bool = false
# Phase 4 — begin() 게이트. 카드 표시 중에는 false라 _process가 타이머/종료 판정을 진행하지 않고
# _spawner.start()도 호출되지 않는다. begin()은 멱등 — 중복 호출은 무시(정확히 1회 시작).
var _begun: bool = false

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

	# 스킬 가이드 컨트롤러(SIGN/DEVICE 배치 글로우 + 개미 글로우 + 장치 ghost) 런타임 보강.
	# 씬에 이미 있으면 생성하지 않는다(Stage01~09는 .tscn에 명시 배선). Stage10처럼 누락된 씬에
	# 안전망을 제공해 "표지판 배치 가이드가 안 뜨는" 회귀를 영구 차단한다(2026-06-08).
	_ensure_guide_controllers()

	# SkillRegistry 검증
	var errors: Array[String] = SkillRegistry.validate_stage(stage_data)
	if not errors.is_empty():
		push_error("[StageRunner] SkillRegistry errors: %s" % str(errors))

	# Candy 초기화
	if _candy != null:
		_candy.hp = stage_data.candy_hp

	# HUD 초기 candy_hp 표시 — candy_piece_picked는 첫 픽업 시점부터만 발화하므로
	# 본 push 없으면 stage 시작 직후 카운터가 0으로 노출됨.
	if _hud != null and _hud.has_method("set_candy_hp"):
		_hud.set_candy_hp(stage_data.candy_hp)

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
		if stage_data.layout != null:
			_spawner.spawn_direction = stage_data.layout.spawn_direction
			_spawner.spawn_direction_alternate = stage_data.layout.spawn_direction_alternate
		if _home != null and _spawner.spawn_position == Vector2.ZERO:
			_spawner.spawn_position = _home.get_spawn_position()
		if not _spawner.spawn_finished.is_connected(_on_spawner_finished):
			_spawner.spawn_finished.connect(_on_spawner_finished)
		# codex plan-review v1 MED-2: 직접 대입 대신 set_release_rate 호출 →
		# AntSpawner가 release_rate_changed emit → ReleaseRateStepper.Value Label 동기.
		# .tscn 기본 Value text가 빈 문자열인 risk를 첫 frame에 채움. (begin 전에 둬도
		# 안전 — set_release_rate는 spawn을 시작하지 않고 rate/HUD만 갱신.)
		# Phase 4 — _spawner.start()는 begin()으로 분리(아래). connect는 위에서 이미 완료라
		# CRITICAL ORDERING(connect ⊂ start 이전) 유지.
		_spawner.set_release_rate(stage_data.release_rate_initial)

	_time_left = stage_data.time_limit_seconds
	_completed = false

	# Phase 11: HUD ReleaseRateStepper의 KB/Pad RELEASE_RATE_UP/DOWN 소비자.
	# PAUSE_TOGGLE은 StepFrame 소비, 본 핸들러는 release_rate 만 처리.
	if not EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.connect(_on_action)

	# Phase 6: stage 결과 표시는 SceneFlow/Overlay 책임. StageRunner는 emit만 함.

	print("[StageRunner] ready Stage ", stage_data.id, " total=", stage_data.total_ants, " hp=", stage_data.candy_hp, " auto_begin=", auto_begin)

	# Phase 4 — 직접 로드(헤드리스/플레이테스트)·카드 없는 경로는 즉시 시작. SceneFlow가 카드로
	# 게이트할 땐 auto_begin=false로 두고 intro_dismissed 후 begin() 호출.
	if auto_begin:
		begin()

# 스킬 가이드 컨트롤러 안전망 — 씬에 없으면 런타임 생성해 World에 배선.
# AffordanceGlowController: SIGN(표지판)/DEVICE 배치 셀 글로우 + 무장/정착 스킬 개미 글로우.
# PlacementPreview: DEVICE 장치 설치 ghost.
# 둘 다 toolbar._pending_skill_id + 커서를 폴링하므로 toolbar/terrain 참조가 필요하다. 절대 경로로
# 주입(add_child 시 _ready가 NodePath를 resolve). 이미 존재하면(stage01~09 .tscn 명시) 건드리지 않는다.
func _ensure_guide_controllers() -> void:
	if _toolbar == null or _spawn_parent == null:
		return
	var terrain: Node = _spawn_parent.get_node_or_null("Terrain")
	if terrain == null:
		return
	var has_glow: bool = false
	var has_preview: bool = false
	for c in _spawn_parent.get_children():
		if c is AffordanceGlowController:
			has_glow = true
		if c is PlacementPreview:
			has_preview = true
	if not has_glow:
		var glow := AffordanceGlowController.new()
		glow.name = "AffordanceGlowController"
		glow.toolbar_path = _toolbar.get_path()
		glow.terrain_path = terrain.get_path()
		_spawn_parent.add_child(glow)
	if not has_preview:
		var preview := PlacementPreview.new()
		preview.name = "PlacementPreview"
		preview.toolbar_path = _toolbar.get_path()
		preview.terrain_path = terrain.get_path()
		_spawn_parent.add_child(preview)

# 스폰·타이머 게이트 진입점 (Phase 4 — STAGE_GUIDE_PLAN §2.3 방식2). 멱등(중복 호출 무시 = 정확히 1회 시작).
func begin() -> void:
	if _begun:
		return
	_begun = true
	_begin_frame = Engine.get_physics_frames()
	if _spawner != null:
		print("[StageRunner] begin Stage ", stage_data.id if stage_data != null else -1)
		_spawner.start(_spawn_parent)

# 테스트/배선 inspector — 스폰이 시작됐는지(begin 호출 후 true).
func is_begun() -> bool:
	return _begun

func _process(delta: float) -> void:
	# Phase 4 — begin() 전(카드 표시 중)에는 타이머/종료 판정을 진행하지 않는다.
	if not _begun or _completed or stage_data == null:
		return

	# 결정론 모드: 전역 물리 프레임 경과로 time_left 산출(delta 누적 비결정성 회피). 기본: 종전 delta 차감.
	if SimConfig.deterministic:
		var elapsed: float = float(Engine.get_physics_frames() - _begin_frame) / float(Engine.physics_ticks_per_second)
		_time_left = max(0.0, stage_data.time_limit_seconds - elapsed)
	else:
		_time_left = max(0.0, _time_left - delta)
	if _hud != null and _hud.has_method("update_time"):
		_hud.update_time(_time_left)

	var candy_hp: int = _candy.hp if _candy != null else 0

	# 스테이지 종료 판정 — 더 이상 진행 불가하거나 시간이 끝나면 종료하고, 그 시점의 별점으로
	# 클리어/실패를 가른다. 2026-06-04 정책: 별 1개 이상(저장 비율 ≥ 1성 임계)이면 클리어.
	#   (1) is_cleared      = 모든 사탕 처리(저장 또는 손실) 완료.
	#   (2) no_more_ants    = 남은 개미 0 + 운반 중 0 → 더 옮길 수 없음(미수거 사탕이 남아도 종료).
	#   (3) time_out        = 제한 시간 종료.
	var reason: String = ""
	var concluded: bool = false
	if score_system.is_cleared(candy_hp):
		concluded = true
	elif _spawner_finished and _living_ant_count() == 0 and score_system.in_transit_pieces == 0:
		concluded = true
		reason = "no_more_ants"
	elif _time_left <= 0.0:
		concluded = true
		reason = "time_out"

	if concluded:
		_completed = true
		_conclude_stage(reason)

# 종료 시점 별점으로 클리어/실패 확정. 별 1개 이상이면 stage_cleared emit →
# SaveData가 cleared=true 기록 → is_unlocked(다음 스테이지) true → 다음 스테이지 진입 가능.
func _conclude_stage(fail_reason: String) -> void:
	# 클리어 = 별 1개 이상 = 사탕 조각 1개 이상 회수 (Scoring 규칙 단일 SoT, HP 무관).
	var cleared: bool = Scoring.compute_stars(score_system.saved_pieces, score_system.original_hp) >= 1
	# Phase 20 — sfx_request emit (id only). receiver는 phase 21에서 connect.
	if cleared:
		EventBus.sfx_request.emit(&"stage_cleared")
		EventBus.stage_cleared.emit(_make_result(true, ""))
	else:
		EventBus.sfx_request.emit(&"stage_failed")
		EventBus.stage_failed.emit(_make_result(false, fail_reason if fail_reason != "" else "incomplete"))
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
		if not _spawn_parent.is_ancestor_of(n):
			continue
		# 2026-06-04 — 물 표류(AdriftState)·낙하 기절(DeadState) 개미는 정상 루트 복귀 불가한 종착 상태라
		# "남은 개미"에서 제외. 종료까지 queue_free되지 않고 그룹에 남아도 no_more_ants(스테이지 종료)
		# 판정을 막지 않도록 한다(기절도 표류처럼 종료까지 화면에 유지되는 정책으로 통일).
		var a: Ant = n as Ant
		if a != null and a.state_machine != null:
			var st: AntState = a.state_machine.current_state
			if st is AdriftState or st is DeadState:
				continue
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
