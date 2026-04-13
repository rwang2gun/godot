extends CharacterBase

## =====================================================================
##  CharacterWM — 마법사 (Wand Mage)
##  원거리 콤보 4단, 소용돌이/스윕 특수기
## =====================================================================

const MAX_SPEED    := 5.5
const ACCELERATION := 12.0
const DAMPING      := 18.0
const TURN_SPEED   := 15.0
const GRAVITY      := -20.0

const ATTACK_RANGE := 3.0
const ATTACK_ANGLE := PI / 4.0
const COMBO_MAX    := 4

const DASH_SPEED    := 12.0
const DASH_DURATION := 0.25

const SKILL_COOLDOWN_MAX := 8.0

var combo_step      : int   = 0
var attack_timer    : float = 0.0
var attack_duration : float = 0.5
var active_end      : float = 0.25
var has_hit         : bool  = false
var input_buffered  : bool  = false
var combo_cooldown  : float = 0.0

var dash_timer : float   = 0.0
var dash_dir   : Vector3 = Vector3.ZERO

var hurt_timer    : float   = 0.0
var knockback_vel : Vector3 = Vector3.ZERO

var skill_cooldown : float = 0.0
var mp             : int   = 0
var max_mp         : int   = 50

var facing_angle  : float = 0.0
var target_facing : float = 0.0

var game_manager : Node  = null
var goblins      : Array = []
var camera_rig           = null

var state_machine : StateMachine = StateMachine.new()

# --- 포즈 매핑 (WM 전용) ---
var pose_map: Dictionary = {
	"idle": "wm_idle", "battle_idle": "wm_battle_idle",
	"combo1": "wm_combo1", "combo2": "wm_combo2", "combo3a": "wm_combo3", "combo3b": "wm_combo3", "combo4": "wm_combo4",
	"dash": "wm_dash", "hurt": "hurt",
	"skill_cast": "wm_skill", "ult_windup": "wm_ult_charge", "ult_strike": "wm_ult_charge",
	"shoulder_bash": "wm_charge_windup", "walk1": "wm_idle",
}


## 머티리얼 오버라이드 — 보라 마법사
func _init_materials() -> void:
	mat_chest  = _make_mat(Color(0.4, 0.15, 0.6))
	mat_waist  = _make_mat(Color(0.3, 0.1, 0.45))
	mat_pelvis = _make_mat(Color(0.35, 0.12, 0.5))
	mat_skin   = _make_mat(Color(1.0, 0.86, 0.67))
	mat_hair   = _make_mat(Color(0.9, 0.85, 0.7))
	mat_right  = _make_mat(Color(0.5, 0.2, 0.7))
	mat_left   = _make_mat(Color(0.5, 0.2, 0.7))


func _ready() -> void:
	super()

	state_machine.add_state("idle",         IdleState.new(self))
	state_machine.add_state("walk",         WalkState.new(self))
	state_machine.add_state("attack",       AttackState.new(self))
	state_machine.add_state("dash",         DashState.new(self))
	state_machine.add_state("hurt",         HurtState.new(self))
	state_machine.add_state("chargeAttack", ChargeAttackState.new(self))
	state_machine.add_state("skill",        SkillState.new(self))
	state_machine.add_state("ultimate",     UltimateState.new(self))
	state_machine.add_state("swapOut",      SwapOutState.new(self))
	state_machine.add_state("swapIn",       SwapInState.new(self))
	state_machine.change_state("idle")


func _physics_process(delta: float) -> void:
	super(delta)

	if game_manager and game_manager.is_game_over:
		return

	combo_cooldown  = maxf(0.0, combo_cooldown - delta)
	skill_cooldown  = maxf(0.0, skill_cooldown - delta)

	state_machine.update(delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	move_and_slide()
	_update_facing(delta)


func set_pose(pose_name: String, speed: float = 10.0) -> void:
	var mapped: String = pose_map.get(pose_name, pose_name)
	super(mapped, speed)


func apply_friction(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DAMPING * delta)
	velocity.z = move_toward(velocity.z, 0.0, DAMPING * delta)

func get_move_dir() -> Vector3:
	var raw: Vector2 = InputManager.move_input
	if raw == Vector2.ZERO:
		return Vector3.ZERO
	var theta: float = camera_rig.theta if camera_rig else 0.0
	var fwd := Vector3(-sin(theta), 0.0, -cos(theta))
	var rgt := Vector3( cos(theta), 0.0, -sin(theta))
	return (rgt * raw.x + fwd * -raw.y).normalized()

func get_nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	var min_d := INF
	for g in goblins:
		if not is_instance_valid(g) or g.get("is_dead"):
			continue
		var d := global_position.distance_to(g.global_position)
		if d < min_d:
			min_d = d
			nearest = g
	return nearest

func start_attack() -> void:
	combo_step = 1
	state_machine.change_state("attack")

func start_dash() -> void:
	var dir := get_move_dir()
	if dir.length() < 0.1:
		dir = -pivot.global_transform.basis.z
		dir.y = 0
		dir = dir.normalized()
	dash_dir   = dir
	dash_timer = 0.0
	state_machine.change_state("dash")

func check_hit() -> void:
	var fwd := -pivot.global_transform.basis.z
	fwd.y = 0
	if fwd.length() > 0.01:
		fwd = fwd.normalized()
	for g in goblins:
		if not is_instance_valid(g) or g.get("is_dead"):
			continue
		var to_e: Vector3 = g.global_position - global_position
		to_e.y = 0
		var dist := to_e.length()
		if dist > ATTACK_RANGE + 0.4:
			continue
		if dist > 0.05:
			var angle := acos(clampf(fwd.dot(to_e.normalized()), -1.0, 1.0))
			if angle > ATTACK_ANGLE + 0.2:
				continue
		_apply_hit(g)
		return

func take_hit(from_dir: Vector3, _knockdown: bool = false) -> void:
	if state_machine.current_name == "dash":
		return
	knockback_vel = from_dir * 5.0
	hurt_timer = 0.4
	combo_step = 0
	state_machine.change_state("hurt")
	if game_manager:
		game_manager.player_take_hit()

func request_swap() -> void:
	if game_manager and game_manager.has_method("request_swap"):
		game_manager.request_swap()

func _apply_hit(goblin: Node3D) -> void:
	has_hit = true
	var kb := (goblin.global_position - global_position)
	kb.y = 0
	if kb.length() > 0.01:
		kb = kb.normalized()
	var is_last_hit := (combo_step == COMBO_MAX)
	if goblin.has_method("take_hit"):
		goblin.take_hit(kb, is_last_hit)
	if game_manager:
		game_manager.add_score(10 * combo_step)
		game_manager.trigger_hitstop(0.06)
		if is_last_hit:
			game_manager.trigger_slow_mo(0.8)
	mp = mini(mp + 5, max_mp)

func _update_facing(delta: float) -> void:
	if state_machine.current_name == "walk":
		var vel2 := Vector2(velocity.x, velocity.z)
		if vel2.length() > 0.5:
			target_facing = atan2(-vel2.x, -vel2.y)
	facing_angle = lerp_angle(facing_angle, target_facing, TURN_SPEED * delta)
	pivot.rotation.y = facing_angle
