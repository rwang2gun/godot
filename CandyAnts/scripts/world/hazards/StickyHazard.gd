class_name StickyHazard extends HazardBase

# 끈끈이 hazard = 감속 존(2026-06-07 재설계, HTML 원안). 과거 "body_entered → apply_sticky(N초 완전정지)"를 폐기.
# body_entered → ant.enter_sticky / body_exited → ant.exit_sticky 로 겹침 집합만 갱신한다.
# 개미는 끈끈이 셀과 겹쳐있는 동안 effective_speed가 STICKY_SPEED_MULT배로 느려질 뿐(정지·카운트다운 없음).
# 나뭇잎 점프대 홉 직후(is_jump_immune)엔 진입 무시 — 포물선으로 넘는 동안 감속하지 않는다.

func _ready() -> void:
	super._ready()
	body_exited.connect(_on_body_exited)

func _handle_ant_entry(ant: Ant) -> void:
	if ant.is_jump_immune():
		return
	# 첫 끈끈이 접촉 sfx — 이미 다른 끈끈이 셀에 겹쳐있으면(이어붙은 띠) 중복으로 내지 않는다.
	if not ant.is_slowed():
		EventBus.sfx_request.emit(&"sticky_glue")
	ant.enter_sticky(get_instance_id())

func _on_body_exited(body: Node2D) -> void:
	var ant: Ant = body as Ant
	if ant == null or not is_instance_valid(ant):
		return
	ant.exit_sticky(get_instance_id())

# 비활성화(deactivate_hazards_for_placement 등) 시 monitoring off는 body_exited를 쏘지 않으므로,
# 끄기 직전 겹쳐있던 개미의 감속 소스를 직접 제거해 영구 감속 잔존을 막는다.
func set_active(active: bool) -> void:
	if not active:
		for b in get_overlapping_bodies():
			var ant: Ant = b as Ant
			if ant != null and is_instance_valid(ant):
				ant.exit_sticky(get_instance_id())
	super.set_active(active)
