class_name SettledState extends AntState

# Phase 15 — 정착 상태. terminal (해제 불가, exit 불호출). SettlementMarker._on_body_entered가
# 분배자 본인의 정착 트리거에서 change_state(SettledState.new())로 진입시킨다.
# 후속 walker는 SettledState로 안 들어가고 SettlementMarker._transfer_traits만 받음.

# v2 F3: 전이 가능 트레잇 화이트리스트 — single SoT. phase 16+ 트레잇 추가 시 본 배열만 갱신.
const TRANSFER_WHITELIST: Array[StringName] = [&"floater"]

var _settle_pos: Vector2 = Vector2.ZERO

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	_settle_pos = a.global_position
	a.velocity = Vector2.ZERO
	# 분배자가 blocker 스킬 받은 적 없음 (DistributorSkill.can_apply 표 참조)이지만 멱등 호출.
	a.set_blocker_active(false)

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	# 중력만 적용 — 정착 cell이 platform 위에 있다는 가정. 떠있으면 floor 도착까지 자유낙하.
	# Faller로 전이하지 않음 — SettledState는 terminal (D3 해제 불가).
	if not a.is_on_floor():
		a.velocity.y += a.gravity * delta
	else:
		a.velocity.y = 0.0
	a.velocity.x = 0.0
	a.move_and_slide()
	# 좌우 anchor — push로 살짝 밀려도 _settle_pos.x 복원.
	a.global_position.x = _settle_pos.x
