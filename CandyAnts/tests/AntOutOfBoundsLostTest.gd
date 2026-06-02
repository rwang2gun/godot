extends Node

# Out-of-bounds 탈락 검증 — 개미가 플레이 영역(layout.tile_map 범위) 밖으로 벗어나면
# LostState로 처리되는지(아래·좌·우 3방향) + 인바운드 개미는 안 죽는지.
# 최소 world(StageLayoutBuilder+layout {"0,0":"solid"}, cell_size 48):
#   _kill_x_min=(0-3)*48=-144  _kill_x_max=(0+1+3)*48=192  _kill_y=(0+1+3)*48=192
# 배치:
#   bottom(사탕보유): (24, 600)  → y>192  → lost + candy_piece_lost 1회
#   left (빈손):      (-500, -40)→ x<-144 → lost, emit 없음
#   right(빈손):      (1000,-40) → x>192  → lost, emit 없음
#   inside(빈손,대조):(24, -40)  → 범위 내 → 생존(false-trigger 가드)
# 기대: OOB 3마리 모두 queue_free 제거, inside 생존, candy_piece_lost == 1.
#
# PASS: quit(0). FAIL: quit(1). DEADLINE: 120 frame(2초 @ 60fps).

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const DEADLINE_FRAMES: int = 120

var _lost_count: int = 0
var _bottom: Ant = null
var _left: Ant = null
var _right: Ant = null
var _inside: Ant = null
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.candy_piece_lost.connect(_on_lost)
	_build_world()
	print("[AntOutOfBoundsLostTest] driver ready")

func _build_world() -> void:
	var world: Node2D = Node2D.new()
	world.name = "World"
	add_child(world)

	# Ant._resolve_mantle_distance가 ancestor에서 "StageLayoutBuilder" 자식 + .layout을 찾는다.
	var layout: StageLayoutData = StageLayoutData.new()
	layout.cell_size = 48
	layout.tile_map = {"0,0": "solid"}
	var builder: StageLayoutBuilder = StageLayoutBuilder.new()
	builder.name = "StageLayoutBuilder"
	builder.layout = layout
	world.add_child(builder)   # ants 추가 전에 builder가 ancestor 스캔에 잡히도록 먼저.

	_bottom = _spawn(world, Vector2(24.0, 600.0), true)    # 아래 + 사탕보유
	_left = _spawn(world, Vector2(-500.0, -40.0), false)   # 좌
	_right = _spawn(world, Vector2(1000.0, -40.0), false)  # 우
	_inside = _spawn(world, Vector2(24.0, -40.0), false)   # 범위 내(대조 — 생존해야)

func _spawn(world: Node2D, pos: Vector2, carrying: bool) -> Ant:
	var a: Ant = ANT_SCENE.instantiate() as Ant
	a.has_candy = carrying
	a.position = pos
	world.add_child(a)
	return a

func _on_lost(_by_ant: Node) -> void:
	_lost_count += 1

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1

	var oob_gone: bool = (not is_instance_valid(_bottom)
		and not is_instance_valid(_left)
		and not is_instance_valid(_right))

	if oob_gone:
		# OOB 3마리 제거 완료 시점에 검증.
		if not is_instance_valid(_inside):
			_fail("inside ant(범위 내)가 잘못 제거됨 — false-trigger")
			return
		if _lost_count != 1:
			_fail("expected candy_piece_lost == 1 (bottom carry only) but got %d" % _lost_count)
			return
		print("[AntOutOfBoundsLostTest] PASS frame=%d oob_removed=3 inside_alive=true lost_emits=%d" % [_frame, _lost_count])
		_done = true
		get_tree().quit(0)
		return

	if _frame > DEADLINE_FRAMES:
		_fail("deadline — bottom=%s left=%s right=%s inside=%s lost=%d" % [
			str(is_instance_valid(_bottom)), str(is_instance_valid(_left)),
			str(is_instance_valid(_right)), str(is_instance_valid(_inside)), _lost_count])

func _fail(msg: String) -> void:
	print("[AntOutOfBoundsLostTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
