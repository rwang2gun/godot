class_name LeafJumpPad extends Node2D

# Reusable leaf jump pad placed directly on the terrain cell.
# Unlike SkillSign, this is the game object itself: ants trigger it when entering its column.

const PAD_TEXTURE: Texture2D = preload("res://assets/sprites/terrain/leaf_jump_pad.png")
const PAD_PRESSED_TEXTURE: Texture2D = preload("res://assets/sprites/terrain/leaf_jump_pad_pressed.png")
const PAD_SPRUNG_TEXTURE: Texture2D = preload("res://assets/sprites/terrain/leaf_jump_pad_sprung.png")
const CHARGE_TIME: float = 0.25

var cell: Vector2i = Vector2i.ZERO
var _terrain: Terrain = null

enum _Phase { IDLE, CHARGING, SPRUNG }
var _phase: int = _Phase.IDLE
var _active_ant: Ant = null
var _sprite: Sprite2D = null

func setup(p_cell: Vector2i, p_terrain: Terrain) -> void:
	cell = p_cell
	_terrain = p_terrain

func _ready() -> void:
	z_index = 115
	if _terrain != null:
		var cs: int = _terrain.cell_size
		global_position = Vector2(
			float(cell.x) * cs + cs / 2.0,
			float(cell.y) * cs + cs / 2.0
		)
	_build_visual()

func _build_visual() -> void:
	var cs: int = _terrain.cell_size if _terrain != null else 48
	_sprite = Sprite2D.new()
	_sprite.texture = PAD_TEXTURE
	var w: float = float(PAD_TEXTURE.get_width())
	if w > 0.0:
		_sprite.scale = Vector2.ONE * (float(cs) / w)
	add_child(_sprite)

func _physics_process(_delta: float) -> void:
	if _terrain == null:
		return
	match _phase:
		_Phase.IDLE:
			_try_trigger()
		_Phase.CHARGING:
			_watch_charge()
		_Phase.SPRUNG:
			_watch_sprung()

func _try_trigger() -> void:
	var skill_script: Script = SkillRegistry.get_skill("leaf_jump")
	if skill_script == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not a.is_alive() or a.state_machine == null:
			continue
		if not _ant_at_cell(a):
			continue
		var skill: Skill = skill_script.new() as Skill
		if skill == null or not skill.can_apply(a):
			continue
		_active_ant = a
		_set_texture(PAD_PRESSED_TEXTURE)
		a.state_machine.change_state(LeafChargeState.new(LeafJumpSkill.LEAF_JUMP_CELLS, CHARGE_TIME))
		# 발동 피드백 — 장치가 지나가는 개미를 점프 충전 상태로 트리거하는 순간.
		EventBus.sfx_request.emit(&"skill_activate")
		_phase = _Phase.CHARGING
		return

func _watch_charge() -> void:
	if not _active_ant_valid():
		_reset()
		return
	var state: AntState = _active_ant.state_machine.current_state
	if state is LeafJumpState:
		_set_texture(PAD_SPRUNG_TEXTURE)
		_phase = _Phase.SPRUNG
	elif not (state is LeafChargeState):
		_reset()

func _watch_sprung() -> void:
	if not _active_ant_valid():
		_reset()
		return
	var state: AntState = _active_ant.state_machine.current_state
	if not (state is LeafJumpState) and not _ant_at_cell(_active_ant):
		_reset()

func _active_ant_valid() -> bool:
	return (
		_active_ant != null and is_instance_valid(_active_ant)
		and _active_ant.is_alive() and _active_ant.state_machine != null
	)

func _reset() -> void:
	_active_ant = null
	_phase = _Phase.IDLE
	_set_texture(PAD_TEXTURE)

func _set_texture(tex: Texture2D) -> void:
	if _sprite != null:
		_sprite.texture = tex

func _ant_at_cell(a: Ant) -> bool:
	if not a.is_on_floor():
		return false
	var cs: int = _terrain.cell_size
	return int(floor(a.global_position.x / cs)) == cell.x
