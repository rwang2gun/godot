extends Node2D
# Verify-only 임시 도구 — 새 계단 비스킷 타일 연속성 + 45° 등반 회전 시각 검증.
# 운영 코드 아님. 평지 + 대각 STAIR 계단을 직접 깔고 ant 한 마리를 보행→등반시킨 뒤 PNG 캡처.
# 헤드리스 아님으로 실행해야 렌더됨:
#   "D:/Godot_v4.6.2-stable_win64_console.exe" --path . res://tests/StairClimbVisualCapture.tscn -- --frames 40

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")
const OUT: String = "D:/claude/godot/CandyAnts/verify_stair_climb.png"
const CS: int = 48
const GROUND_ROW: int = 8

var _output: String = OUT
var _wait_frames: int = 40
var _frame: int = 0
var _captured: bool = false
var _terrain: Terrain = null
var _ant: Ant = null

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--frames" and i + 1 < args.size():
			_wait_frames = int(args[i + 1])
		elif args[i] == "--out" and i + 1 < args.size():
			_output = args[i + 1]

	var cam: Camera2D = Camera2D.new()
	cam.position = Vector2(360, 260)
	cam.zoom = Vector2(2.2, 2.2)
	add_child(cam)
	cam.make_current()

	_terrain = Terrain.new()
	_terrain.name = "Terrain"
	_terrain.set_cell_size(CS)
	add_child(_terrain)

	# 평지 floor (bridge 타일 = 시각용 일반 floor) cols 0..5, row 8.
	for c in range(0, 6):
		_terrain.add_tile(Vector2i(c, GROUND_ROW), Terrain.DYNAMIC_TILE_BRIDGE)
	# 대각 STAIR 계단 — 우상향 "/": (6,7)(7,6)(8,5)(9,4)(10,3). 끊김 없는 비스킷 막대 확인용.
	for k in range(0, 5):
		_terrain.add_tile(Vector2i(6 + k, 7 - k), Terrain.DYNAMIC_TILE_STAIR, 1)
	# 꼭대기 착지 platform.
	for c in range(11, 14):
		_terrain.add_tile(Vector2i(c, 2), Terrain.DYNAMIC_TILE_BRIDGE)

	_ant = ANT_SCENE.instantiate() as Ant
	_ant.direction = 1
	# col2 ground 위에 배치 (floor top = GROUND_ROW*CS = 384, ant 중심을 살짝 위).
	_ant.global_position = Vector2(2 * CS + 24, GROUND_ROW * CS - 8)
	add_child(_ant)
	print("[StairClimbCapture] out=%s frames=%d" % [_output, _wait_frames])

func _process(_delta: float) -> void:
	if _captured:
		return
	_frame += 1
	# ant 상태 진단 — 캡처 프레임 고르기용.
	if _ant != null and is_instance_valid(_ant) and _ant.state_machine != null:
		var s: Object = _ant.state_machine.current_state
		var sn: String = s.get_script().resource_path.get_file() if s != null and s.get_script() != null else "?"
		if _frame % 5 == 0:
			print("[StairClimbCapture] frame=%d pos=%s state=%s rot=%.1f" % [
				_frame, _ant.global_position, sn,
				rad_to_deg(_ant._sprite.rotation) if _ant._sprite != null else 0.0])
	if _frame < _wait_frames:
		return
	_captured = true
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var err: int = img.save_png(_output)
	print("[StairClimbCapture] CAPTURED frame=%d err=%d -> %s" % [_frame, err, _output])
	get_tree().quit(0 if err == OK else 1)
