class_name DashState
extends BaseState

func enter() -> void:
	parent.set_pose("dash", 30.0)

func update(delta: float) -> void:
	parent.dash_timer += delta
	parent.velocity.x = parent.dash_dir.x * parent.DASH_SPEED
	parent.velocity.z = parent.dash_dir.z * parent.DASH_SPEED

	if parent.dash_timer >= parent.DASH_DURATION:
		parent.state_machine.change_state("idle")
