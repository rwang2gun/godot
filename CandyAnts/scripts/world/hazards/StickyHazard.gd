class_name StickyHazard extends HazardBase

# Phase 17 — 끈끈이 hazard. body_entered → ant.apply_sticky(duration).
# Walker/Carrying update가 is_stuck() 분기로 정지.
# D13 — 같은 frame 다중 body_entered 차단 위해 instance frame 캐싱.

@export var duration: float = 3.0

# Ant InstanceID → 마지막 처리 frame (Engine.get_physics_frames()).
# body_exited에서 entry 정리 — 재진입 시 fresh trigger.
var _recently_processed: Dictionary = {}

func _ready() -> void:
	super._ready()
	body_exited.connect(_on_body_exited)

func _handle_ant_entry(ant: Ant) -> void:
	# 나뭇잎 점프대(leaf_jump) 홉 직후 면역 — 점프로 끈끈이를 넘는 동안엔 정지시키지 않는다.
	# (홉은 끈끈이 너머 바닥에 착지하므로 보통 overlap 자체가 없지만, 착지 프레임 잔여 overlap 방어.)
	if ant.is_jump_immune():
		return
	var frame: int = Engine.get_physics_frames()
	var aid: int = ant.get_instance_id()
	# 같은 frame 중복 발화 skip (set_deferred/signal 순서 race 대응).
	if _recently_processed.get(aid, -1) == frame:
		return
	_recently_processed[aid] = frame
	# Phase 20 — sfx_request emit 직전 (D13 idempotency 가드 통과 후, apply_sticky 직전).
	# receiver는 phase 21에서 connect.
	EventBus.sfx_request.emit(&"sticky_glue")
	ant.apply_sticky(duration)

func _on_body_exited(body: Node2D) -> void:
	var ant: Ant = body as Ant
	if ant == null:
		return
	_recently_processed.erase(ant.get_instance_id())
