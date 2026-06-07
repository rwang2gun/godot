class_name SkillSign extends Node2D

# One-shot skill sign for install-style skills. Leaf jump is intentionally excluded:
# it places a reusable LeafJumpPad game object directly instead of a sign.
#
# 설치형(SIGN) 분류 SoT는 SkillAffordance.SKILL_CATEGORY(= Category.SIGN)로 단일화됨(Phase 3).
# 과거 const SIGN_SKILLS 하드코딩 리스트는 제거 — 라우팅은 SkillAffordance.category_of() 파생.

const SIGN_BOARD_TEXTURE: Texture2D = preload("res://assets/sprites/world/skill_sign_board.png")

var skill_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var _terrain: Terrain = null

func setup(p_skill_id: String, p_cell: Vector2i, p_terrain: Terrain) -> void:
	skill_id = p_skill_id
	cell = p_cell
	_terrain = p_terrain

func _ready() -> void:
	z_index = 120
	if _terrain != null:
		var cs: int = _terrain.cell_size
		global_position = Vector2(
			float(cell.x) * cs + cs / 2.0,
			float(cell.y) * cs + cs / 2.0
		)
	_build_visual()

func _build_visual() -> void:
	var cs: int = _terrain.cell_size if _terrain != null else 48
	var board := Sprite2D.new()
	board.texture = SIGN_BOARD_TEXTURE
	board.scale = Vector2.ONE * (float(cs) / float(SIGN_BOARD_TEXTURE.get_width()))
	add_child(board)

	var icon_tex: Texture2D = load("res://assets/icons/skills/%s.png" % skill_id) as Texture2D
	if icon_tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = icon_tex
	var w: float = float(icon_tex.get_width())
	if w > 0.0:
		# 아이콘을 보드 위에 얹는 스케일 — 기존 0.30의 2배(0.60)로 키워 가독성 향상.
		spr.scale = Vector2.ONE * (float(cs) * 0.60 / w)
	spr.position = Vector2(0, -float(cs) * 0.23)
	add_child(spr)

func _physics_process(_delta: float) -> void:
	if _terrain == null or skill_id == "":
		return
	var skill_script: Script = SkillRegistry.get_skill(skill_id)
	if skill_script == null:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not a.is_alive():
			continue
		if not _ant_at_cell(a):
			continue
		var skill: Skill = skill_script.new() as Skill
		if skill == null or not skill.can_apply(a):
			continue
		skill.apply(a)
		queue_free()
		return

func _ant_at_cell(a: Ant) -> bool:
	if not a.is_on_floor():
		return false
	var cs: int = _terrain.cell_size
	return int(floor(a.global_position.x / cs)) == cell.x
