class_name HurtState
extends BaseState

func enter() -> void:
	parent.set_pose("hurt", 30.0)

func update(delta: float) -> void:
	parent.hurt_timer -= delta
	parent.velocity.x = parent.knockback_vel.x
	parent.velocity.z = parent.knockback_vel.z
	# 수직 넉백 (shove 띄우기 등)
	if parent.knockback_vel.y > 0.1:
		parent.velocity.y = parent.knockback_vel.y
	parent.knockback_vel = parent.knockback_vel.lerp(Vector3.ZERO, 6.0 * delta)

	if parent.hurt_timer <= 0:
		parent.state_machine.change_state("idle")
