class_name FallerState extends AntState

# 낙하 시작 y(=진입 시점)를 기록해 착지 시 낙하 거리를 산출한다(2026-06-02 기절 추가).
# 5칸 이상 자유낙하 + floater 미보유면 DeadState(기절)로, 그 외엔 return_to_walking()로 복귀.
var _fall_start_y: float = 0.0

func enter() -> void:
	var a: Ant = ant as Ant
	if a != null:
		_fall_start_y = a.global_position.y

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	# Phase 14 — floater 보유 시 gravity 0.3배 감쇠.
	var gscale: float = a.FLOATER_GRAVITY_SCALE if a.has_trait(&"floater") else 1.0
	a.velocity.y += a.gravity * delta * gscale
	# 수평 속도는 유지 (좌우 흔들림 없음)
	a.velocity.x = float(a.direction) * a.effective_speed() * 0.5

	a.move_and_slide()

	if a.is_on_floor():
		# 기절(2026-06-02): 5칸+ 자유낙하 + floater 미보유 → DeadState(기절 스프라이트, 사망 묘사 없음).
		# floater는 높이 무관 무효(레밍즈 정통). 그 외엔 carry 모션 분기를 단일 진입점에 위임.
		var fall_dist: float = a.global_position.y - _fall_start_y
		if not a.has_trait(&"floater") and fall_dist >= a.stun_fall_threshold():
			a.state_machine.change_state(DeadState.new())
		else:
			a.return_to_walking()
