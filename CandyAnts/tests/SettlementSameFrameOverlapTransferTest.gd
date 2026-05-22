extends Node

# Phase 15 impl Round 3 F-impl-R3-1 MEDIUM 회귀 가드 (Round 5 F-impl-R5-1 monitoring 흐름 보강).
# SettlementMarker에 분배자와 follower가 같은 physics frame에 이미 overlap 중인 시나리오에서
# transfer가 누락되지 않는지 검증 — _drain_pending_receivers()가 정착 시점에 즉시
# get_overlapping_bodies() 스캔하여 transfer 보장.
#
# 시나리오: floor + marker monitoring=false + 분배자 + follower (둘 다 marker collision area 안 +
# floor 위 standing) → monitoring=true → 같은 physics frame에 body_entered 둘 다 발화 →
# 분배자가 정착 시 _drain_pending_receivers가 follower에게 즉시 transfer.
#
# PASS: quit(0). FAIL: quit(1).

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const SETTLEMENT_MARKER_SCENE: PackedScene = preload("res://scenes/world/SettlementMarker.tscn")

func _ready() -> void:
	# Floor — WalkerState가 is_on_floor=false면 FallerState 전이. ant standing y = floor_top - 5.
	const FLOOR_Y: float = 540.0
	const ANT_STANDING_Y: float = FLOOR_Y - 16.0 - 5.0   # = 519
	var floor_body: StaticBody2D = StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var floor_col: CollisionShape2D = CollisionShape2D.new()
	var floor_shape: RectangleShape2D = RectangleShape2D.new()
	floor_shape.size = Vector2(400, 32)
	floor_col.shape = floor_shape
	floor_body.add_child(floor_col)
	floor_body.global_position = Vector2(500, FLOOR_Y)
	add_child(floor_body)

	# marker 인스턴스 — monitoring=false 시작 (Round 5 F-impl-R5-1 — _ready 이후 명시적 set).
	var marker: SettlementMarker = SETTLEMENT_MARKER_SCENE.instantiate()
	marker.global_position = Vector2(500, ANT_STANDING_Y)
	add_child(marker)
	marker.monitoring = false

	# 분배자 ant — marker collision area 안 + floor 위.
	var distributor: Ant = ANT_SCENE.instantiate()
	distributor.global_position = Vector2(500, ANT_STANDING_Y)
	add_child(distributor)
	for i in range(5):
		await get_tree().physics_frame   # walker 자연 진입 + floor 안정
	distributor.set_trait(&"distributor")
	distributor.set_trait(&"floater")

	# follower ant — 분배자 옆 (같은 shape area 안).
	var follower: Ant = ANT_SCENE.instantiate()
	follower.global_position = Vector2(495, ANT_STANDING_Y)
	add_child(follower)
	for i in range(5):
		await get_tree().physics_frame   # walker 진입

	# Pre-condition (Round 5 F-impl-R5-1 보강) — monitoring=false라 follower는 transfer 미수신.
	if follower.has_trait(&"floater"):
		_fail("PRE: follower received floater while marker monitoring=false (test setup leak)")
		return

	# monitoring=true로 전환 → 같은 frame에 둘 다 body_entered 발화.
	marker.monitoring = true

	# _on_body_entered가 await physics_frame 사용 + _drain 호출. 여러 frame 대기.
	for i in range(15):
		await get_tree().physics_frame

	# 검증:
	# (1) 분배자가 SettledState 진입.
	if distributor.state_machine == null:
		_fail("distributor.state_machine null")
		return
	if not (distributor.state_machine.current_state is SettledState):
		_fail("distributor did not enter SettledState — state=%s" % distributor.state_machine.current_state)
		return
	# (2) marker._distributor 점유.
	if marker._distributor != distributor:
		_fail("marker._distributor mismatch — expected distributor, got %s" % marker._distributor)
		return
	# (3) follower가 floater trait 받음 (same-frame overlap에서 transfer 누락 없음).
	if not follower.has_trait(&"floater"):
		_fail("follower did not receive floater trait — _drain_pending_receivers leak (F-impl-R3-1 regression)")
		return
	# (4) follower는 distributor trait 미수신 (화이트리스트 정책).
	if follower.has_trait(&"distributor"):
		_fail("follower received distributor trait — whitelist violation")
		return

	print("[SettlementSameFrameOverlapTransferTest] PASS — distributor settled + follower received floater via _drain_pending_receivers")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SettlementSameFrameOverlapTransferTest] FAIL %s" % msg)
	get_tree().quit(1)
