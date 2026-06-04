extends Node

# 기절(stun) 낙하 검증 (2026-06-02, 2026-06-04 영속화) — 5칸+ 자유낙하 + floater 미보유 → DeadState(기절,
# 스테이지 종료까지 유지·queue_free 없음) + 운반 중이면 candy_piece_lost 정산. 5칸 미만 또는 floater
# 보유는 기절 없이 보행/운반 복귀(생존).
# bare 씬(StageLayoutBuilder ancestor 없음) → Ant._cell_size=48 기본 → 임계 240px.
#   A: 비-floater 운반, drop≈360(>240) → 기절(DeadState) + 사탕 lost + 종료까지 DeadState 유지(제거 X).
#   B: 비-floater 빈손, drop≈190(<240) → 생존(alive), 기절 X.
#   C: floater 운반,  drop≈360(>240) → 생존(alive) + 사탕 유지(lost X), 기절 X.
# PASS quit(0) / FAIL quit(1).

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const FLOOR_TOP_Y: float = 600.0
const DEADLINE_FRAMES: int = 360   # ~6s — 모든 낙하 + 기절 1s + 플로터 느린낙하 수용.

var _a: Ant = null
var _b: Ant = null
var _c: Ant = null
var _a_id: int = 0
var _b_id: int = 0
var _c_id: int = 0
var _saw_dead_a: bool = false
var _saw_dead_b: bool = false
var _saw_dead_c: bool = false
var _lost_ids: Dictionary = {}
var _frame: int = 0

func _ready() -> void:
	var world: Node2D = Node2D.new()
	world.name = "World"
	add_child(world)
	_make_floor(world)
	EventBus.candy_piece_lost.connect(_on_lost)
	_a = _spawn(world, Vector2(200.0, FLOOR_TOP_Y - 360.0), false, true)
	_b = _spawn(world, Vector2(320.0, FLOOR_TOP_Y - 190.0), false, false)
	_c = _spawn(world, Vector2(440.0, FLOOR_TOP_Y - 360.0), true, true)
	_a_id = _a.get_instance_id()
	_b_id = _b.get_instance_id()
	_c_id = _c.get_instance_id()
	print("[StunFallTest] driver ready — threshold=%.0fpx" % _a.stun_fall_threshold())

func _spawn(world: Node2D, pos: Vector2, floater: bool, carrying: bool) -> Ant:
	var a: Ant = ANT_SCENE.instantiate() as Ant
	a.position = pos
	world.add_child(a)
	if floater:
		a.set_trait(&"floater")
	if carrying:
		a.has_candy = true
		a.has_been_carrying = true
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

func _on_lost(a: Ant) -> void:
	if a != null:
		_lost_ids[a.get_instance_id()] = true

func _is_dead(a) -> bool:
	# 파라미터 untyped — free된 인스턴스를 넘겨도 호출 경계 타입체크 에러 없이 is_instance_valid로 차단.
	return is_instance_valid(a) and a.state_machine != null and a.state_machine.current_state is DeadState

func _physics_process(_delta: float) -> void:
	_frame += 1
	# DeadState 관측 — 기절은 종료까지 유지되므로 freed 걱정 없이 매 frame 폴링.
	if _is_dead(_a):
		_saw_dead_a = true
	if _is_dead(_b):
		_saw_dead_b = true
	if _is_dead(_c):
		_saw_dead_c = true
	if _frame < DEADLINE_FRAMES:
		return
	_evaluate()

func _evaluate() -> void:
	var fails: Array[String] = []

	# A — 기절: DeadState 관측 + 사탕 lost + 종료까지 DeadState 유지(swim 표류처럼 제거 X).
	if not _saw_dead_a:
		fails.append("A: DeadState(기절) 미관측 — 5칸+ 낙하가 기절로 안 빠짐")
	if not _lost_ids.has(_a_id):
		fails.append("A: candy_piece_lost 미발생 — 운반 기절 회계 누락")
	if not is_instance_valid(_a):
		fails.append("A: 기절 개미가 제거됨 — 스테이지 종료까지 유지 기대(queue_free 금지)")
	elif not (_a.state_machine != null and _a.state_machine.current_state is DeadState):
		fails.append("A: 기절 개미가 DeadState를 벗어남 — 종착 상태 유지 위반")

	# B — 생존(저낙하): alive 유지 + 기절 X.
	if not is_instance_valid(_b):
		fails.append("B: 저낙하(4칸)인데 제거됨 — 생존 기대")
	elif _saw_dead_b:
		fails.append("B: 저낙하(4칸)인데 기절(DeadState) 발생")
	elif not _b.is_alive():
		fails.append("B: 저낙하 후 alive=false")

	# C — floater 생존: alive 유지 + 기절 X + 사탕 유지(lost X).
	if not is_instance_valid(_c):
		fails.append("C: floater인데 제거됨 — 높이 무관 생존 기대")
	elif _saw_dead_c:
		fails.append("C: floater인데 기절(DeadState) 발생 — floater 무효 위반")
	elif not _c.has_candy:
		fails.append("C: floater 운반 사탕 유실")
	if _lost_ids.has(_c_id):
		fails.append("C: floater 운반인데 candy_piece_lost 발생")

	if fails.size() > 0:
		push_error("StunFallTest FAIL\n" + "\n".join(fails))
		print("[StunFallTest] FAIL\n", "\n".join(fails))
		get_tree().quit(1)
	else:
		print("[StunFallTest] PASS — A 기절+lost+종료까지 유지 / B 저낙하 생존 / C floater 생존(사탕 유지)")
		get_tree().quit(0)
