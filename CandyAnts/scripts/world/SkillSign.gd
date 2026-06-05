class_name SkillSign extends Node2D

# 발동 표지판 (2026-06-05 프로토타입) — 설치형 스킬을 "지나가는 개미를 빠르게 탭" 대신
# 타일에 표지판으로 설치하고, 그 셀(column)에 처음 도착한 적격 개미가 자동 발동하게 한다.
# basher/cutter/sand_mound의 "빠른 탭" 난이도 완화용. 세 스킬 모두 표지판화 완료.
#
# 스킬별 발동 의미:
#  - sand_mound: 표지판 자리(빈 바닥 셀)에서 그대로 막대과자 사다리 건설.
#  - basher: "흙벽 앞 셀"에 설치 → 도착 개미에 BasherSkill.apply. apply가 전방 열림이면 armed,
#    전방이 벽이면 즉시 굴착 분기를 이미 처리하므로(armed 시 WalkerState가 벽 도달 시 자동 굴착)
#    표지판은 skill.apply만 호출하면 된다 (벽 직전/직면 어디에 설치해도 동작).
#  - cutter: "식물벽 앞 셀"에 설치 → CutterSkill.apply가 basher와 대칭(전방 열림→armed, 식물벽
#    직면→즉시 절단). 동일하게 skill.apply만 호출하면 된다.
#
# 부여(인벤토리 차감)는 설치 시점(SkillToolbar._place_sign)에 이뤄지고, 표지판은 발동 시점에
# can_apply 재검사 후 skill.apply를 직접 호출한다(움직이는 개미 탭과 동일한 can_apply 게이트 공유).

const SIGN_SKILLS: Array[String] = ["sand_mound", "basher", "cutter", "leaf_jump"]
# 재사용형 표지판 — 발동해도 소비(queue_free)하지 않고 남아, 도착하는 모든 적격 개미가 반복 발동한다.
# 나뭇잎 점프대(leaf_jump): 끈끈이 직전에 한 번 세워두면 무리 전체가 끈끈이를 넘어간다. 발동 개미는
# 즉시 전방으로 홉해 표지판 열을 벗어나므로(같은 frame 재발동·무한 루프 없음) 별도 쿨다운이 불필요.
const REUSABLE_SIGNS: Array[String] = ["leaf_jump"]

var skill_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var _terrain: Terrain = null

func setup(p_skill_id: String, p_cell: Vector2i, p_terrain: Terrain) -> void:
	skill_id = p_skill_id
	cell = p_cell
	_terrain = p_terrain

func _ready() -> void:
	z_index = 120   # 타일/개미 위에 표시
	if _terrain != null:
		var cs: int = _terrain.cell_size
		global_position = Vector2(
			float(cell.x) * cs + cs / 2.0,
			float(cell.y) * cs + cs / 2.0
		)
	_build_visual()

# 프로토타입용 단순 표식 — 폴 + 스킬 아이콘. 정식 Phase에서 전용 스프라이트로 교체 예정.
func _build_visual() -> void:
	var cs: int = _terrain.cell_size if _terrain != null else 48
	var pole := Line2D.new()
	pole.add_point(Vector2(0, float(cs) / 2.0))
	pole.add_point(Vector2(0, -float(cs)))
	pole.width = 3.0
	pole.default_color = Color(0.25, 0.18, 0.11)
	add_child(pole)
	# leaf_jump은 전용 아이콘 PNG가 아직 없어(전용 스프라이트 후속 Phase) 간단한 잎사귀 도형으로 표식.
	if skill_id == "leaf_jump":
		_add_leaf_visual(cs)
		return
	var icon_tex: Texture2D = load("res://assets/icons/skills/%s.png" % skill_id) as Texture2D
	if icon_tex != null:
		var spr := Sprite2D.new()
		spr.texture = icon_tex
		var w: float = float(icon_tex.get_width())
		if w > 0.0:
			spr.scale = Vector2.ONE * (float(cs) * 0.7 / w)
		spr.position = Vector2(0, -float(cs) * 1.3)
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
		# 첫 "적격" 개미만 발동 — 운반 중/미보행 등 can_apply 불충족 개미는 통과시키고 다음 개미를 기다린다.
		if skill == null or not skill.can_apply(a):
			continue
		skill.apply(a)
		# 재사용형 점프대는 소비하지 않고 남아 도착하는 모든 적격 개미가 반복 발동(무리 통행).
		# 일반 설치형(sand_mound/basher/cutter)은 첫 발동 후 소비. 어느 쪽이든 한 frame 1마리만 처리.
		if not REUSABLE_SIGNS.has(skill_id):
			queue_free()
		return

# 나뭇잎 점프대 프로토타입 표식 — 폴 위에 잎사귀 도형(Polygon2D) + 잎맥(Line2D). 전용 스프라이트는 후속.
func _add_leaf_visual(cs: int) -> void:
	var s: float = float(cs) * 0.5
	var leaf := Polygon2D.new()
	# 위로 뾰족한 잎(원점=폴 상단 근처). 좌우 대칭 마름모를 살짝 잎 모양으로.
	leaf.polygon = PackedVector2Array([
		Vector2(0.0, -s * 1.7),
		Vector2(s * 0.55, -s * 0.9),
		Vector2(0.0, -s * 0.1),
		Vector2(-s * 0.55, -s * 0.9),
	])
	leaf.color = Color(0.32, 0.72, 0.30)
	add_child(leaf)
	var vein := Line2D.new()
	vein.add_point(Vector2(0.0, -s * 0.1))
	vein.add_point(Vector2(0.0, -s * 1.7))
	vein.width = 2.0
	vein.default_color = Color(0.18, 0.45, 0.18)
	add_child(vein)

# 개미가 표지판 셀(열)에 도달했는지 — 같은 x 열 + 바닥 위. 같은 열을 여러 frame 점유하므로
# 정확 x 일치로 안정적으로 포착된다. (다층 지형 동일 열 height 구분은 정식 Phase에서 보강.)
func _ant_at_cell(a: Ant) -> bool:
	if not a.is_on_floor():
		return false
	var cs: int = _terrain.cell_size
	return int(floor(a.global_position.x / cs)) == cell.x
