class_name WaterHazard extends HazardBase

# Phase 17 — Water hazard. body_entered → 즉시 LostState 전이로 사탕 손실 + ant 제거.
# LostState.enter()가 candy_piece_lost emit + queue_free 수행.

func _handle_ant_entry(ant: Ant) -> void:
	# Phase 20 — sfx_request emit 직전 (id only). receiver는 phase 21에서 connect.
	EventBus.sfx_request.emit(&"water_splash")
	ant.state_machine.change_state(LostState.new())
