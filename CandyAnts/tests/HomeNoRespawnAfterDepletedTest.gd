extends Node

# Home 재생성 억제 검증 (2026-06-02) — 사탕 소진(EventBus.candy_depleted) 후 빈손 귀가 개미는
# 재생성하지 않고 제거(은퇴)된다. 소진 전엔 기존대로 respawn(노드 유지=파킹). 공용 Home.gd 동작.
# 한 Home 재사용: ant1(소진 전)=respawn 후 valid / ant2(소진 후)=retire 후 invalid.
# PASS quit(0) / FAIL quit(1).

const HOME_SCENE: PackedScene = preload("res://scenes/entities/Home.tscn")
const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")

var _home: Home = null
var _ant_before: Ant = null
var _ant_after: Ant = null
var _frame: int = 0
var _phase: int = 0
var _check_frame: int = 0

func _ready() -> void:
	_home = HOME_SCENE.instantiate() as Home
	_home.position = Vector2(400.0, 400.0)
	add_child(_home)
	_ant_before = ANT_SCENE.instantiate() as Ant
	add_child(_ant_before)
	_ant_after = ANT_SCENE.instantiate() as Ant
	add_child(_ant_after)
	print("[HomeNoRespawnTest] driver ready")

func _arm(a: Ant) -> void:
	# 빈손 + 귀가 방향(-1) + grace 해제 → _on_body_entered 본문 진입 조건.
	a.has_candy = false
	a.direction = -1
	a._grace_until = 0.0

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _phase == 0 and _frame >= 2:
		# 1) 소진 전: respawn 경로 → 노드 유지(파킹).
		_arm(_ant_before)
		_home._on_body_entered(_ant_before)
		_phase = 1
		_check_frame = _frame + 2
	elif _phase == 1 and _frame >= _check_frame:
		if not is_instance_valid(_ant_before):
			_fail("소진 전 빈손 귀가가 제거됨 — respawn(노드 유지) 기대")
			return
		# 2) candy_depleted emit → Home._candy_depleted=true → retire 경로 → 제거.
		EventBus.candy_depleted.emit()
		_arm(_ant_after)
		_home._on_body_entered(_ant_after)
		_phase = 2
		_check_frame = _frame + 2
	elif _phase == 2 and _frame >= _check_frame:
		if is_instance_valid(_ant_after):
			_fail("사탕 소진 후 빈손 귀가가 제거되지 않음 — retire 기대(respawn된 듯)")
			return
		print("[HomeNoRespawnTest] PASS — 소진 전 respawn(valid) / 소진 후 retire(removed)")
		get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[HomeNoRespawnTest] FAIL %s" % msg)
	get_tree().quit(1)
