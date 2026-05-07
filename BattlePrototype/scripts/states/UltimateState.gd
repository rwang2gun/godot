class_name UltimateState
extends BaseState

var ult_timer: float = 0.0
const ULT_DURATION := 1.5

func enter() -> void:
	ult_timer = 0.0
	parent.mp = 0  # MP 전부 소모
	parent.set_pose("ult_windup", 20.0)

	if parent.game_manager:
		parent.game_manager.trigger_slow_mo(1.0)

func update(delta: float) -> void:
	ult_timer += delta
	parent.apply_friction(delta)

	# 0.5s 이후 타격 포즈
	if ult_timer > 0.5 and ult_timer - delta <= 0.5:
		parent.set_pose("ult_strike", 30.0)

	if ult_timer >= ULT_DURATION:
		parent.state_machine.change_state("idle")
