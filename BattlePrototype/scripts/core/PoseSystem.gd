class_name PoseSystem
extends RefCounted

## 포즈를 스켈레톤 파츠에 보간 적용
## parts: CharacterBase가 구성한 노드 딕셔너리
## pose: PoseData.POSES["idle"] 등
## speed: 보간 속도 (6~12=느린, 20~28=콤보, 30~40=빠른 복귀)
## delta: _physics_process delta
func apply_pose(parts: Dictionary, pose: Dictionary, speed: float, delta: float) -> void:
	var a: float = minf(1.0, speed * delta)

	# root (position.y + rotation.x/y)
	var root: Node3D = parts["root"]
	var pr: Dictionary = pose.get("root", {})
	root.position.y = lerpf(root.position.y, pr.get("y", 0.0), a)
	root.rotation.x = lerpf(root.rotation.x, pr.get("rx", 0.0), a)
	root.rotation.y = lerpf(root.rotation.y, pr.get("ry", 0.0), a)

	# waist
	var waist: Node3D = parts["waist"]
	var pw: Dictionary = pose.get("waist", {})
	waist.rotation.x = lerpf(waist.rotation.x, pw.get("rx", 0.0), a)
	waist.rotation.y = lerpf(waist.rotation.y, pw.get("ry", 0.0), a)

	# chest
	var chest: Node3D = parts["chest"]
	var pc: Dictionary = pose.get("chest", {})
	chest.rotation.x = lerpf(chest.rotation.x, pc.get("rx", 0.0), a)
	chest.rotation.y = lerpf(chest.rotation.y, pc.get("ry", 0.0), a)

	# 오른팔
	var ra: Dictionary = pose.get("rArm", {})
	var r_arm: Dictionary = parts["right_arm"]
	lerp_joint(r_arm["shoulder"], Vector3(ra.get("sx", 0.0), ra.get("sy", 0.0), ra.get("sz", 0.0)), a)
	r_arm["elbow"].rotation.x = lerpf(r_arm["elbow"].rotation.x, ra.get("ex", 0.0), a)
	lerp_joint(r_arm["wrist"], Vector3(ra.get("wx", 0.0), ra.get("wy", 0.0), 0.0), a)

	# 왼팔
	var la: Dictionary = pose.get("lArm", {})
	var l_arm: Dictionary = parts["left_arm"]
	lerp_joint(l_arm["shoulder"], Vector3(la.get("sx", 0.0), la.get("sy", 0.0), la.get("sz", 0.0)), a)
	l_arm["elbow"].rotation.x = lerpf(l_arm["elbow"].rotation.x, la.get("ex", 0.0), a)

	# 오른다리
	var rh: Dictionary = pose.get("rHip", {})
	var r_leg: Dictionary = parts["right_leg"]
	lerp_joint(r_leg["hip"], Vector3(rh.get("rx", 0.0), rh.get("ry", 0.0), rh.get("rz", 0.0)), a)
	r_leg["knee"].rotation.x = lerpf(r_leg["knee"].rotation.x, rh.get("knee", 0.05), a)

	# 왼다리
	var lh: Dictionary = pose.get("lHip", {})
	var l_leg: Dictionary = parts["left_leg"]
	lerp_joint(l_leg["hip"], Vector3(lh.get("rx", 0.0), lh.get("ry", 0.0), lh.get("rz", 0.0)), a)
	l_leg["knee"].rotation.x = lerpf(l_leg["knee"].rotation.x, lh.get("knee", 0.05), a)


## 단일 관절의 x/y/z 회전을 목표값으로 보간
func lerp_joint(joint: Node3D, target: Vector3, alpha: float) -> void:
	joint.rotation.x = lerpf(joint.rotation.x, target.x, alpha)
	joint.rotation.y = lerpf(joint.rotation.y, target.y, alpha)
	joint.rotation.z = lerpf(joint.rotation.z, target.z, alpha)
