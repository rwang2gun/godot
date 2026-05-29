extends Node2D
# Verify-only 임시 도구 — climber/floater 스킬 뱃지가 캐릭터 꼬리(진행 반대쪽)에 붙는지,
# direction에 따라 좌우로 따라가는지 시각 확인. 운영 코드 아님 (StageVisualCapture 답습).
#
# Usage:
#   godot --path . res://tests/AntBadgeVisualCapture.tscn -- --out <abs>.png --frames 14

const ANT: PackedScene = preload("res://scenes/entities/Ant.tscn")

var _output: String = "D:/claude/godot/CandyAnts/verify_ant_tail_badge.png"
var _wait_frames: int = 16
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		match args[i]:
			"--out":
				if i + 1 < args.size():
					_output = args[i + 1]
			"--frames":
				if i + 1 < args.size():
					_wait_frames = int(args[i + 1])

	# 파스텔 배경
	var bg := CanvasLayer.new()
	bg.layer = -10
	add_child(bg)
	var rect := ColorRect.new()
	rect.color = Color(0.97, 0.92, 0.88)
	rect.size = Vector2(1920, 1080)
	bg.add_child(rect)

	# 바닥 (개미가 떨어지지 않게)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	add_child(floor_body)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(900, 60)
	cs.shape = shape
	cs.position = Vector2(450, 320)
	floor_body.add_child(cs)

	# 카메라 (두 개미 클로즈업)
	var cam := Camera2D.new()
	cam.position = Vector2(450, 250)
	cam.zoom = Vector2(2.4, 2.4)
	add_child(cam)
	cam.make_current()

	# 우향(+1) / 좌향(-1) 개미 둘 — 둘 다 climber+floater
	_spawn(Vector2(340, 285), 1)
	_spawn(Vector2(560, 285), -1)

func _spawn(pos: Vector2, dir: int) -> void:
	var a: Ant = ANT.instantiate() as Ant
	a.position = pos
	a.direction = dir
	add_child(a)
	a.set_trait(&"climber")
	a.set_trait(&"floater")

func _process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame < _wait_frames:
		return
	_done = true
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(_output)
	print("[ant-badge-capture] frame=%d err=%d -> %s" % [_frame, err, _output])
	get_tree().quit(0 if err == OK else 1)
