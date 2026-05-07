class_name CharacterWM
extends CharacterBase

## =====================================================================
##  CharacterWM — 마법사 (Wand Mage)
##  원거리 콤보 4단, 소용돌이/스윕 특수기
## =====================================================================


func _ready() -> void:
	# 스탯 override
	MAX_SPEED    = 5.5
	ACCELERATION = 12.0
	ATTACK_RANGE = 3.0
	ATTACK_ANGLE = PI / 4.0
	COMBO_MAX    = 4
	DASH_SPEED   = 8.0

	# 포즈 매핑 (WM 전용)
	pose_map = {
		"idle": "wm_idle", "battle_idle": "wm_battle_idle",
		"combo1": "wm_combo1", "combo2": "wm_combo2",
		"combo3a": "wm_combo3", "combo3b": "wm_combo3", "combo4": "wm_combo4",
		"dash": "wm_dash", "hurt": "hurt",
		"skill_cast": "wm_skill",
		"ult_windup": "wm_ult_charge", "ult_strike": "wm_ult_charge",
		"shoulder_bash": "wm_charge_windup", "walk1": "wm_idle",
		"charge_windup": "wm_charge_windup", "charge_slam": "wm_charge_fire",
	}

	super()

	# Wand 빌드 (손잡이 + orb) — HTML buildWand 이식
	_build_wand()


func _build_wand() -> void:
	var wrist: Node3D = parts["right_arm"]["wrist"]
	var wand_group: Node3D = Node3D.new()
	wand_group.name = "Wand"

	# 손잡이 (금색 원통) — HTML은 Cylinder, 여기선 얇은 box로 대체
	var handle_mat: StandardMaterial3D = _make_mat(Color(1.0, 0.84, 0.0))
	var handle_size: Vector3 = Vector3(0.03, 0.55, 0.03)
	var handle: MeshInstance3D = MeshInstance3D.new()
	var handle_mesh: BoxMesh = BoxMesh.new()
	handle_mesh.size = handle_size
	handle.mesh = handle_mesh
	handle.material_override = handle_mat
	# Z방향으로 뻗도록: position z=-0.275 (전방), 세로 축이 z를 향하도록 회전
	handle.rotation = Vector3(PI / 2.0, 0, 0)
	handle.position = Vector3(0, -0.035, -0.275)
	wand_group.add_child(handle)

	# 끝 보석 (orb)
	var orb_mat: StandardMaterial3D = _make_mat(Color(0.67, 0.67, 0.8))
	orb_mat.emission_enabled = true
	orb_mat.emission = Color(0.0, 0.33, 0.8)
	orb_mat.emission_energy_multiplier = 0.0  # 기본 비활성
	var orb: MeshInstance3D = MeshInstance3D.new()
	var orb_mesh: BoxMesh = BoxMesh.new()
	orb_mesh.size = Vector3(0.08, 0.08, 0.08)
	orb.mesh = orb_mesh
	orb.material_override = orb_mat
	orb.rotation = Vector3(0, PI / 4.0, 0)
	orb.position = Vector3(0, -0.035, -0.58)
	wand_group.add_child(orb)

	wrist.add_child(wand_group)
	parts["wand"] = wand_group
	parts["wand_orb_mat"] = orb_mat

	# 기본 sword는 완전히 숨김 (base에서 scale 0.001이지만 명시적으로)
	if parts.has("sword"):
		var sword: MeshInstance3D = parts["sword"]
		sword.visible = false


## 머티리얼 오버라이드 — 보라 마법사
func _init_materials() -> void:
	mat_chest  = _make_mat(Color(0.4, 0.15, 0.6))
	mat_waist  = _make_mat(Color(0.3, 0.1, 0.45))
	mat_pelvis = _make_mat(Color(0.35, 0.12, 0.5))
	mat_skin   = _make_mat(Color(1.0, 0.86, 0.67))
	mat_hair   = _make_mat(Color(0.9, 0.85, 0.7))
	mat_right  = _make_mat(Color(0.5, 0.2, 0.7))
	mat_left   = _make_mat(Color(0.5, 0.2, 0.7))
