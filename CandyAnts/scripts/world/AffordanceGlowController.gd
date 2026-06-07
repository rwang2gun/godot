class_name AffordanceGlowController
extends Node2D

# 스킬 선택 시 "어디를 탭하나"를 글로우로 표시 (STAGE_GUIDE_PLAN §0.8.1~§0.8.3, Phase 2).
# 글로우 대상은 카테고리 SoT(SkillAffordance)에서 파생 — 스킬 id 하드코딩 없음:
#   - ANT_ARMED(③)/ANT_SETTLE(②) → 적격 개미(is_alive && can_apply) 스프라이트 글로우.
#   - SIGN(①)/DEVICE(④)          → 커서 아래 valid surface 셀 글로우(SignPlacement 파생).
# 폴링 패턴은 PlacementPreview 답습(toolbar._pending_skill_id + 커서). 부적격은 무표시.

const ANT_SPRITE_NODE := "Sprite"                    # Ant.tscn의 시각 노드(AnimatedSprite2D)
const ANT_GLOW_COLOR: Color = Tokens.GRAPE_700       # 개미 = 포도(보라). 레몬은 파스텔 배경에 묻혀 교체(2026-06-07 요청)
# 캐릭터(검정)와 보라 글로우가 붙으면 경계가 안 보여 → 캐릭터에 닿는 안쪽 띠를 흰색으로 분리(2026-06-07 요청).
const ANT_GLOW_INNER_COLOR: Color = Color.WHITE
const ANT_GLOW_INNER_RATIO: float = 0.45             # 전체 외곽선 중 안쪽 흰 띠 비율
const SURFACE_GLOW_COLOR: Color = Tokens.MINT_500    # 타일 = 민트(개미와 시각 구분)
const SURFACE_BORDER_RATIO: float = 0.10
# 개미 외곽선 글로우 화면 목표 두께(px). outline_width는 텍셀 단위 + 개미 스프라이트가 scale 0.24로 축소
# 표시돼 2텍셀이면 화면 0.5px(거의 안 보임) → 화면 px ÷ scale 로 환산해 굵게 넘긴다(2026-06-07 요청).
const ANT_GLOW_SCREEN_PX: float = 3.5

@export var toolbar_path: NodePath
@export var terrain_path: NodePath

var _toolbar: SkillToolbar = null
var _terrain: Terrain = null
var _glowing_ants: Dictionary = {}     # instance_id → Ant (현재 글로우 적용 중)
var _surface_marker: Sprite2D = null

func _ready() -> void:
	_toolbar = get_node_or_null(toolbar_path) as SkillToolbar
	_terrain = get_node_or_null(terrain_path) as Terrain
	z_index = 90

func _process(_delta: float) -> void:
	refresh(get_global_mouse_position())

# 런타임/테스트 공통 진입 — 주어진 커서 위치 기준으로 글로우 갱신.
func refresh(cursor_world: Vector2) -> void:
	if _toolbar == null:
		_clear_all()
		return
	var pending: String = _toolbar._pending_skill_id
	if pending == "" or not SkillAffordance.SKILL_CATEGORY.has(pending):
		_clear_all()
		return
	match SkillAffordance.glow_target_of(pending):
		SkillAffordance.GlowTarget.ANT:
			_clear_surface()
			_update_ant_glow(pending)
		SkillAffordance.GlowTarget.SURFACE:
			_clear_ant_glow()
			_update_surface_glow(pending, cursor_world)

# --- ANT 글로우 ---

# 적격 개미 = is_alive() && skill.can_apply(ant). (글로우 대상이 ANT인 카테고리에서만 의미.)
func eligible_ants(skill_id: String) -> Array:
	var out: Array = []
	var script: Script = SkillRegistry.get_skill(skill_id)
	if script == null:
		return out
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not a.is_alive():
			continue
		var skill: Skill = script.new() as Skill
		if skill != null and skill.can_apply(a):
			out.append(a)
	return out

func _update_ant_glow(skill_id: String) -> void:
	var elig_ids: Dictionary = {}
	for a in eligible_ants(skill_id):
		elig_ids[a.get_instance_id()] = a
	# 더 이상 적격이 아닌(또는 무효) 개미 글로우 해제.
	for id in _glowing_ants.keys():
		if not elig_ids.has(id):
			_remove_ant_glow(id)
	# 새로 적격인 개미 글로우 적용.
	for id in elig_ids:
		if _glowing_ants.has(id):
			continue
		var a: Ant = elig_ids[id]
		var vis: CanvasItem = a.get_node_or_null(ANT_SPRITE_NODE) as CanvasItem
		if vis != null:
			Glow.apply(vis, ANT_GLOW_COLOR, _ant_glow_width(vis), ANT_GLOW_INNER_COLOR, ANT_GLOW_INNER_RATIO)
			_glowing_ants[id] = a

# 화면 목표 두께(px)를 스프라이트 scale로 나눠 텍셀 단위 outline_width로 환산.
# 개미 Sprite는 scale ≈ 0.24 → 3.5px ÷ 0.24 ≈ 14.6 텍셀. scale 0이면 안전 기본값.
func _ant_glow_width(vis: CanvasItem) -> float:
	var sx: float = absf(vis.scale.x)
	if sx <= 0.0001:
		return 14.0
	return ANT_GLOW_SCREEN_PX / sx

func _remove_ant_glow(id) -> void:
	var a: Ant = _glowing_ants.get(id) as Ant
	if a != null and is_instance_valid(a):
		var vis: CanvasItem = a.get_node_or_null(ANT_SPRITE_NODE) as CanvasItem
		if vis != null:
			Glow.clear(vis)
	_glowing_ants.erase(id)

func _clear_ant_glow() -> void:
	for id in _glowing_ants.keys():
		_remove_ant_glow(id)

# --- SURFACE 글로우 ---

# 커서 위치의 설치 가능 셀(SignPlacement 파생). 실제 배치 규칙과 동일 SoT.
func surface_install_result(skill_id: String, cursor_world: Vector2) -> Dictionary:
	if _terrain == null:
		return {"cell": Vector2i.MAX, "valid": false, "reason": "no_terrain"}
	var parent: Node = _terrain.get_parent()
	return SignPlacement.resolve_surface_install_cell(_terrain, skill_id, cursor_world, parent)

func _update_surface_glow(skill_id: String, cursor_world: Vector2) -> void:
	var res: Dictionary = surface_install_result(skill_id, cursor_world)
	if not res.get("valid", false):
		_clear_surface()
		return
	_ensure_surface_marker()
	var cs: int = _terrain.cell_size
	var cell: Vector2i = res["cell"]
	_surface_marker.position = Vector2(float(cell.x) * cs + cs / 2.0, float(cell.y) * cs + cs / 2.0)
	_surface_marker.visible = true
	Glow.apply(_surface_marker, SURFACE_GLOW_COLOR)

func _ensure_surface_marker() -> void:
	if _surface_marker != null:
		return
	var cs: int = _terrain.cell_size if _terrain != null else 48
	_surface_marker = Sprite2D.new()
	_surface_marker.texture = _make_cell_frame_texture(cs)
	_surface_marker.z_index = 95
	add_child(_surface_marker)

func _clear_surface() -> void:
	if _surface_marker != null:
		Glow.clear(_surface_marker)
		_surface_marker.visible = false

func _clear_all() -> void:
	_clear_ant_glow()
	_clear_surface()

# 셀 테두리 프레임 텍스처(테두리 불투명·중앙 투명) → outline 셰이더가 테두리를 글로우.
# 셰이더가 동작하지 않아도(헤드리스) 프레임 자체가 셀 강조로 읽힌다.
func _make_cell_frame_texture(cs: int) -> Texture2D:
	var border: int = maxi(2, int(round(float(cs) * SURFACE_BORDER_RATIO)))
	var img := Image.create(cs, cs, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	for y: int in cs:
		for x: int in cs:
			if x < border or x >= cs - border or y < border or y >= cs - border:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)
