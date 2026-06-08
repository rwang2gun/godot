class_name FallerState extends AntState

# 낙하 시작 y(=진입 시점)를 기록해 착지 시 낙하 거리를 산출한다(2026-06-02 기절 추가).
# 5칸 이상 자유낙하 + floater 미보유면 DeadState(기절)로, 그 외엔 return_to_walking()로 복귀.
var _fall_start_y: float = 0.0
# 낙하 시작 y override (옵션, 2026-06-06). WorkerState(digger)가 굴착 중 자유낙하를 감지해 FallerState로
# 넘길 때, 이미 일부 떨어진 거리를 포함한 실제 낙하 시작점(off-floor 진입 앵커)을 넘겨 기절 거리 측정을
# 정확히 한다. NAN(기본) = enter 시점 y를 시작점으로 사용(일반 낙하 — 기존 모든 호출 경로 무영향).
var _start_y_override: float = NAN
# 착지음 최소 낙하거리(칸) — 이 미만의 작은 깡총 착지는 무음(스팸 방지). stun 임계(5칸)와 별개.
const LAND_MIN_FALL_CELLS: float = 1.5

func _init(start_y_override: float = NAN) -> void:
	_start_y_override = start_y_override

func enter() -> void:
	var a: Ant = ant as Ant
	if a != null:
		_fall_start_y = a.global_position.y if is_nan(_start_y_override) else _start_y_override
		# 낙하산 펴는 소리 — floater 트레잇 개미가 slow-fall 진입하는 순간 1회(throttle로 잦은 재진입 흡수).
		if a.has_trait(&"floater"):
			EventBus.sfx_request.emit(&"parachute")

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
			# 착지음 — 기절 미만의 실질 낙하만(작은 깡총 제외). floater는 낙하산 착지라 thud 없음.
			# 1.5칸 임계 = stun 임계(5칸) / STUN_FALL_CELLS * LAND_MIN_FALL_CELLS → cell_size 자동 추종.
			var land_min: float = a.stun_fall_threshold() / float(a.STUN_FALL_CELLS) * LAND_MIN_FALL_CELLS
			if not a.has_trait(&"floater") and fall_dist >= land_min:
				EventBus.sfx_request.emit(&"ant_land")
			a.return_to_walking()
