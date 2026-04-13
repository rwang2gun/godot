class_name ChargeAttackState
extends BaseState

var charge_timer: float = 0.0
const CHARGE_DURATION := 0.6
const CHARGE_ACTIVE_END := 0.35

var has_hit: bool = false

func enter() -> void:
	charge_timer = 0.0
	has_hit = false
	parent.set_pose("shoulder_bash", 25.0)

	# 가장 가까운 적 방향으로 회전
	var nearest: Node3D = parent.get_nearest_enemy()
	if nearest:
		var to_t: Vector3 = nearest.global_position - parent.global_position
		to_t.y = 0
		if to_t.length() > 0.1:
			parent.target_facing = atan2(-to_t.x, -to_t.z)

func update(delta: float) -> void:
	charge_timer += delta

	# 전진 돌진
	var fwd: Vector3 = -parent.pivot.global_transform.basis.z
	parent.velocity.x = lerpf(parent.velocity.x, fwd.x * 6.0, 10.0 * delta)
	parent.velocity.z = lerpf(parent.velocity.z, fwd.z * 6.0, 10.0 * delta)

	# 히트 판정
	if not has_hit and charge_timer < CHARGE_ACTIVE_END:
		parent.check_hit()
		if parent.has_hit:
			has_hit = true

	if charge_timer >= CHARGE_DURATION:
		parent.combo_step = 0
		parent.state_machine.change_state("idle")
