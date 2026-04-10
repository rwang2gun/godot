extends Node3D

# =====================================================================
#  CameraRig — 플레이어를 따라다니는 오빗 카메라
#  마우스 드래그(캡처 모드) : 수평/수직 회전
#  theta : 수평각,  phi : 수직각
# =====================================================================

var theta          : float   = 0.0      # 수평 회전 (라디안)
var phi            : float   = 0.42     # 수직 각도 (라디안, 0=수평 1.2=위에서)
var distance       : float   = 7.0      # 현재 거리
var target_distance: float   = 7.0      # 목표 거리 (상태에 따라 변경)

const MOUSE_SENS   : float   = 0.003
const PHI_MIN      : float   = 0.1
const PHI_MAX      : float   = 1.2
const FOLLOW_SPEED : float   = 8.0
const DIST_SPEED   : float   = 5.0

var _target: Node3D = null

@onready var _camera: Camera3D = $Camera3D

func set_target(t: Node3D) -> void:
	_target = t

# --- 마우스 입력 ---
func _input(event: InputEvent) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		theta -= event.relative.x * MOUSE_SENS
		phi    = clampf(phi - event.relative.y * MOUSE_SENS, PHI_MIN, PHI_MAX)

func _process(delta: float) -> void:
	if not _target:
		return

	# 타겟 위치 스무스 추적
	var follow_pos := _target.global_position + Vector3(0, 0.6, 0)
	global_position = global_position.lerp(follow_pos, FOLLOW_SPEED * delta)

	# 거리 스무스 보간
	distance = lerpf(distance, target_distance, DIST_SPEED * delta)

	# 카메라 오빗 위치 계산
	# 구면 좌표: theta=수평, phi=수직
	var cx := sin(theta) * cos(phi) * distance
	var cy := sin(phi)             * distance
	var cz := cos(theta) * cos(phi) * distance

	_camera.position = Vector3(cx, cy, cz)
	_camera.look_at(global_position, Vector3.UP)
