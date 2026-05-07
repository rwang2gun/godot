class_name SkillState
extends BaseState

var skill_timer: float = 0.0
const SKILL_DURATION := 0.8

func enter() -> void:
	skill_timer = 0.0
	parent.skill_cooldown = parent.SKILL_COOLDOWN_MAX
	parent.set_pose("skill_cast", 25.0)

	# 가장 가까운 적 방향으로 회전
	var nearest: Node3D = parent.get_nearest_enemy()
	if nearest:
		var to_t: Vector3 = nearest.global_position - parent.global_position
		to_t.y = 0
		if to_t.length() > 0.1:
			parent.target_facing = atan2(-to_t.x, -to_t.z)

func update(delta: float) -> void:
	skill_timer += delta
	parent.apply_friction(delta)

	if skill_timer >= SKILL_DURATION:
		parent.state_machine.change_state("idle")
