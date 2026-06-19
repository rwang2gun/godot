class_name FallerState extends AntState

# 낙하 시작 y(=진입 시점)를 기록해 착지 시 낙하 거리를 산출한다(2026-06-02 기절 추가).
# 5칸 이상 자유낙하 + floater 미보유면 DeadState(기절)로, 그 외엔 return_to_walking()로 복귀.
var _fall_start_y: float = 0.0
# 낙하 시작 y override (옵션, 2026-06-06). WorkerState(digger)가 굴착 중 자유낙하를 감지해 FallerState로
# 넘길 때, 이미 일부 떨어진 거리를 포함한 실제 낙하 시작점(off-floor 진입 앵커)을 넘겨 기절 거리 측정을
# 정확히 한다. NAN(기본) = enter 시점 y를 시작점으로 사용(일반 낙하 — 기존 모든 호출 경로 무영향).
var _start_y_override: float = NAN
# 밀어내기 낙하(2026-06-20) — 건설 타일에 끼여 밀려난 개미의 낙하. floater 트레잇의 낙하산 연출(slow-fall +
# parachute 소리)과 **1회 소모**를 모두 건너뛴다(사용자: "낙하산이 아니라 떨어지는 모션 + 낙하산 소모 X").
# floater 트레잇 자체는 보존하므로 기절 면제(레밍즈 정통)도 유지 — 끼임은 개미 잘못이 아니라 능력 손해 없이
# 떨어뜨린다. 기본 false = 기존 모든 낙하 경로(절벽·digger) 동작 불변.
var _eject_fall: bool = false
# 착지음 최소 낙하거리(칸) — 이 미만의 작은 깡총 착지는 무음(스팸 방지). stun 임계(5칸)와 별개.
const LAND_MIN_FALL_CELLS: float = 1.5

func _init(start_y_override: float = NAN, eject_fall: bool = false) -> void:
	_start_y_override = start_y_override
	_eject_fall = eject_fall

func enter() -> void:
	var a: Ant = ant as Ant
	if a != null:
		_fall_start_y = a.global_position.y if is_nan(_start_y_override) else _start_y_override
		# 낙하산 펴는 소리 — floater 트레잇 개미가 slow-fall 진입하는 순간 1회. 밀어내기 낙하는 제외(연출 없이 떨어짐).
		if a.has_trait(&"floater") and not _eject_fall:
			EventBus.sfx_request.emit(&"parachute")

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return

	# Phase 14 — floater 보유 시 gravity 0.3배 감쇠. 밀어내기 낙하(_eject_fall)는 floater여도 일반 중력으로 떨어진다.
	var slow_fall: bool = a.has_trait(&"floater") and not _eject_fall
	var gscale: float = a.FLOATER_GRAVITY_SCALE if slow_fall else 1.0
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
			# (floater 소멸보다 먼저 판정해 낙하산 착지의 무음 컨벤션을 유지한다.)
			var land_min: float = a.stun_fall_threshold() / float(a.STUN_FALL_CELLS) * LAND_MIN_FALL_CELLS
			if not a.has_trait(&"floater") and fall_dist >= land_min:
				EventBus.sfx_request.emit(&"ant_land")
			# floater 1회 소멸 (2026-06-17) — 분배받은 개미(distributor 아님)가 낙하산으로 첫 낙하를 마치고
			# 착지하면 floater를 1회 소비해 제거한다. 분배자 본인(distributor)은 정착해 분배를 이어가야 하므로 유지.
			# 높이 무관(사용자 결정: "첫 낙하 1회 후"). 배지는 _update_trait_badges가 자동 갱신.
			# 밀어내기 낙하(_eject_fall)는 floater 1회 소모도 건너뛴다(트레잇 보존, 사용자 정정).
			if a.has_trait(&"floater") and not a.has_trait(&"distributor") and not _eject_fall:
				a.unset_trait(&"floater")
			a.return_to_walking()
