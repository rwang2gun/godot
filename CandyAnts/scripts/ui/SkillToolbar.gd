class_name SkillToolbar extends CanvasLayer

# Phase 11 rewrite (plan v2 §4.1). 동적 Button.new() + stylebox override 제거 →
# SkillSlot atom 인스턴스화 + atom 메서드(set_count/set_selected/set_disabled_state) 호출.
# EventBus.action_triggered 구독 + 커스텀 마우스 커서 + _try_assign + _find_closest_ant는 무변경.
# group("skill_toolbars") 등록 폐기 (codex v1 HIGH-2: StageRunner direct ref로 라우팅).
# EventBus connect/disconnect lifecycle guard 추가 (codex v1 MED-3).

const GameAction := preload("res://scripts/input/GameAction.gd")
const SkillSlotScene: PackedScene = preload("res://scenes/ui/atoms/SkillSlot.tscn")
const CLICK_RADIUS: float = 48.0
# 스킬 선택 시 커스텀 마우스 커서 배율. Input.set_custom_mouse_cursor는 노드 scale을 무시하고
# 텍스처 원본 px를 그대로 OS 커서로 그린다(128px 원본 → 화면 128px). 그래서 다운스케일한
# ImageTexture를 넘겨 크기를 줄인다. 0.5 = 50% 축소.
const CURSOR_SCALE: float = 0.5

# Registered skill PNG icons — reused by SkillSlot.icon_texture and the custom mouse cursor.
const ICONS: Dictionary = {
	"blocker": preload("res://assets/icons/skills/blocker.png"),
	"builder": preload("res://assets/icons/skills/builder.png"),
	"climber": preload("res://assets/icons/skills/climber.png"),
	"floater": preload("res://assets/icons/skills/floater.png"),
	"sand_mound": preload("res://assets/icons/skills/sand_mound.png"),
	"bridge": preload("res://assets/icons/skills/bridge.png"),
	"basher": preload("res://assets/icons/skills/basher.png"),
	"digger": preload("res://assets/icons/skills/digger.png"),
	"cutter": preload("res://assets/icons/skills/cutter.png"),
}
const CURSOR_ICONS: Dictionary = {
	"blocker": preload("res://assets/icons/skills/cursors/blocker.png"),
	"builder": preload("res://assets/icons/skills/cursors/builder.png"),
	"climber": preload("res://assets/icons/skills/cursors/climber.png"),
	"floater": preload("res://assets/icons/skills/cursors/floater.png"),
	"sand_mound": preload("res://assets/icons/skills/cursors/sand_mound.png"),
	"bridge": preload("res://assets/icons/skills/cursors/bridge.png"),
	"basher": preload("res://assets/icons/skills/cursors/basher.png"),
	"digger": preload("res://assets/icons/skills/cursors/digger.png"),
	"cutter": preload("res://assets/icons/skills/cursors/cutter.png"),
}
# 스킬 한글 라벨은 Strings 오토로드로 이관(2026-06-02). Strings.skill_label(id) 사용.

@export var stage_data: StageData = null
@export var hbox_path: NodePath

var _pending_skill_id: String = ""
var _inventory: Dictionary = {}     # id (String) → count (int)
var _slots: Dictionary = {}         # id (String) → SkillSlot
var _all_disabled: bool = false
var _scaled_cursor_cache: Dictionary = {}   # id (String) → ImageTexture (CURSOR_SCALE 축소본, 1회 생성 캐시)

func _ready() -> void:
	if stage_data == null:
		push_warning("[SkillToolbar] stage_data null — toolbar empty")
		return
	_inventory = stage_data.skill_inventory.duplicate(true)
	var hbox: Node = get_node_or_null(hbox_path)
	if hbox == null:
		push_error("[SkillToolbar] hbox_path missing")
		return
	var i: int = 0
	for id: String in stage_data.available_skills:
		var slot: SkillSlot = SkillSlotScene.instantiate()
		slot.skill_id = StringName(id)
		slot.hotkey = str(i + 1)
		slot.ko_label = Strings.skill_label(id)
		slot.icon_texture = ICONS.get(id) as Texture2D
		hbox.add_child(slot)
		slot.set_count(int(_inventory.get(id, 0)))
		var captured_id: String = id
		slot.pressed.connect(func() -> void: _on_slot_pressed(captured_id))
		_slots[id] = slot
		i += 1
	if not EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.connect(_on_action)

func _exit_tree() -> void:
	# Toolbar 해제 시 OS 커서가 마지막 스킬 아이콘으로 남는 것 방지 — 멱등.
	Input.set_custom_mouse_cursor(null)
	if EventBus.action_triggered.is_connected(_on_action):
		EventBus.action_triggered.disconnect(_on_action)

# StageRunner._disable_toolbar가 직접 호출 (group lookup 폐기, codex v1 HIGH-2).
# SkillSlot.set_disabled_state 사용 — Button.disabled 직접 대입 금지 (alpha 0.55 visual refresh 보장).
func set_all_disabled(b: bool) -> void:
	_all_disabled = b
	for id: String in _slots:
		(_slots[id] as SkillSlot).set_disabled_state(b)
	if b:
		_clear_selection()

func _on_action(name: StringName, payload: Dictionary) -> void:
	if _all_disabled:
		return
	match name:
		GameAction.SKILL_ASSIGN:
			if not payload.get("position_valid", false):
				return
			_try_assign(payload.get("world_pos", Vector2.ZERO))
		GameAction.SKILL_CANCEL:
			_clear_selection()
		GameAction.SKILL_CYCLE_NEXT:
			_cycle(+1)
		GameAction.SKILL_CYCLE_PREV:
			_cycle(-1)
		_:
			var slot_idx: int = GameAction.SKILL_SELECT_BY_SLOT.find(name)
			if slot_idx >= 0:
				_select_by_slot(slot_idx)

func _on_slot_pressed(id: String) -> void:
	var count: int = int(_inventory.get(id, 0))
	if count <= 0:
		# Phase 21(sound) sound hook 자리 — 현 phase 11에서는 noop.
		return
	if _pending_skill_id == id:
		_clear_selection()
		return
	_select(id)

func _select(id: String) -> void:
	# 다른 슬롯 selected off → 새 슬롯 selected on → 커스텀 커서 교체. _pending_skill_id 단일 SoT.
	if _pending_skill_id != "" and _slots.has(_pending_skill_id):
		(_slots[_pending_skill_id] as SkillSlot).set_selected(false)
	_pending_skill_id = id
	if _slots.has(id):
		(_slots[id] as SkillSlot).set_selected(true)
	var icon: Texture2D = _cursor_texture(id)
	if icon != null:
		# hotspot = (0,0) — 커서 아트의 화살표 tip이 좌상단. 50% 축소해도 tip이 원점이라 그대로 유효.
		Input.set_custom_mouse_cursor(icon, Input.CURSOR_ARROW, Vector2.ZERO)
	print("[SkillToolbar] pending=", id)

# CURSOR_ICONS 원본(128px)을 CURSOR_SCALE만큼 다운스케일한 ImageTexture를 반환(1회 생성 후 캐시).
# set_custom_mouse_cursor가 텍스처 원본 px를 그대로 쓰므로 여기서 줄여야 화면 커서가 작아진다.
func _cursor_texture(id: String) -> Texture2D:
	if _scaled_cursor_cache.has(id):
		return _scaled_cursor_cache[id] as Texture2D
	var src: Texture2D = CURSOR_ICONS.get(id) as Texture2D
	if src == null:
		return null
	var img: Image = src.get_image()
	if img == null:
		return src   # get_image 실패 시 원본 fall-back (커서는 크게 뜨더라도 동작 유지)
	var w: int = maxi(1, int(round(float(img.get_width()) * CURSOR_SCALE)))
	var h: int = maxi(1, int(round(float(img.get_height()) * CURSOR_SCALE)))
	img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_scaled_cursor_cache[id] = tex
	return tex

func _clear_selection() -> void:
	if _pending_skill_id != "" and _slots.has(_pending_skill_id):
		(_slots[_pending_skill_id] as SkillSlot).set_selected(false)
	_pending_skill_id = ""
	Input.set_custom_mouse_cursor(null)

# 클릭(탭) 흐름 — _pending_skill_id(armed)를 커서 위치 개미에 부여.
# ant 미발견(빈 공간 클릭)이면 선택 유지(오클릭 보호), 그 외엔 적용 성공/실패 무관 선택 해제 — 기존 동작 보존.
func _try_assign(world: Vector2) -> void:
	if _pending_skill_id == "":
		return
	var ant: Ant = _find_closest_ant(world)
	if ant == null:
		return
	_apply_skill(_pending_skill_id, ant)
	_clear_selection()

# 드래그앤드롭 drop 경로 — SkillDropZone._drop_data가 호출.
# 클릭 흐름의 _pending_skill_id와 독립: drop은 drag data dict가 운반한 id를 직접 적용한다.
# (월드 드래그를 부여로 오해하지 않도록, 드래그는 반드시 SkillSlot에서 시작해야 데이터가 실린다.)
func try_assign_dragged(id: String, world: Vector2) -> void:
	if _all_disabled:
		return
	var ant: Ant = _find_closest_ant(world)
	if ant == null:
		return
	_apply_skill(id, ant)
	# 드롭으로 적용했으면 기존에 armed돼 있던 선택/커서도 초기화(stale skill 커서 방지).
	_clear_selection()

# id 스킬을 ant에 적용 시도 — 성공 시 인벤토리 차감 + true 반환. 클릭/드롭 공통 코어.
func _apply_skill(id: String, ant: Ant) -> bool:
	if id == "" or not _slots.has(id):
		return false
	if int(_inventory.get(id, 0)) <= 0:
		return false
	var skill_script: Script = SkillRegistry.get_skill(id)
	if skill_script == null:
		return false
	var skill: Skill = skill_script.new() as Skill
	if skill == null or not skill.can_apply(ant):
		return false
	skill.apply(ant)
	_inventory[id] = int(_inventory[id]) - 1
	(_slots[id] as SkillSlot).set_count(int(_inventory[id]))
	print("[SkillToolbar] applied=", id, " to=", ant.name, " remaining=", _inventory[id])
	return true

func _select_by_slot(slot_idx: int) -> void:
	if stage_data == null:
		return
	if slot_idx < 0 or slot_idx >= stage_data.available_skills.size():
		return
	_on_slot_pressed(stage_data.available_skills[slot_idx])

func _cycle(step: int) -> void:
	if stage_data == null or stage_data.available_skills.is_empty():
		return
	var ids: Array = stage_data.available_skills
	var cur: int = ids.find(_pending_skill_id) if _pending_skill_id != "" else -1
	var next_idx: int = posmod(cur + step, ids.size())
	_on_slot_pressed(ids[next_idx])

func _find_closest_ant(world: Vector2) -> Ant:
	# Phase 15 impl Round 2 F-impl-R2-1 MEDIUM 대응 — terminal state(Settled/Saved/Dead) ant는
	# is_alive()=false → 클릭 타겟팅 후보에서 제외. settled distributor가 marker 위에 visible로
	# 남아있어도 valid follower의 skill assign을 shadow하지 않도록 보장.
	var ants: Array = get_tree().get_nodes_in_group("ants")
	var closest: Ant = null
	var best: float = CLICK_RADIUS
	for n in ants:
		var a: Ant = n as Ant
		if a == null:
			continue
		if not a.is_alive():
			continue
		var d: float = a.global_position.distance_to(world)
		if d < best:
			best = d
			closest = a
	return closest
