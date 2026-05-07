class_name GameManager
extends Node3D

# --- Game State ---
var score: int = 0
var player_hits: int = 0
const MAX_PLAYER_HITS: int = 10
var is_game_over: bool = false

# --- Node References ---
var player: CharacterBase           # 현재 활성 캐릭터
var characters: Array = []          # [FS, EF, WM] 전체 캐릭터 배열
var active_idx: int = 0             # 현재 활성 캐릭터 인덱스
var goblins: Array = []
var camera_rig: CameraRig

# --- AI Coordinator ---
var attacker_idx: int = -1
var ai_coordinator_timer: float = 0.0

# --- Time Effects ---
var slow_timer: float = 0.0
var hitstop_timer: float = 0.0
var _was_hitstop: bool = false

# --- 교체 ---
var _swap_pending_idx: int = -1

# --- UI ---
@onready var score_label: Label  = $UI/HUD/ScoreLabel
@onready var hp_label: Label     = $UI/HUD/HPLabel
@onready var stance_label: Label = $UI/HUD/StanceLabel
@onready var debug_label: Label  = $UI/HUD/DebugLabel

# --- 캐릭터 이름 ---
const CHAR_NAMES: Array = ["FS", "EF", "WM"]


func _ready() -> void:
	# 캐릭터 배열 구성: FS(Player), EF, WM
	var fs: CharacterBase = $Player
	var ef: CharacterBase = $CharacterEF
	var wm: CharacterBase = $CharacterWM
	characters = [fs, ef, wm]

	camera_rig = $CameraRig

	# 모든 캐릭터에 참조 주입
	for ch_any in characters:
		var ch: CharacterBase = ch_any
		ch.game_manager = self
		ch.camera_rig = camera_rig

	# 고블린 설정
	for child in $Goblins.get_children():
		goblins.append(child)
		child.set("game_manager", self)

	# 모든 캐릭터에 고블린 참조 전달
	for ch_any in characters:
		var ch: CharacterBase = ch_any
		ch.goblins = goblins

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
	var fps: float = Engine.get_frames_per_second()
	var real_dt: float = 1.0 / fps if fps > 0 else 0.016

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

	ai_coordinator_timer = maxf(0.0, ai_coordinator_timer - delta)

	if attacker_idx >= 0 and attacker_idx < goblins.size():
		# 타입 없이 먼저 받아서 프리된 인스턴스 할당 에러 방지
		var cur = goblins[attacker_idx]
		if not is_instance_valid(cur) or cur.get("is_dead"):
			_pick_next_attacker()
	else:
		_pick_next_attacker()


func _pick_next_attacker() -> void:
	if ai_coordinator_timer > 0:
		return
	# 프리된 엔트리 제거 (주기적 정리)
	_cleanup_freed_goblins()
	var living: Array = []
	for g in goblins:
		if is_instance_valid(g) and not g.get("is_dead"):
			living.append(g)
	if living.is_empty():
		attacker_idx = -1
		return
	var candidate = living[randi() % living.size()]
	attacker_idx = goblins.find(candidate)
	_assign_attacker(attacker_idx)
	ai_coordinator_timer = randf_range(2.5, 4.0)


func _assign_attacker(idx: int) -> void:
	for i in goblins.size():
		var g = goblins[i]
		if not is_instance_valid(g):
			continue
		g.set("role", "attacker" if i == idx else "watcher")


func _cleanup_freed_goblins() -> void:
	var cleaned: Array = []
	for g in goblins:
		if is_instance_valid(g):
			cleaned.append(g)
	goblins = cleaned


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
		target_idx = (active_idx + 1) % characters.size()

	if target_idx == active_idx:
		return

	_swap_pending_idx = target_idx

	# 현재 캐릭터를 SwapOut 상태로 전환
	player.state_machine.change_state("swapOut")


## SwapOut 완료 시 호출 (SwapOutState에서 호출)
func complete_swap_out() -> void:
	if _swap_pending_idx < 0:
		return

	var old_pos: Vector3 = player.global_position
	var old_facing: float = player.facing_angle

	_deactivate_character(active_idx)

	active_idx = _swap_pending_idx
	_swap_pending_idx = -1

	var new_char: CharacterBase = characters[active_idx]
	new_char.global_position = old_pos
	new_char.facing_angle = old_facing
	new_char.target_facing = old_facing

	_activate_character(active_idx)
	_update_goblin_player_ref()

	new_char.state_machine.change_state("swapIn")


func _activate_character(idx: int) -> void:
	var ch: CharacterBase = characters[idx]
	ch.visible = true
	ch.set_physics_process(true)
	ch.set_process(true)
	for child in ch.get_children():
		if child is CollisionShape3D:
			child.disabled = false
	player = ch
	camera_rig.set_target(ch)


func _deactivate_character(idx: int) -> void:
	var ch: CharacterBase = characters[idx]
	ch.visible = false
	ch.set_physics_process(false)
	ch.set_process(false)
	ch.velocity = Vector3.ZERO
	for child in ch.get_children():
		if child is CollisionShape3D:
			child.disabled = true


func _update_goblin_player_ref() -> void:
	for g_any in goblins:
		var g = g_any
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
	if debug_label and player:
		var lines: PackedStringArray = PackedStringArray()
		lines.append("Player State: %s" % player.state_machine.current_name)
		for i in goblins.size():
			# 타입 없이 먼저 받아 프리된 인스턴스 할당 에러 방지
			var g = goblins[i]
			if not is_instance_valid(g):
				continue
			var gn: Node3D = g
			var dist: float = player.global_position.distance_to(gn.global_position)
			var role_v: Variant = gn.get("role")
			var state_v: Variant = gn.get("ai_state")
			var atk_v: Variant = gn.get("attack_type")
			var cd_v: Variant = gn.get("attack_cd")
			var g_role: String = role_v if role_v != null else "?"
			var g_state: String = state_v if state_v != null else "?"
			var g_atk: String = atk_v if atk_v != null else ""
			var g_cd: float = cd_v if cd_v != null else 0.0
			lines.append("G%d: %.1fm  role=%s  ai=%s  atk=%s  cd=%.1f" % [i + 1, dist, g_role, g_state, g_atk, g_cd])
		debug_label.text = "\n".join(lines)
