extends Node

## =====================================================================
##  InputManager — 입력 트리거 관리 싱글톤
##  트리거는 _process 시작 시 자동 리셋 → _physics_process까지 1프레임 유지
## =====================================================================

# --- 트리거 플래그 (매 프레임 리셋) ---
var attack_triggered       := false
var skill_triggered        := false
var ultimate_triggered     := false
var shift_triggered        := false
var charge_attack_released := false

# --- 차지 어택 ---
var is_charging     := false
var attack_hold_time := 0.0
const CHARGE_THRESHOLD := 0.3

# --- 이동 입력 ---
var move_input := Vector2.ZERO   # (x, y) raw WASD

# --- 교체 입력 ---
var swap_triggered := false
var swap_index     := -1          # 1/2/3 키 또는 Tab 순환


func _ready() -> void:
	_setup_input_map()


func _process(delta: float) -> void:
	# 이전 프레임 트리거 리셋 (→ _physics_process까지 1프레임 유지됨)
	_reset_triggers()

	# 공격: 누르는 시점엔 트리거 없음 → 홀드 시간 누적 → 릴리스 시 분기
	# - hold < CHARGE_THRESHOLD → attack_triggered (일반 공격)
	# - hold >= CHARGE_THRESHOLD → is_charging=true (홀드 중) → 릴리스 시 charge_attack_released
	if Input.is_action_just_pressed("attack"):
		attack_hold_time = 0.0
		is_charging = false
	elif Input.is_action_pressed("attack"):
		attack_hold_time += delta
		if not is_charging and attack_hold_time >= CHARGE_THRESHOLD:
			is_charging = true

	if Input.is_action_just_released("attack"):
		if is_charging:
			charge_attack_released = true
		elif attack_hold_time < CHARGE_THRESHOLD:
			attack_triggered = true
		is_charging = false
		attack_hold_time = 0.0

	# 스킬/궁극기/대시
	if Input.is_action_just_pressed("skill"):
		skill_triggered = true
	if Input.is_action_just_pressed("ultimate"):
		ultimate_triggered = true
	if Input.is_action_just_pressed("dodge"):
		shift_triggered = true

	# 이동 입력
	move_input = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): move_input.y -= 1
	if Input.is_physical_key_pressed(KEY_S): move_input.y += 1
	if Input.is_physical_key_pressed(KEY_A): move_input.x -= 1
	if Input.is_physical_key_pressed(KEY_D): move_input.x += 1
	if move_input != Vector2.ZERO:
		move_input = move_input.normalized()

	# 캐릭터 교체
	if Input.is_action_just_pressed("swap_next"):
		swap_triggered = true
		swap_index = -1  # Tab = 순환
	elif Input.is_action_just_pressed("swap_1"):
		swap_triggered = true
		swap_index = 0
	elif Input.is_action_just_pressed("swap_2"):
		swap_triggered = true
		swap_index = 1
	elif Input.is_action_just_pressed("swap_3"):
		swap_triggered = true
		swap_index = 2


func _reset_triggers() -> void:
	attack_triggered       = false
	skill_triggered        = false
	ultimate_triggered     = false
	shift_triggered        = false
	charge_attack_released = false
	swap_triggered         = false
	swap_index             = -1


## InputMap에 필요한 액션 등록
func _setup_input_map() -> void:
	# attack: 마우스 좌클릭 + Space
	_ensure_action("attack")
	var mouse_ev := InputEventMouseButton.new()
	mouse_ev.button_index = MOUSE_BUTTON_LEFT
	if not _action_has_event("attack", mouse_ev):
		InputMap.action_add_event("attack", mouse_ev)
	_ensure_key_action("attack", KEY_SPACE)

	# dodge: Shift + RMB + Period(.)
	_ensure_key_action("dodge", KEY_SHIFT)
	_ensure_key_action("dodge", KEY_PERIOD)
	var rmb_ev := InputEventMouseButton.new()
	rmb_ev.button_index = MOUSE_BUTTON_RIGHT
	if not _action_has_event("dodge", rmb_ev):
		InputMap.action_add_event("dodge", rmb_ev)

	# skill: E
	_ensure_key_action("skill", KEY_E)

	# ultimate: Q
	_ensure_key_action("ultimate", KEY_Q)

	# swap: Tab, 1, 2, 3
	_ensure_key_action("swap_next", KEY_TAB)
	_ensure_key_action("swap_1", KEY_1)
	_ensure_key_action("swap_2", KEY_2)
	_ensure_key_action("swap_3", KEY_3)

	# pause: ESC
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
			if e is InputEventKey and ev is InputEventKey:
				if e.physical_keycode == ev.physical_keycode:
					return true
			elif e is InputEventMouseButton and ev is InputEventMouseButton:
				if e.button_index == ev.button_index:
					return true
	return false
