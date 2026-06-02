class_name DeadState extends AntState

# 기절(stun) terminal state — 2026-06-02 재활용(구: 즉시 queue_free, 호출부 없던 dead code).
# 게임은 사망을 직접 묘사하지 않는다: 5칸+ 자유낙하한 개미는 기절 스프라이트를 ~1초 재생한 뒤
# 사라진다(queue_free). 회계는 LostState와 동일 — 운반 중이었다면 candy_piece_lost 정산.
# FallerState가 (착지y − 시작y) >= stun_fall_threshold() + floater 미보유일 때 본 state로 전이.
# 기절 스프라이트는 Ant._update_sprite의 DeadState→"stun" 매핑이 매 frame 재생한다.

const STUN_DURATION_SECONDS: float = 1.0

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	# 착지 후 정지 — DeadState.update는 no-op라 move_and_slide 미호출, 그 자리에 멈춰 기절을 재생.
	a.velocity = Vector2.ZERO
	if a.has_candy:
		# 회계 LostState 동일 — 운반 조각 1개 lost 정산(ScoreSystem._on_lost가 in_transit -1).
		# has_candy 즉시 clear로 멱등(추가 lost emit 방지). sfx id는 P21 receiver 대기.
		EventBus.sfx_request.emit(&"candy_lost")
		EventBus.candy_piece_lost.emit(a)
		a.has_candy = false
	# 기절 효과음 id — 운반 여부 무관 1회(P21 receiver 대기, 미연결이면 no-op).
	EventBus.sfx_request.emit(&"ant_stun")
	# Blocker hitbox 정리 — call_deferred(Area2D 콜백 안전, 멱등). 낙하 기절이라 보통 비활성이지만 방어적.
	a.call_deferred("set_blocker_active", false)
	# 기절 스프라이트 ~1초 재생 후 제거. ant가 먼저 free되면 a.queue_free Callable이 invalid → 안전 skip.
	var tree: SceneTree = a.get_tree()
	if tree == null:
		a.queue_free()
		return
	tree.create_timer(STUN_DURATION_SECONDS).timeout.connect(a.queue_free)
