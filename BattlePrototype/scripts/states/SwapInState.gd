class_name SwapInState
extends BaseState

var swap_timer: float = 0.0
const SWAP_IN_DURATION := 0.3

func enter() -> void:
	swap_timer = 0.0
	parent.set_pose("idle", 20.0)

func update(delta: float) -> void:
	swap_timer += delta
	parent.apply_friction(delta)

	if swap_timer >= SWAP_IN_DURATION:
		parent.state_machine.change_state("idle")
