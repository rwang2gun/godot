class_name LeafJumpState extends AntState

# 나뭇잎 점프대 발동 시 포물선 비행 (2026-06-05). 전방 cells타일을 일정 수평속도 + 초기 상승속도 +
# 중력으로 호를 그리며 날아가 끈끈이 너머에 착지한다. 모션은 낙하(fall) 애니메이션 재사용
# (Ant._update_sprite가 LeafJumpState → "fall" 매핑). 비행 내내 끈끈이 면역(Ant._leaf_jumping=true).
#
# FallerState를 쓰지 않는 이유: FallerState가 velocity.x를 보행속도 0.5배로 매 frame 덮어써 수평
# 도달 거리를 제어할 수 없다. 본 state는 vx를 일정하게 유지해 도달 거리(포물선 사거리)를 결정한다.
# vx/vy0는 Ant.leaf_jump_launch가 "정점 2타일·사거리 cells타일"(평지) 조건으로 산출해 넘긴다.

var _vx: float = 0.0          # 일정 수평 속도(부호 포함)
var _vy0: float = 0.0         # 초기 수직 속도(상승 = 음수)
var _airborne: bool = false   # 발사 직후 첫 frame은 아직 바닥 위 → 이륙 확인 후에만 착지 판정
var _frames: int = 0          # 실패 안전장치 — 천장/벽에 막혀 영영 이륙·착지 못 할 때 강제 종료

# 비행이 비정상적으로 길어지면(천장에 갇힘 등) 강제 복귀. 4타일 평지 호는 ~45 frame이라 넉넉.
const _MAX_FLIGHT_FRAMES: int = 240

func _init(vx: float, vy0: float) -> void:
	_vx = vx
	_vy0 = vy0

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	a.velocity = Vector2(_vx, _vy0)

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	_frames += 1
	a.velocity.y += a.gravity * delta
	a.velocity.x = _vx   # 일정 수평 속도 유지 → 포물선 사거리 결정(좌우 흔들림/감속 없음).
	a.move_and_slide()

	# 이륙 확인: 바닥을 벗어난 적이 있어야 착지 판정 시작(발사 frame의 잔존 is_on_floor 오판 방지).
	if not a.is_on_floor():
		_airborne = true
	elif _airborne:
		# 끈끈이 너머 착지 — 면역 해제 후 보행/운반 복귀(has_candy 분기는 return_to_walking이 처리).
		a.end_leaf_jump()
		a.return_to_walking()
		return

	if _frames >= _MAX_FLIGHT_FRAMES:
		# 안전장치: 막혀서 정상 착지 못 하면 강제 복귀(면역 해제 포함).
		a.end_leaf_jump()
		a.return_to_walking()
