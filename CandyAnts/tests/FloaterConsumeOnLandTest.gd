extends Node

# floater 1회 소멸 검증 (2026-06-17) — 분배받은 개미(floater, distributor 아님)가 낙하 후 착지하면
# floater trait이 제거되고, 분배자(floater+distributor)는 유지되는지 단언한다(FallerState 착지 처리).
# bare 씬(StunFallTest 패턴): floor + 높은 낙하 2마리.
#   A: floater만 → 착지 후 floater 제거(소멸 = 분배받은 개미는 한 번 쓰면 사라짐).
#   B: floater+distributor → 착지 후 floater 유지(분배자는 계속 분배해야 하므로).
# PASS quit(0) / FAIL quit(1).

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const FLOOR_TOP_Y: float = 600.0
const DEADLINE_FRAMES: int = 360   # ~6s — floater 느린낙하(0.3배 중력) 360px 착지 수용(StunFall C와 동일).

var _a: Ant = null   # floater만 (분배받은 개미)
var _b: Ant = null   # floater+distributor (분배자)
var _done: bool = false
var _frame: int = 0

func _ready() -> void:
	var world: Node2D = Node2D.new()
	world.name = "World"
	add_child(world)
	_make_floor(world)
	_a = _spawn(world, Vector2(200.0, FLOOR_TOP_Y - 360.0), false)
	_b = _spawn(world, Vector2(440.0, FLOOR_TOP_Y - 360.0), true)
	print("[FloaterConsumeOnLandTest] driver ready")

func _spawn(world: Node2D, pos: Vector2, distributor: bool) -> Ant:
	var a: Ant = ANT_SCENE.instantiate() as Ant
	a.position = pos
	world.add_child(a)
	a.set_trait(&"floater")
	if distributor:
		a.set_trait(&"distributor")
	return a

func _make_floor(world: Node2D) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1   # Ant.collision_mask=3 → layer1 충돌
	body.collision_mask = 0
	body.position = Vector2(320.0, FLOOR_TOP_Y + 20.0)   # top = 600
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(1000.0, 40.0)
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < DEADLINE_FRAMES:
		return
	_evaluate()

func _evaluate() -> void:
	var fails: Array[String] = []
	# A — floater만(분배받은 개미): 낙하+착지 후 floater 제거(소멸).
	if not is_instance_valid(_a):
		fails.append("A: 개미 제거됨 — floater 낙하는 안전(생존) 기대")
	elif _a.has_trait(&"floater"):
		fails.append("A: 착지 후에도 floater 유지 — 분배받은 개미는 첫 낙하 후 1회 소멸 기대")
	# B — floater+distributor(분배자): 착지 후 floater 유지.
	if not is_instance_valid(_b):
		fails.append("B: 분배자 제거됨 — 생존 기대")
	elif not _b.has_trait(&"floater"):
		fails.append("B: 분배자 floater 소멸 — distributor는 분배 위해 floater 유지 기대")

	if fails.size() > 0:
		push_error("FloaterConsumeOnLandTest FAIL\n" + "\n".join(fails))
		print("[FloaterConsumeOnLandTest] FAIL\n", "\n".join(fails))
		get_tree().quit(1)
	else:
		print("[FloaterConsumeOnLandTest] PASS — A floater 소멸(분배받음) / B floater 유지(분배자)")
		get_tree().quit(0)
	_done = true
