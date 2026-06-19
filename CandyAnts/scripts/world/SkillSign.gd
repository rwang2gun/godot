class_name SkillSign extends Node2D

# One-shot skill sign for install-style skills. Leaf jump is intentionally excluded:
# it places a reusable LeafJumpPad game object directly instead of a sign.
#
# 설치형(SIGN) 분류 SoT는 SkillAffordance.SKILL_CATEGORY(= Category.SIGN)로 단일화됨(Phase 3).
# 과거 const SIGN_SKILLS 하드코딩 리스트는 제거 — 라우팅은 SkillAffordance.category_of() 파생.

const SIGN_BOARD_TEXTURE: Texture2D = preload("res://assets/sprites/world/skill_sign_board.png")
# 표지판 표시 배율 — 셀 크기의 2배(2026-06-07 요청). 발동 트리거는 개미 점유 셀(x,y) 기준이라 시각만 커지고 게임플레이는 불변.
const DISPLAY_SCALE: float = 2.0
# 보드 텍스처 내 패널(글씨칸) 영역 — skill_sign_board.png 크림 내부 측정값(2026-06-07): 24×15px, 중심 y −0.188(보드 중심 기준).
# 아이콘이 패널 밖으로 넘치지 않도록 이 비율에 맞춘다. 정사각 아이콘이라 패널 높이(15px)가 한계 → FRAC 0.30(0.30×48≈14.4<15).
# SIGN 커서 합성(SkillToolbar._sign_cursor_texture)도 이 상수를 공유해 동일 배치.
const PANEL_ICON_FRAC: float = 0.30             # 아이콘 변 길이 ÷ 보드 폭
const PANEL_ICON_CENTER_Y_FRAC: float = -0.188  # 아이콘 중심 y ÷ 보드 높이 (패널 중심)
# 기둥 밑동을 surface 위 가장자리에 딱 붙이지 않고 지면 안으로 살짝 묻어 "꽂힌" 느낌을 준다(2026-06-07 요청).
# z_index=120이라 지형 위에 그려져 기둥·그림자가 surface 타일을 덮는다. 발동은 개미 셀(x,y) 기준이라 시각만 변함.
const EMBED_DEPTH_FRAC: float = 0.40            # surface 안으로 내릴 깊이 ÷ 셀

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
	# 2배로 키우되 바닥을 surface 위 가장자리에 맞춘 뒤(lift) embed만큼 지면 안으로 내려 겹치게 한다.
	var lift: float = float(cs) * (DISPLAY_SCALE - 1.0) / 2.0
	var embed: float = float(cs) * EMBED_DEPTH_FRAC
	var board_center_y: float = -lift + embed   # 보드 로컬 중심 y (셀 중심 기준)
	var board_h: float = float(cs) * DISPLAY_SCALE
	var board := Sprite2D.new()
	board.texture = SIGN_BOARD_TEXTURE
	board.scale = Vector2.ONE * (float(cs) * DISPLAY_SCALE / float(SIGN_BOARD_TEXTURE.get_width()))
	board.position = Vector2(0, board_center_y)
	add_child(board)

	var icon_tex: Texture2D = load("res://assets/icons/skills/%s.png" % skill_id) as Texture2D
	if icon_tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = icon_tex
	var w: float = float(icon_tex.get_width())
	if w > 0.0:
		# 아이콘을 보드 패널 안에 맞춘다 — 패널 높이가 한계라 PANEL_ICON_FRAC(0.30)로 축소(넘침 방지).
		spr.scale = Vector2.ONE * (float(cs) * DISPLAY_SCALE * PANEL_ICON_FRAC / w)
	# 아이콘 중심 = 보드 중심 + 패널 중심 fraction.
	spr.position = Vector2(0, board_center_y + board_h * PANEL_ICON_CENTER_Y_FRAC)
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
		# 발동 피드백 — 설치형 스킬이 지나가는 개미에 실제 적용되는 순간.
		EventBus.sfx_request.emit(&"skill_activate")
		queue_free()
		return

func _ant_at_cell(a: Ant) -> bool:
	if not a.is_on_floor():
		return false
	var cs: int = _terrain.cell_size
	# x(열)뿐 아니라 y(층)도 일치해야 발동. x만 보면 같은 열의 **위층 발판**에 선 개미가 아래층 표지판을
	# 오발동시킨다(다층 버그). 표지판 cell은 SignPlacement._ground_cell이 "발판 위 빈 셀"로 스냅한 것이라
	# 개미가 그 위에 설 때 floor(ant_y/cs)==cell.y가 성립(설치-발동 대칭).
	if int(floor(a.global_position.x / cs)) != cell.x:
		return false
	return int(floor(a.global_position.y / cs)) == cell.y
