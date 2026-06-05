class_name LeafChargeState extends AntState

# 나뭇잎 점프대 발동 직전의 차징(눌림) 대기 (2026-06-06).
# 점프대 셀에 도착한 적격 개미를 CHARGE_TIME초 동안 제자리에 고정했다가, 시간이 차면
# Ant.leaf_jump_launch(cells)로 포물선 비행(LeafJumpState)을 발사한다. LeafJumpPad가
# 본 상태 진입/이탈을 관찰해 점프대 스프라이트를 pad → pressed → sprung로 교체한다.
#
# 대기 동안 개미를 "제자리 고정"하는 이유:
#  - 즉시 발사하면 끈끈이 직전 눌림(0.25초) 연출이 불가능하다.
#  - 고정하지 않고 대기하면 개미가 끈끈이 셀로 걸어가 정지(is_stuck)해 점프가 실패한다.
# 고정 = 좌우 속도 0 + 중력만으로 바닥에 붙여 둠. direction은 유지되어 발사 방향이 보존된다.

var _cells: int = 0
var _charge_time: float = 0.0
var _elapsed: float = 0.0
var _launched: bool = false

func _init(cells: int, charge_time: float) -> void:
	_cells = cells
	_charge_time = charge_time

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	a.velocity = Vector2.ZERO

func update(delta: float) -> void:
	var a: Ant = ant as Ant
	if a == null or _launched:
		return
	# 제자리 고정 — 좌우 정지 + 중력만으로 바닥에 붙어 대기.
	a.velocity.x = 0.0
	a.velocity.y += a.gravity * delta
	a.move_and_slide()
	_elapsed += delta
	if _elapsed >= _charge_time:
		_launched = true
		# 발사 성공 시 leaf_jump_launch가 LeafJumpState로 전이한다(여기서 current_state 교체됨).
		# 발사 실패(지형 없음 등)면 보행 복귀로 안전 종료해 차징 상태에 영구 정체하지 않는다.
		if not a.leaf_jump_launch(_cells):
			a.return_to_walking()
