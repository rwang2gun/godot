class_name LostState extends AntState

# Phase 17 — hazard 진입으로 ant 탈락(§0.2 어휘) terminal state.
# enter()에서 candy_piece_lost emit(보유 시) + queue_free. exit() 없음.
# §0.2 어휘 정책: 기존 terminal state(PROPOSAL §7.5 deferred 잔존) 재사용하지 않고 신규 terminal로 도입.

func enter() -> void:
	var a: Ant = ant as Ant
	if a == null:
		return
	if a.has_candy:
		EventBus.candy_piece_lost.emit(a)
		# in_transit -1 처리는 ScoreSystem._on_lost가 수행.
		# has_candy 즉시 clear — 멱등성 (LostState 진입 후 추가 hazard 발화 시
		# is_alive() 가드로 차단되지만 추가 candy_piece_lost emit 방지 안전망).
		a.has_candy = false
	# Blocker hitbox 정리 — call_deferred (Area2D.body_entered 콜백에서 monitoring 직접 set 금지).
	# 멱등 — 이미 비활성이어도 no-op. queue_free도 frame 끝에 deferred 실행되므로 순서 무관.
	a.call_deferred("set_blocker_active", false)
	a.queue_free()
