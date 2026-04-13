class_name HurtState
extends BaseState

func enter() -> void:
	parent.set_pose("hurt", 30.0)

func update(delta: float) -> void:
	parent.hurt_timer -= delta
	parent.velocity.x = parent.knockback_vel.x
	parent.velocity.z = parent.knockback_vel.z
	parent.knockback_vel = parent.knockback_vel.lerp(Vector3.ZERO, 6.0 * delta)

	if parent.hurt_timer <= 0:
		parent.state_machine.change_state("idle")
