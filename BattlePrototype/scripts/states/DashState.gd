class_name DashState
extends BaseState

## HTML DashState 이식
##  - WASD 있음 → 입력 방향 + POSES.dash (전방 대시)
##  - WASD 없음 → 후방 + 절차적 백대시 포즈 (HTML 라인 738-761 좌표 변환 적용)
##  속도/지속시간은 캐릭터별 DASH_SPEED / DASH_DURATION 사용 (HTML 원본 8.0 m/s × 0.25s = 약 2 m)


func enter() -> void:
	# 백대시는 절차적 포즈를 직접 lerp → PoseSystem 비활성
	if parent.is_back_dash:
		parent.skip_pose_update = true
	else:
		parent.skip_pose_update = false
		parent.set_pose("dash", 25.0)


func exit() -> void:
	parent.skip_pose_update = false
	parent.velocity.x = 0.0
	parent.velocity.z = 0.0


func update(delta: float) -> void:
	parent.dash_timer += delta
	parent.velocity.x = parent.dash_dir.x * parent.DASH_SPEED
	parent.velocity.z = parent.dash_dir.z * parent.DASH_SPEED

	# 대시 도중 공격 입력 → forceDash 콤보로 진입 (있으면)
	if InputManager.attack_triggered and parent.combo_cooldown <= 0:
		parent.special_mode = "dash"
		parent.combo_step = 1
		parent.state_machine.change_state("attack")
		return

	if parent.is_back_dash:
		_animate_back_dash(delta)

	if parent.dash_timer >= parent.DASH_DURATION:
		parent.state_machine.change_state("idle")


# =====================================================================
#  HTML DashState.update 의 isBackDash 분기 절차적 애니메이션 이식
#  좌표 변환: rx/rz/sx/sz/ex/wx/knee → 부호 반전, ry/sy/wy → 그대로
# =====================================================================
func _animate_back_dash(delta: float) -> void:
	var t: float = minf(1.0, 25.0 * delta)

	var root: Node3D  = parent.parts["root"]
	var waist: Node3D = parent.parts["waist"]
	var chest: Node3D = parent.parts["chest"]
	var l_hip: Node3D  = parent.parts["left_leg"]["hip"]
	var l_knee: Node3D = parent.parts["left_leg"]["knee"]
	var r_hip: Node3D  = parent.parts["right_leg"]["hip"]
	var r_knee: Node3D = parent.parts["right_leg"]["knee"]
	var l_sh: Node3D = parent.parts["left_arm"]["shoulder"]
	var l_el: Node3D = parent.parts["left_arm"]["elbow"]
	var r_sh: Node3D = parent.parts["right_arm"]["shoulder"]
	var r_el: Node3D = parent.parts["right_arm"]["elbow"]
	var r_wr: Node3D = parent.parts["right_arm"]["wrist"]

	# Root: HTML rx=-0.6, ry=-0.6, y=0.85 → rx 반전 +0.6, ry 그대로 -0.6
	root.rotation.x = lerpf(root.rotation.x, 0.6, t)
	root.rotation.y = lerpf(root.rotation.y, -0.6, t)
	root.position.y = lerpf(root.position.y, 0.85, t)

	# Waist: HTML rx=0.6, ry=0.2 → -0.6, 0.2
	waist.rotation.x = lerpf(waist.rotation.x, -0.6, t)
	waist.rotation.y = lerpf(waist.rotation.y, 0.2, t)

	# Chest: HTML rx=0.3, ry=0.2 → -0.3, 0.2
	chest.rotation.x = lerpf(chest.rotation.x, -0.3, t)
	chest.rotation.y = lerpf(chest.rotation.y, 0.2, t)

	# 다리: HTML lLeg.hip=(-1.0, 0, -0.1), lKnee.x=0.05 → 반전 (1.0, 0, 0.1), -0.05
	l_hip.rotation.x = lerpf(l_hip.rotation.x, 1.0, t)
	l_hip.rotation.y = lerpf(l_hip.rotation.y, 0.0, t)
	l_hip.rotation.z = lerpf(l_hip.rotation.z, 0.1, t)
	l_knee.rotation.x = lerpf(l_knee.rotation.x, -0.05, t)

	# rLeg.hip=(-1.4, 0, 0.2), rKnee.x=1.5 → (1.4, 0, -0.2), -1.5
	r_hip.rotation.x = lerpf(r_hip.rotation.x, 1.4, t)
	r_hip.rotation.y = lerpf(r_hip.rotation.y, 0.0, t)
	r_hip.rotation.z = lerpf(r_hip.rotation.z, -0.2, t)
	r_knee.rotation.x = lerpf(r_knee.rotation.x, -1.5, t)

	# 왼팔: HTML shoulder=(-1.2, 0.2, 0.4), elbow.x=-0.1 → (1.2, 0.2, -0.4), 0.1
	l_sh.rotation.x = lerpf(l_sh.rotation.x, 1.2, t)
	l_sh.rotation.y = lerpf(l_sh.rotation.y, 0.2, t)
	l_sh.rotation.z = lerpf(l_sh.rotation.z, -0.4, t)
	l_el.rotation.x = lerpf(l_el.rotation.x, 0.1, t)

	# 오른팔: HTML shoulder=(0.5, 0, -0.6), elbow.x=-0.2 → (-0.5, 0, 0.6), 0.2
	r_sh.rotation.x = lerpf(r_sh.rotation.x, -0.5, t)
	r_sh.rotation.y = lerpf(r_sh.rotation.y, 0.0, t)
	r_sh.rotation.z = lerpf(r_sh.rotation.z, 0.6, t)
	r_el.rotation.x = lerpf(r_el.rotation.x, 0.2, t)
	# 손목: HTML set(1.4, 0.2, 0) → 반전 (-1.4, 0.2, 0)
	r_wr.rotation = Vector3(-1.4, 0.2, 0.0)
