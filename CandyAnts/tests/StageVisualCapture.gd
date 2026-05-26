extends Node
# Visual capture driver — stage scene을 instantiate하고 N frame 후 viewport를 PNG로 저장.
# Verify-only 임시 도구 (스킬 변경 후 stage layout/sprite 시각 검증). 운영 코드 아님.
#
# Usage:
#   godot --path . res://tests/StageVisualCapture.tscn -- \
#       --stage res://scenes/stages/Stage01.tscn \
#       --out D:/claude/godot/CandyAnts/verify_stage01.png \
#       --frames 60

const DEFAULT_STAGE: String = "res://scenes/stages/Stage01.tscn"
const DEFAULT_OUT: String = "D:/claude/godot/CandyAnts/verify_stage.png"
const DEFAULT_FRAMES: int = 60

var _output: String = DEFAULT_OUT
var _wait_frames: int = DEFAULT_FRAMES
var _frame: int = 0
var _captured: bool = false

func _ready() -> void:
	var stage_path: String = DEFAULT_STAGE
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		match args[i]:
			"--stage":
				if i + 1 < args.size():
					stage_path = args[i + 1]
			"--out":
				if i + 1 < args.size():
					_output = args[i + 1]
			"--frames":
				if i + 1 < args.size():
					_wait_frames = int(args[i + 1])
	var ps: PackedScene = load(stage_path) as PackedScene
	if ps == null:
		push_error("[capture] load failed: %s" % stage_path)
		get_tree().quit(2)
		return
	print("[capture] stage=%s out=%s frames=%d" % [stage_path, _output, _wait_frames])
	add_child(ps.instantiate())

func _process(_delta: float) -> void:
	if _captured:
		return
	_frame += 1
	if _frame < _wait_frames:
		return
	_captured = true
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(_output)
	print("[capture] frame=%d err=%d -> %s" % [_frame, err, _output])
	get_tree().quit(0 if err == OK else 1)
