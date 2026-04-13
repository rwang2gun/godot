class_name CharacterBase
extends CharacterBody3D

## =====================================================================
##  CharacterBase — HTML CharacterFS 대응
##  Node3D 계층으로 스켈레톤을 구축하고 PoseSystem으로 포즈 적용
## =====================================================================

# --- 치수 (HTML buildGeometry 원본 값) ---
const HEAD_H   := 0.23
const HEAD_W   := 0.19
const HEAD_D   := 0.21
const CHEST_H  := 0.25
const CHEST_W  := 0.33
const CHEST_D  := 0.20
const WAIST_H  := 0.14
const WAIST_W  := 0.22
const WAIST_D  := 0.16
const PELVIS_H := 0.19
const PELVIS_W := 0.30
const PELVIS_D := 0.22
const THIGH_L  := 0.30
const CALF_L   := 0.50
const LEG_H    := THIGH_L + CALF_L  # 0.8
const THIGH_W  := 0.16
const CALF_W   := 0.11
const ARM_W    := 0.08
const UPPER_ARM_L := 0.32
const FOREARM_L   := 0.35
const HAND_S   := 0.07

# --- 머티리얼 색상 (서브클래스에서 오버라이드 가능) ---
var mat_chest: StandardMaterial3D
var mat_waist: StandardMaterial3D
var mat_pelvis: StandardMaterial3D
var mat_skin: StandardMaterial3D
var mat_hair: StandardMaterial3D
var mat_right: StandardMaterial3D
var mat_left: StandardMaterial3D

# --- PoseSystem ---
var pose_system: PoseSystem = PoseSystem.new()
var parts: Dictionary = {}

# --- 현재 포즈 ---
var current_pose: Dictionary = PoseData.POSES["idle"]
var pose_speed: float = 10.0

# --- Pivot (facing 회전용, 스켈레톤의 부모) ---
var pivot: Node3D


func _ready() -> void:
	_init_materials()
	_build_skeleton()
	# 초기 포즈 즉시 적용 (보간 없이)
	pose_system.apply_pose(parts, current_pose, 999.0, 1.0)


func _physics_process(delta: float) -> void:
	pose_system.apply_pose(parts, current_pose, pose_speed, delta)


## 포즈 전환
func set_pose(pose_name: String, speed: float = 10.0) -> void:
	if PoseData.POSES.has(pose_name):
		current_pose = PoseData.POSES[pose_name]
		pose_speed = speed


# =====================================================================
#  머티리얼 초기화 — 서브클래스에서 오버라이드하여 색상 변경
# =====================================================================
func _init_materials() -> void:
	mat_chest = _make_mat(Color(0.29, 0.29, 0.29))   # 0x4a4a4a
	mat_waist = _make_mat(Color(0.2, 0.2, 0.2))      # 0x333333
	mat_pelvis = _make_mat(Color(0.29, 0.29, 0.29))   # 0x4a4a4a
	mat_skin = _make_mat(Color(1.0, 0.86, 0.67))      # 0xffdbac
	mat_hair = _make_mat(Color(1.0, 0.2, 0.0))        # 0xff3300
	mat_right = _make_mat(Color(0.91, 0.12, 0.39))    # 0xe91e63
	mat_left = _make_mat(Color(0.13, 0.59, 0.95))     # 0x2196f3


func _make_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m


# =====================================================================
#  스켈레톤 구축 — HTML buildGeometry() 1:1 이식 (좌표 변환 적용)
# =====================================================================
func _build_skeleton() -> void:
	# Pivot (facing 회전용)
	pivot = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)

	# Root (position.y = legH)
	var root := _make_joint("Root")
	root.position.y = LEG_H
	pivot.add_child(root)
	parts["root"] = root

	# Pelvis mesh
	_add_box(root, Vector3(PELVIS_W, PELVIS_H, PELVIS_D), Vector3(0, PELVIS_H / 2.0, 0), mat_pelvis)

	# Waist joint
	var waist := _make_joint("Waist")
	waist.position.y = PELVIS_H
	root.add_child(waist)
	parts["waist"] = waist
	_add_box(waist, Vector3(WAIST_W, WAIST_H, WAIST_D), Vector3(0, WAIST_H / 2.0, 0), mat_waist)

	# Chest joint
	var chest := _make_joint("Chest")
	chest.position.y = WAIST_H
	waist.add_child(chest)
	parts["chest"] = chest
	_add_box(chest, Vector3(CHEST_W, CHEST_H, CHEST_D), Vector3(0, CHEST_H / 2.0, 0), mat_chest)

	# Neck → Head
	var neck := _make_joint("Neck")
	neck.position.y = CHEST_H
	chest.add_child(neck)

	var head_mesh := _add_box(neck, Vector3(HEAD_W, HEAD_H, HEAD_D), Vector3(0, HEAD_H / 2.0 + 0.03, 0), mat_skin)

	# Nose (Z 반전: +headD/2+0.02 → -(headD/2+0.02))
	var nose := _add_box(head_mesh, Vector3(0.04, 0.04, 0.04), Vector3(0, -0.02, -(HEAD_D / 2.0 + 0.02)), _make_mat(Color(0, 1, 0)))
	nose.visible = false
	parts["nose"] = nose

	# Hair
	_add_box(head_mesh, Vector3(HEAD_W + 0.04, 0.06, HEAD_D + 0.04), Vector3(0, HEAD_H / 2.0 + 0.01, 0), mat_hair)
	_add_box(head_mesh, Vector3(HEAD_W + 0.04, 0.1, 0.05), Vector3(0, HEAD_H / 2.0 - 0.03, -(HEAD_D / 2.0 + 0.02)), mat_hair)
	_add_box(head_mesh, Vector3(HEAD_W + 0.03, 0.38, 0.08), Vector3(0, -0.05, HEAD_D / 2.0 + 0.02), mat_hair)
	_add_box(head_mesh, Vector3(0.03, 0.2, 0.1), Vector3(HEAD_W / 2.0 + 0.02, 0.03, 0.04), mat_hair)
	_add_box(head_mesh, Vector3(0.03, 0.2, 0.1), Vector3(-(HEAD_W / 2.0 + 0.02), 0.03, 0.04), mat_hair)

	# Arms
	parts["right_arm"] = _create_arm(chest, true)
	parts["left_arm"] = _create_arm(chest, false)

	# Sword (right wrist, Z 반전: +0.6 → -0.6)
	var sword := _add_box(parts["right_arm"]["wrist"], Vector3(0.04, 0.04, 1.2), Vector3(0, -HAND_S / 2.0, -0.6), _make_mat(Color(0.8, 0.8, 0.8)))
	sword.visible = false
	sword.scale = Vector3(0.001, 0.001, 0.001)
	parts["sword"] = sword

	# Legs
	parts["right_leg"] = _create_leg(root, true)
	parts["left_leg"] = _create_leg(root, false)


func _create_arm(parent: Node3D, is_right: bool) -> Dictionary:
	# X 반전: Three.js side=-1(right) → Godot +0.23
	var side_x: float = 0.23 if is_right else -0.23
	var mat: StandardMaterial3D = mat_right if is_right else mat_left
	var group_name: String = "RightArm" if is_right else "LeftArm"
	var prefix: String = "R_" if is_right else "L_"

	# 중간 그룹 노드
	var arm_group := Node3D.new()
	arm_group.name = group_name
	parent.add_child(arm_group)

	var shoulder := _make_joint(prefix + "Shoulder")
	shoulder.position = Vector3(side_x, CHEST_H * 0.8, 0)
	arm_group.add_child(shoulder)
	_add_box(shoulder, Vector3(ARM_W, UPPER_ARM_L, ARM_W), Vector3(0, -UPPER_ARM_L / 2.0, 0), mat)

	var elbow := _make_joint(prefix + "Elbow")
	elbow.position.y = -UPPER_ARM_L
	shoulder.add_child(elbow)
	_add_box(elbow, Vector3(ARM_W * 0.9, FOREARM_L, ARM_W * 0.9), Vector3(0, -FOREARM_L / 2.0, 0), mat)

	var wrist := _make_joint(prefix + "Wrist")
	wrist.position.y = -FOREARM_L
	elbow.add_child(wrist)
	_add_box(wrist, Vector3(HAND_S, HAND_S, HAND_S), Vector3(0, -HAND_S / 2.0, 0), mat_skin)

	return {"shoulder": shoulder, "elbow": elbow, "wrist": wrist}


func _create_leg(parent: Node3D, is_right: bool) -> Dictionary:
	# X 반전: Three.js side=-1(right) → Godot +0.11
	var side_x: float = 0.11 if is_right else -0.11
	var mat: StandardMaterial3D = mat_right if is_right else mat_left
	var group_name: String = "RightLeg" if is_right else "LeftLeg"
	var prefix: String = "R_" if is_right else "L_"

	# 중간 그룹 노드
	var leg_group := Node3D.new()
	leg_group.name = group_name
	parent.add_child(leg_group)

	var hip := _make_joint(prefix + "Hip")
	hip.position = Vector3(side_x, 0, 0)
	leg_group.add_child(hip)
	_add_box(hip, Vector3(THIGH_W, THIGH_L, THIGH_W), Vector3(0, -THIGH_L / 2.0, 0), mat)

	var knee := _make_joint(prefix + "Knee")
	knee.position.y = -THIGH_L
	hip.add_child(knee)
	_add_box(knee, Vector3(CALF_W, CALF_L, CALF_W), Vector3(0, -CALF_L / 2.0, 0), mat)

	return {"hip": hip, "knee": knee}


# =====================================================================
#  유틸
# =====================================================================
func _make_joint(joint_name: String) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.rotation_order = EULER_ORDER_XYZ
	return joint


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi
