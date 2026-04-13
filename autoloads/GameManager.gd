extends Node3D

# --- Game State ---
var score: int = 0
var player_hits: int = 0
const MAX_PLAYER_HITS: int = 10
var is_game_over: bool = false

# --- Node References ---
var player: CharacterBody3D          # 현재 활성 캐릭터
var characters: Array = []           # [FS, EF, WM] 전체 캐릭터 배열
var active_idx: int = 0              # 현재 활성 캐릭터 인덱스
var goblins: Array = []
var camera_rig: Node3D

# --- AI Coordinator ---
var attacker_idx: int = -1
var ai_coordinator_timer: float = 0.0

# --- Time Effects ---
var slow_timer: float = 0.0
var hitstop_timer: float = 0.0
var _was_hitstop: bool = false

# --- 교체 ---
var _swap_pending_idx: int = -1      # 교체 대기 중인 캐릭터 인덱스

# --- UI ---
@onready var score_label: Label = $UI/HUD/ScoreLabel
@onready var hp_label: Label    = $UI/HUD/HPLabel
@onready var stance_label: Label = $UI/HUD/StanceLabel

# --- 캐릭터 이름 ---
const CHAR_NAMES: Array = ["FS", "EF", "WM"]

func _ready() -> void:
	# 캐릭터 배열 구성: FS(Player), EF, WM
	var fs: CharacterBody3D = $Player
	var ef: CharacterBody3D = $CharacterEF
	var wm: CharacterBody3D = $CharacterWM
	characters = [fs, ef, wm]

	camera_rig = $CameraRig

	# 모든 캐릭터에 참조 주입
	for ch in characters:
		ch.set("game_manager", self)
		ch.set("camera_rig", camera_rig)

	# 고블린 설정
	for child in $Goblins.get_children():
		goblins.append(child)
		child.set("game_manager", self)

	# 모든 캐릭터에 고블린 참조 전달
	for ch in characters:
		ch.set("goblins", goblins)

	# EF/WM 비활성화 → FS만 활성화
	for i in characters.size():
		if i == 0:
			_activate_character(i)
		else:
			_deactivate_character(i)

	# 고블린 player_ref 설정
	_update_goblin_player_ref()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_assign_attacker(0)

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

func _update_time_effects(_delta: float) -> void:
	# Engine.time_scale=0일 때 delta도 0이 되므로 실시간 delta 사용
	var real_dt: float = 1.0 / Engine.get_frames_per_second() if Engine.get_frames_per_second() > 0 else 0.016

	if hitstop_timer > 0:
		hitstop_timer -= real_dt
		if not _was_hitstop:
			Engine.time_scale = 0.0
			_was_hitstop = true
		if hitstop_timer <= 0:
			Engine.time_scale = 1.0 if slow_timer <= 0 else 0.25
			_was_hitstop = false
		return

	if slow_timer > 0:
		slow_timer -= real_dt
		Engine.time_scale = 0.25
	else:
		Engine.time_scale = 1.0

func _update_ai_coordinator(delta: float) -> void:
	if is_game_over:
		return

	ai_coordinator_timer = max(0, ai_coordinator_timer - delta)

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

func trigger_hitstop(duration: float = 0.08) -> void:
	hitstop_timer = duration

func trigger_slow_mo(duration: float = 2.0) -> void:
	slow_timer = duration

func on_goblin_hit_interrupted() -> void:
	ai_coordinator_timer = 1.0
	_pick_next_attacker()

# ----- 캐릭터 교체 시스템 -----

## 교체 요청 (Player에서 호출)
func request_swap() -> void:
	if is_game_over:
		return

	var target_idx: int
	if InputManager.swap_index >= 0 and InputManager.swap_index < characters.size():
		target_idx = InputManager.swap_index
	else:
		# Tab = 다음 캐릭터 순환
		target_idx = (active_idx + 1) % characters.size()

	# 이미 활성인 캐릭터면 무시
	if target_idx == active_idx:
		return

	_swap_pending_idx = target_idx

	# 현재 캐릭터를 SwapOut 상태로 전환
	if player.has_method("state_machine"):
		pass
	# state_machine은 변수이므로 직접 접근
	if player.get("state_machine"):
		player.state_machine.change_state("swapOut")
	else:
		# state_machine이 없으면 즉시 교체
		complete_swap_out()

## SwapOut 완료 시 호출 (SwapOutState에서 호출)
func complete_swap_out() -> void:
	if _swap_pending_idx < 0:
		return

	var old_pos: Vector3 = player.global_position
	var old_facing: float = player.get("facing_angle") if player.get("facing_angle") != null else 0.0

	# 이전 캐릭터 비활성화
	_deactivate_character(active_idx)

	# 새 캐릭터 활성화
	active_idx = _swap_pending_idx
	_swap_pending_idx = -1

	var new_char: CharacterBody3D = characters[active_idx]
	new_char.global_position = old_pos
	if new_char.get("facing_angle") != null:
		new_char.set("facing_angle", old_facing)
		new_char.set("target_facing", old_facing)

	_activate_character(active_idx)
	_update_goblin_player_ref()

	# SwapIn 상태로 시작
	if new_char.get("state_machine"):
		new_char.state_machine.change_state("swapIn")


func _activate_character(idx: int) -> void:
	var ch: CharacterBody3D = characters[idx]
	ch.visible = true
	ch.set_physics_process(true)
	ch.set_process(true)
	# 충돌 활성화
	for child in ch.get_children():
		if child is CollisionShape3D:
			child.disabled = false
	player = ch
	camera_rig.set_target(ch)


func _deactivate_character(idx: int) -> void:
	var ch: CharacterBody3D = characters[idx]
	ch.visible = false
	ch.set_physics_process(false)
	ch.set_process(false)
	ch.velocity = Vector3.ZERO
	# 충돌 비활성화
	for child in ch.get_children():
		if child is CollisionShape3D:
			child.disabled = true


func _update_goblin_player_ref() -> void:
	for g in goblins:
		if is_instance_valid(g):
			g.set("player_ref", player)


func _update_ui() -> void:
	if score_label:
		score_label.text = "SCORE: %d" % score
	if hp_label:
		hp_label.text = "HITS: %d / %d" % [player_hits, MAX_PLAYER_HITS]
	if stance_label:
		var name_str: String = CHAR_NAMES[active_idx] if active_idx < CHAR_NAMES.size() else "??"
		stance_label.text = "STANCE: %s" % name_str
