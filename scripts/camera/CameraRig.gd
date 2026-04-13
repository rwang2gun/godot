extends Node3D

## =====================================================================
##  CameraRig — SpringArm3D 기반 오빗 카메라
##  구면좌표(theta/phi)로 회전, SpringArm3D로 벽 충돌 회피
## =====================================================================

var theta          : float = 0.0      # 수평 회전 (라디안)
var phi            : float = 0.42     # 수직 각도 (라디안, 0=수평 1.2=위에서)
var target_distance: float = 7.0

const MOUSE_SENS   : float = 0.003
const PHI_MIN      : float = 0.1
const PHI_MAX      : float = 1.2
const FOLLOW_SPEED : float = 8.0

var _target: Node3D = null

@onready var _pitch: Node3D      = $Pitch
@onready var _spring: SpringArm3D = $Pitch/SpringArm3D
@onready var _camera: Camera3D    = $Pitch/SpringArm3D/Camera3D


func set_target(t: Node3D) -> void:
	_target = t


func _ready() -> void:
	_spring.spring_length = target_distance
	_spring.add_excluded_object(get_parent())  # 자기 자신 제외


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
	var follow_pos: Vector3 = _target.global_position + Vector3(0, 0.6, 0)
	global_position = global_position.lerp(follow_pos, FOLLOW_SPEED * delta)

	# 수평 회전 (yaw)
	rotation.y = theta

	# 수직 회전 (pitch)
	_pitch.rotation.x = -phi

	# SpringArm이 거리와 충돌 회피를 자동 처리
	_spring.spring_length = target_distance
