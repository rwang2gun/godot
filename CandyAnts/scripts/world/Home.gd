class_name Home extends Area2D

@export var spawn_position_offset: Vector2 = Vector2(0, -5)
const RESPAWN_DELAY_SECONDS: float = 3.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func get_spawn_position() -> Vector2:
	return global_position + spawn_position_offset

func _on_body_entered(body: Node2D) -> void:
	if not (body is Ant):
		return
	var a: Ant = body as Ant
	# 가드 1: 스폰/리스폰 grace — spawn 위치가 Home Area2D 내부라 spawn 직후 body_entered가
	# 즉시 발화. 빈손 fresh ant도 respawn 분기로 가도록 기존 has_been_carrying guard는 제거하고
	# grace + re-arm으로 spawn/respawn 직후 1회 발화만 차단.
	if Time.get_ticks_msec() / 1000.0 < a._grace_until:
		return
	var carrying: bool = a.has_candy

	# 운반 종료 처리 — 사탕은 ant 손을 떠나 Home에 안착, has_candy 해제 후 시그널.
	a.has_candy = false
	print("[Home] saved ", a.name, " carrying=", carrying)
	# Phase 20 — sfx_request emit (with_candy=true만; 빈손 회수는 분배자 정착 후 등 코어 게임플레이 핵심 아님).
	if carrying:
		EventBus.sfx_request.emit(&"ant_save")
	EventBus.ant_saved.emit(a, carrying)
	if carrying:
		a.state_machine.change_state(SavedState.new())
	else:
		# 빈손 귀가는 SavedState(queue_free) 대신 3초 대기 후 spawn 위치에서 재등장.
		# 같은 인스턴스를 재활용해 trait 보존 + AntSpawner.total cap 무영향 +
		# _living_ant_count(노드 존재 기준)도 그대로 유지 → no_more_ants 가드 안전.
		_begin_respawn(a)

func _begin_respawn(a: Ant) -> void:
	a.velocity = Vector2.ZERO
	a.global_position = global_position
	a.visible = false
	# collision_layer=0 으로 잠시 빼서 Home/Hazard Area2D 트리거 비활성. set_deferred로 physics step 중 변경 회피.
	a.set_deferred("collision_layer", 0)
	a.process_mode = Node.PROCESS_MODE_DISABLED
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = RESPAWN_DELAY_SECONDS
	add_child(timer)
	timer.timeout.connect(_on_respawn_timeout.bind(a, timer))
	timer.start()

func _on_respawn_timeout(a: Ant, timer: Timer) -> void:
	timer.queue_free()
	if not is_instance_valid(a):
		return
	a.process_mode = Node.PROCESS_MODE_INHERIT
	a.global_position = get_spawn_position()
	a.velocity = Vector2.ZERO
	# 진행 방향이 반전된 채로 재등장하면 spawn 위치 바로 옆 절벽으로 떨어지는 회귀.
	# Ant._ready가 snapshot한 최초 스폰 방향으로 복원해 첫 스폰과 동일한 walk-out 보장.
	a.direction = a._spawn_direction
	a.visible = true
	# grace 재무장 — collision_layer 복귀 시 spawn 위치(Home 내부)에서 body_entered가 즉시 재발화해
	# 무한 respawn 루프가 생기는 것을 차단. 0.4s 안에 ant가 home 밖으로 걸어나가야 다음 entry부터 정상 트리거.
	a._grace_until = Time.get_ticks_msec() / 1000.0 + a.spawn_grace_seconds
	a.has_been_carrying = false
	a.collision_layer = 4  # Ant.tscn 기본값 (Layer 3)
	a.state_machine.change_state(WalkerState.new())
