extends Node

# Phase 15 impl Round 4 F-impl-R4-1 MEDIUM 회귀 가드.
# SettlementMarker가 carrying receiver(has_candy=true)에게도 trait transfer 적용하는지 검증.
# 기존 SettlementSameFrameOverlapTransferTest는 Walker receiver만 검증.
#
# 단순화 접근: distributor 정착 시뮬레이션을 manual로 — marker._distributor 강제 점유 +
# distributor SettledState 강제 전이 후, carrying follower가 marker 진입 시 transfer 검증.
# (정착 자체의 collision/walker dynamic은 SettlementSameFrameOverlapTransferTest가 검증함.)
#
# PASS: quit(0). FAIL: quit(1).

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const SETTLEMENT_MARKER_SCENE: PackedScene = preload("res://scenes/world/SettlementMarker.tscn")
const CARRYING_STATE_SCRIPT: GDScript = preload("res://scripts/ant/states/CarryingState.gd")
const SETTLED_STATE_SCRIPT: GDScript = preload("res://scripts/ant/states/SettledState.gd")

func _ready() -> void:
	# Floor — CarryingState.update가 is_on_floor=false면 FallerState 전이.
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

	# marker — monitoring=false 시작 (Round 5 F-impl-R5-1 — _ready가 monitoring을 덮어쓰지 않음).
	var marker: SettlementMarker = SETTLEMENT_MARKER_SCENE.instantiate()
	marker.global_position = Vector2(500, ANT_STANDING_Y)
	add_child(marker)
	marker.monitoring = false   # _ready 이후 명시적 set (scene default monitoring=true 덮어씀)

	# distributor — 즉시 SettledState 강제 전이 + marker._distributor 점유.
	var distributor: Ant = ANT_SCENE.instantiate()
	distributor.global_position = Vector2(495, ANT_STANDING_Y)
	add_child(distributor)
	await get_tree().physics_frame
	distributor.set_trait(&"distributor")
	distributor.set_trait(&"floater")
	if distributor.state_machine != null:
		distributor.state_machine.change_state(SETTLED_STATE_SCRIPT.new())
	marker._distributor = distributor

	# carrying follower — has_candy=true + CarryingState 강제 (floor 위 standing).
	var follower: Ant = ANT_SCENE.instantiate()
	follower.global_position = Vector2(510, ANT_STANDING_Y)
	add_child(follower)
	for i in range(5):
		await get_tree().physics_frame   # walker → floor 안정

	# Pre-condition (Round 5 F-impl-R5-1 보강) — marker가 monitoring=false라 follower는 아직 transfer 안 받음.
	if follower.has_trait(&"floater"):
		_fail("PRE: follower received floater while marker monitoring=false (test setup leak)")
		return

	follower.has_candy = true
	if follower.state_machine != null:
		follower.state_machine.change_state(CARRYING_STATE_SCRIPT.new())

	# CarryingState 안정 확인.
	for i in range(3):
		await get_tree().physics_frame

	if not (follower.state_machine.current_state is CarryingState):
		_fail("follower not in CarryingState — pre-condition violated (state=%s)" % follower.state_machine.current_state)
		return
	if not follower.has_candy:
		_fail("follower.has_candy false — pre-condition violated")
		return
	if not (distributor.state_machine.current_state is SettledState):
		_fail("distributor not in SettledState — pre-condition violated")
		return

	# marker monitoring=true → follower body_entered 발화. carrying receiver transfer 검증.
	marker.monitoring = true
	for i in range(15):
		await get_tree().physics_frame

	# 검증:
	if not follower.has_trait(&"floater"):
		_fail("carrying follower did not receive floater trait — has_candy filter leaked (F-impl-R4-1 regression)")
		return
	if not (follower.state_machine.current_state is CarryingState):
		_fail("carrying follower state changed during transfer — expected CarryingState")
		return
	if not follower.has_candy:
		_fail("carrying follower lost has_candy during transfer")
		return
	if follower.has_trait(&"distributor"):
		_fail("follower received distributor trait — whitelist violation")
		return

	print("[SettlementCarryingReceiverTransferTest] PASS — carrying follower received floater + CarryingState/has_candy 유지")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[SettlementCarryingReceiverTransferTest] FAIL %s" % msg)
	get_tree().quit(1)
