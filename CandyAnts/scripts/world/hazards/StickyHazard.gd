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
	var frame: int = Engine.get_physics_frames()
	var aid: int = ant.get_instance_id()
	# 같은 frame 중복 발화 skip (set_deferred/signal 순서 race 대응).
	if _recently_processed.get(aid, -1) == frame:
		return
	_recently_processed[aid] = frame
	ant.apply_sticky(duration)

func _on_body_exited(body: Node2D) -> void:
	var ant: Ant = body as Ant
	if ant == null:
		return
	_recently_processed.erase(ant.get_instance_id())
