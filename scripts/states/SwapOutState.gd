class_name SwapOutState
extends BaseState

var swap_timer: float = 0.0
const SWAP_OUT_DURATION := 0.2

func enter() -> void:
	swap_timer = 0.0
	parent.set_pose("idle", 30.0)

func update(delta: float) -> void:
	swap_timer += delta
	parent.apply_friction(delta)

	if swap_timer >= SWAP_OUT_DURATION:
		# GameManager에게 교체 완료 알림
		if parent.game_manager:
			parent.game_manager.complete_swap_out()
