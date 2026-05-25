extends Node

# Phase 20 — P-D1 회귀 가드. sfx_request 8 신규 id가 정확한 위치에 emit되는지 검증.
# 정적 검증: 각 id가 plan §3.2에 명시된 source file에 emit literal로 존재.
# 동적 검증: 직접 호출 가능한 경로(LostState/WaterHazard/StickyHazard)에 한해 emit 캡처.

# id → 검증 대상 source file 매핑 (plan §3.2 freeze).
const SFX_SITES: Array = [
	{"id": "candy_pick",       "path": "res://scripts/world/Candy.gd"},
	{"id": "candy_depleted",   "path": "res://scripts/world/Candy.gd"},
	{"id": "ant_save",         "path": "res://scripts/world/Home.gd"},
	{"id": "candy_lost",       "path": "res://scripts/ant/states/LostState.gd"},
	{"id": "stage_cleared",    "path": "res://scripts/core/StageRunner.gd"},
	{"id": "stage_failed",     "path": "res://scripts/core/StageRunner.gd"},
	{"id": "water_splash",     "path": "res://scripts/world/hazards/WaterHazard.gd"},
	{"id": "sticky_glue",      "path": "res://scripts/world/hazards/StickyHazard.gd"},
]

var _captured: Array[StringName] = []
var _failed: bool = false

func _ready() -> void:
	# (1) 정적 검증 — 각 id가 명시된 source file에 emit literal로 존재.
	for site in SFX_SITES:
		var id: String = site["id"]
		var path: String = site["path"]
		var content := FileAccess.get_file_as_string(path)
		if content.is_empty():
			_fail("cannot read %s" % path)
			return
		var literal := "sfx_request.emit(&\"%s\")" % id
		if not content.contains(literal):
			_fail("expected `%s` literal in %s" % [literal, path])
			return
	print("[SfxRequestEmitTest] 정적 8 id 검증 OK")

	# (2) 동적 검증 — sfx_request 구독 후 직접 트리거 가능한 경로 호출.
	EventBus.sfx_request.connect(_on_sfx)

	# candy_lost: LostState.enter() 직접 트리거 (Ant에 has_candy=true).
	var ant: Ant = preload("res://scenes/entities/Ant.tscn").instantiate()
	add_child(ant)
	await get_tree().physics_frame
	ant.has_candy = true
	ant.state_machine.change_state(LostState.new())
	await get_tree().physics_frame
	if not (&"candy_lost" in _captured):
		_fail("dynamic: candy_lost not captured after LostState entry")
		return
	# water_splash: WaterHazard._handle_ant_entry 직접 호출. (Ant 새로 spawn — 이전 ant는 queue_free)
	var ant2: Ant = preload("res://scenes/entities/Ant.tscn").instantiate()
	add_child(ant2)
	await get_tree().physics_frame
	var water_haz: WaterHazard = WaterHazard.new()
	add_child(water_haz)
	# WaterHazard._handle_ant_entry는 protected 아니지만 직접 호출 — sfx emit + LostState 전이.
	water_haz._handle_ant_entry(ant2)
	await get_tree().physics_frame
	if not (&"water_splash" in _captured):
		_fail("dynamic: water_splash not captured after WaterHazard entry")
		return
	# sticky_glue: StickyHazard._handle_ant_entry. duration 0 회피 위해 default 3.0 유지.
	var ant3: Ant = preload("res://scenes/entities/Ant.tscn").instantiate()
	add_child(ant3)
	await get_tree().physics_frame
	var sticky_haz: StickyHazard = StickyHazard.new()
	add_child(sticky_haz)
	sticky_haz._handle_ant_entry(ant3)
	await get_tree().physics_frame
	if not (&"sticky_glue" in _captured):
		_fail("dynamic: sticky_glue not captured after StickyHazard entry")
		return
	# stage_cleared/stage_failed: 직접 emit 검증은 StageRunner._process 내부 + ScoreSystem 필요해
	# 정적 검증만으로 충분(이미 위 step에서 통과).
	# candy_pick/candy_depleted/ant_save도 정적 검증으로 cover (Candy/Home body_entered 시뮬레이션은 복잡).
	EventBus.sfx_request.disconnect(_on_sfx)
	print("[SfxRequestEmitTest] PASS (static 8 + dynamic 3)")
	get_tree().quit(0)

func _on_sfx(id: StringName) -> void:
	_captured.append(id)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[SfxRequestEmitTest] FAIL ", msg)
	get_tree().quit(1)
