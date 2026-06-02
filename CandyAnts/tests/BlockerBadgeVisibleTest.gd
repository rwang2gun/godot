extends Node

# Blocker 배지 표시 검증 (2026-06-02) — 개미가 WorkerState("blocker")일 때만 꼬리 배지 최상위
# (y=-44, climber 0 / floater -22 위)에 차단 아이콘이 visible=true. 비-blocker(Walker)는 false.
# 바닥(StaticBody2D layer1) 위에서 검증 — blocker는 is_on_floor 유지돼야 FallerState로 안 빠짐.
# PASS: quit(0). FAIL: quit(1).

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const FLOOR_TOP_Y: float = 280.0

var _blocker: Ant = null
var _walker: Ant = null
var _frame: int = 0
var _phase: int = 0
var _check_frame: int = 0

func _ready() -> void:
	var world: Node2D = Node2D.new()
	world.name = "World"
	add_child(world)
	_make_floor(world)
	# 바닥(top=280) 위에 안착하도록 살짝 위에서 스폰 → 중력으로 착지.
	_blocker = ANT_SCENE.instantiate() as Ant
	_blocker.position = Vector2(260.0, 250.0)
	world.add_child(_blocker)
	_walker = ANT_SCENE.instantiate() as Ant
	_walker.position = Vector2(340.0, 250.0)
	world.add_child(_walker)
	print("[BlockerBadgeTest] driver ready")

func _make_floor(world: Node2D) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1   # Ant.collision_mask=3 → layer1 충돌
	body.collision_mask = 0
	body.position = Vector2(300.0, FLOOR_TOP_Y + 20.0)   # top = 280
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(800.0, 40.0)
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)

func _physics_process(_delta: float) -> void:
	_frame += 1
	if _phase == 0:
		# blocker 개미가 바닥에 안착하면 blocker로 전이.
		if _blocker.state_machine != null and _blocker.is_on_floor():
			_blocker.state_machine.change_state(WorkerState.new("blocker"))
			_phase = 1
			_check_frame = _frame + 3   # _update_trait_badges가 돌 프레임 여유.
		elif _frame > 300:
			_fail("blocker 개미가 바닥에 안착 못함(is_on_floor false) — 셋업 문제")
	elif _phase == 1 and _frame >= _check_frame:
		_check()

func _check() -> void:
	# blocker 상태 유지 확인(바닥 위라 FallerState로 안 빠져야).
	if not _blocker._is_blocker_state():
		_fail("blocker 개미가 blocker 상태 이탈(state=%s)" % str(_blocker.state_machine.current_state))
		return
	var bb: Sprite2D = _blocker._blocker_badge
	var wb: Sprite2D = _walker._blocker_badge
	if bb == null:
		_fail("BlockerBadge 노드 없음 — Ant.tscn TailBadges/BlockerBadge 확인")
		return
	if not bb.visible:
		_fail("blocker 개미 BlockerBadge.visible=false (true 기대)")
		return
	if absf(bb.position.y - (-44.0)) > 0.5:
		_fail("BlockerBadge.y=%.1f (최상위 -44 기대 — climber 0 / floater -22 위)" % bb.position.y)
		return
	if wb != null and wb.visible:
		_fail("walker(비-blocker) 개미 BlockerBadge.visible=true (false 기대)")
		return
	print("[BlockerBadgeTest] PASS blocker.visible=true y=%.1f (topmost) / walker.visible=false" % bb.position.y)
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[BlockerBadgeTest] FAIL %s" % msg)
	get_tree().quit(1)
