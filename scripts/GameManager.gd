extends Node3D

# --- Game State ---
var score: int = 0
var player_hits: int = 0
const MAX_PLAYER_HITS: int = 10
var is_game_over: bool = false

# --- Node References ---
var player: CharacterBody3D
var goblins: Array = []
var camera_rig: Node3D

# --- AI Coordinator ---
# 한 번에 한 마리만 공격하도록 조율
var attacker_idx: int = -1
var ai_coordinator_timer: float = 0.0

# --- Time Effects ---
var slow_timer: float = 0.0        # 슬로우 모션 남은 시간 (실수 시간 기준)
var hitstop_timer: float = 0.0     # 히트스톱 남은 시간 (실수 시간 기준)
var _was_hitstop: bool = false

# --- UI ---
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var hp_label: Label    = $UI/HUD/HPLabel
@onready var stance_label: Label = $UI/HUD/StanceLabel

func _ready() -> void:
	player     = $Player
	camera_rig = $CameraRig
	camera_rig.set_target(player)

	for child in $Goblins.get_children():
		goblins.append(child)
		child.set("game_manager", self)
		child.set("player_ref", player)

	player.set("game_manager", self)
	player.set("goblins", goblins)
	player.set("camera_rig", camera_rig)

	_setup_inputs()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# 첫 번째 고블린을 공격자로 지정
	_assign_attacker(0)

func _setup_inputs() -> void:
	# 이미 있으면 건너뜀
	_ensure_action("attack")
	_ensure_action("dodge")
	_ensure_action("pause")

	# 마우스 좌클릭 → attack
	var mouse_ev := InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	if not _action_has_event("attack", mouse_ev):
		InputMap.action_add_event("attack", mouse_ev)

	# Space → attack
	_ensure_key_action("attack", KEY_SPACE)
	# Shift → dodge
	_ensure_key_action("dodge", KEY_SHIFT)
	# ESC → pause (마우스 해제 겸용)
	_ensure_key_action("pause", KEY_ESCAPE)

func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

func _ensure_key_action(action: String, key: Key) -> void:
	_ensure_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	if not _action_has_event(action, ev):
		InputMap.action_add_event(action, ev)

func _action_has_event(action: String, ev: InputEvent) -> bool:
	for e in InputMap.action_get_events(action):
		if e.get_class() == ev.get_class():
			return true
	return false

# ----- Process -----

func _process(delta: float) -> void:
	# ESC = 마우스 토글
	if Input.is_action_just_pressed("pause"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_update_time_effects(delta)
	_update_ai_coordinator(delta)
	_update_ui()

func _update_time_effects(delta: float) -> void:
	# 히트스톱: time_scale=0 → 잠시 후 복원
	if hitstop_timer > 0:
		hitstop_timer -= delta          # real time (time_scale=0 이어도 _process는 작동)
		if not _was_hitstop:
			Engine.time_scale = 0.0
			_was_hitstop = true
		if hitstop_timer <= 0:
			Engine.time_scale = 1.0 if slow_timer <= 0 else 0.25
			_was_hitstop = false
		return

	# 슬로우 모션
	if slow_timer > 0:
		slow_timer -= delta * 0.25      # slow_timer는 실제 경과 시간으로 줄임
		Engine.time_scale = 0.25
	else:
		Engine.time_scale = 1.0

func _update_ai_coordinator(delta: float) -> void:
	if is_game_over:
		return

	ai_coordinator_timer = max(0, ai_coordinator_timer - delta)

	# 현재 공격자가 죽었거나 비전투 상태면 교체
	if attacker_idx >= 0 and attacker_idx < goblins.size():
		var cur = goblins[attacker_idx]
		if cur.get("is_dead") or not is_instance_valid(cur):
			_pick_next_attacker()
	else:
		_pick_next_attacker()

func _pick_next_attacker() -> void:
	if ai_coordinator_timer > 0:
		return
	var living: Array = goblins.filter(func(g): return is_instance_valid(g) and not g.get("is_dead"))
	if living.is_empty():
		attacker_idx = -1
		return
	var candidate = living[randi() % living.size()]
	attacker_idx = goblins.find(candidate)
	_assign_attacker(attacker_idx)
	ai_coordinator_timer = randf_range(2.5, 4.0)

func _assign_attacker(idx: int) -> void:
	for i in goblins.size():
		if not is_instance_valid(goblins[i]):
			continue
		goblins[i].set("role", "attacker" if i == idx else "watcher")

# ----- Public API -----

func add_score(amount: int) -> void:
	score += amount

func player_take_hit() -> void:
	if is_game_over:
		return
	player_hits += 1
	if player_hits >= MAX_PLAYER_HITS:
		is_game_over = true
		print("GAME OVER!  Final Score: %d" % score)

## 히트스톱: duration초간 게임 정지 느낌
func trigger_hitstop(duration: float = 0.08) -> void:
	hitstop_timer = duration

## 슬로우 모션: duration초간 0.25배속
func trigger_slow_mo(duration: float = 2.0) -> void:
	slow_timer = duration

## 공격자 교체 딜레이 설정 (고블린이 피격당했을 때 호출)
func on_goblin_hit_interrupted() -> void:
	ai_coordinator_timer = 1.0
	_pick_next_attacker()

func _update_ui() -> void:
	if score_label:
		score_label.text = "SCORE: %d" % score
	if hp_label:
		hp_label.text = "HITS: %d / %d" % [player_hits, MAX_PLAYER_HITS]
