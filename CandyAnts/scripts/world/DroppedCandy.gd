class_name DroppedCandy extends Area2D

# 낙하산 분배자(FloaterSkill)가 운반 중 적용되어 바닥에 떨어뜨린 사탕 조각 (2026-06-03).
# 비운반 보행 개미(WalkerState, has_candy=false)가 닿으면 주워 운반(CarryingState)하고 사라진다.
# 자격: '운반중이 아닌 보행 개미 모두' — has_been_carrying 무관(재생성된 개미도 가능).
# 회계: 드롭 시 candy_piece_lost로 lost+1 처리됐던 조각을 candy_piece_recovered로 lost→in_transit 보정.

var _claimed: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _claimed:
		return
	var a: Ant = body as Ant
	if a == null or not is_instance_valid(a) or a.state_machine == null:
		return
	if a.has_candy:
		return
	if not (a.state_machine.current_state is WalkerState):
		return
	_claimed = true
	# Phase 20 컨벤션 — sfx id only (receiver는 phase 21).
	EventBus.sfx_request.emit(&"candy_pick")
	# 상태 전이를 먼저 — recovered 옵저버(ScoreSystem·테스트)가 has_candy=true인 정확한 상태를 보도록.
	a.state_machine.change_state(CarryingState.new())
	EventBus.candy_piece_recovered.emit(a)
	# Area2D 콜백 안에서 monitoring 직접 set 금지 — set_deferred. queue_free도 frame 끝 deferred.
	set_deferred("monitoring", false)
	queue_free()
