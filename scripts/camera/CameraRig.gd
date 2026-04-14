class_name CameraRig
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
	# 타겟 CharacterBody3D를 SpringArm 충돌에서 제외 (플레이어 캡슐에 카메라가 끌려들어가는 문제 방지)
	if t is CollisionObject3D and _spring:
		_spring.add_excluded_object(t.get_rid())


func _ready() -> void:
	_spring.spring_length = target_distance
	# Main 트리에 있는 모든 CharacterBody3D를 spring 충돌에서 제외
	# (Player, CharacterEF, CharacterWM, 고블린들 — 카메라가 캡슐 안에 있어 raycast가 자신에 맞는 문제)
	call_deferred("_exclude_all_character_bodies")


func _exclude_all_character_bodies() -> void:
	var root_node: Node = get_tree().current_scene
	if root_node == null:
		return
	_exclude_recursive(root_node)


func _exclude_recursive(node: Node) -> void:
	if node is CharacterBody3D:
		_spring.add_excluded_object((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_exclude_recursive(child)


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
