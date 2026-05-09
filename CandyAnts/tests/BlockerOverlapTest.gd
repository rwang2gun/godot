extends Node

# Phase 4 sweep regression — Codex adversarial review HIGH:
# Blocker bounce는 유입 방향(direction)을 반전해야 한다.
# post-overlap 위치 기반은 활성화 순간 깊은 overlap·큰 delta에서 통과 방향을
# 그대로 유지시켜 stage3 보장을 깨뜨릴 수 있음.
#
# §B-1 +1 진입 ant가 blocker 중심을 5px 통과한 상태에서 활성화되어도 -1로 반전
# §B-2 -1 진입 ant가 blocker 중심을 5px 통과한 상태에서 활성화되어도 +1로 반전
# §B-3 정상(통과 전) 진입에서도 기존 동작 유지 — 회귀 방지
# §B-4 WorkerState(=다른 Blocker)는 영향 받지 않음 — 무한 반전 차단 유지
# §B-5 같은 physics frame에 두 blocker가 발화해도 한 번만 반전 (Codex round 2 HIGH 대응
#       idempotency — 두 번 flip되어 원래 방향 복귀하는 결함 방지)
# §B-6 같은 (blocker, walker) 쌍의 body_entered가 cross-frame으로 재발화해도 두 번째부터는
#       direction 유지. body_exited 후 다음 frame 재진입은 다시 bounce 가능 (Codex round 4
#       HIGH 대응 — overlap-scoped guard 추가)
# §B-7 walker가 blocker A에 overlap 중인 상태로 distinct blocker B에 다른 frame에 진입하면
#       B는 정상 bounce해야 함 (Codex round 5 HIGH 대응 — overlap-only guard로는 B contact가
#       영구 소비되어 A exit 후에도 재발화 못 하는 결함 방지)
# §B-8 same-frame 다중 blocker의 game-design semantics 검증 (Codex round 7 HIGH 대응):
#       - signal order 역순(B-then-A)에서도 §B-5와 동일하게 단 1회 flip
#       - synthetic next-frame replay(body_exited 없는 재발화)는 suppress — 지연된
#         double-flip이 §B-5의 "한 번만 반전" spec을 깨는 것 방지
#       - body_exited 후 재진입은 정상 bounce — 영구 suppress가 아님을 검증
#
# 직접 _on_blocker_body_entered를 호출하여 bounce 결정 로직만 격리 테스트.
# PASS: get_tree().quit(0). FAIL: quit(1).

const ANT_SCENE: PackedScene = preload("res://scenes/entities/Ant.tscn")

func _ready() -> void:
	var blocker: Ant = ANT_SCENE.instantiate()
	add_child(blocker)
	blocker.global_position = Vector2.ZERO
	blocker.set_blocker_active(true)

	# §B-1: +1 진입, 중심 5px 통과한 상태 (rel_x > 0, direction=1)
	# OLD bug: rel_x >= 0이라 direction=1로 그대로 → 통과
	# NEW: -direction = -1 → 좌측으로 반전
	if not _expect_bounce(blocker, Vector2(5.0, 0.0), 1, -1, "§B-1 +1 deep overlap"):
		return

	# §B-2: -1 진입, 중심 5px 통과한 상태 (rel_x < 0, direction=-1)
	# OLD bug: rel_x < 0이라 direction=-1로 그대로 → 통과
	# NEW: -direction = 1 → 우측으로 반전
	if not _expect_bounce(blocker, Vector2(-5.0, 0.0), -1, 1, "§B-2 -1 deep overlap"):
		return

	# §B-3: +1 진입, 아직 진입 측(rel_x < 0) — 정상 케이스 회귀 방지
	if not _expect_bounce(blocker, Vector2(-5.0, 0.0), 1, -1, "§B-3 +1 entry side (regression)"):
		return

	# §B-4: WorkerState(다른 blocker)는 무시되어야 함
	var worker_ant: Ant = ANT_SCENE.instantiate()
	add_child(worker_ant)
	worker_ant.global_position = Vector2(5.0, 0.0)
	worker_ant.direction = 1
	# WorkerState 직접 적용 (다른 Blocker로 가정)
	worker_ant.state_machine.change_state(WorkerState.new("blocker"))
	blocker._on_blocker_body_entered(worker_ant)
	if worker_ant.direction != 1:
		print("[BlockerOverlapTest] FAIL §B-4 WorkerState ant should not be redirected, ",
			"expected direction=1 got=", worker_ant.direction)
		get_tree().quit(1)
		return
	print("[BlockerOverlapTest] PASS §B-4 WorkerState ant unaffected")

	# §B-5: 같은 physics frame에 두 blocker가 동시 발화해도 단 1회만 반전.
	# 두 번 flip되면 +1 → -1 → +1 로 원위치 복귀해 통과 — 그 결함을 차단하는지 검증.
	var blocker2: Ant = ANT_SCENE.instantiate()
	add_child(blocker2)
	blocker2.global_position = Vector2(20.0, 0.0)
	blocker2.set_blocker_active(true)

	var dual_walker: Ant = ANT_SCENE.instantiate()
	add_child(dual_walker)
	dual_walker.global_position = Vector2(10.0, 0.0)  # 두 blocker 사이
	dual_walker.direction = 1
	# 동기 호출 = 같은 physics frame. 첫 발화는 반전, 두 번째는 frame guard로 무시.
	blocker._on_blocker_body_entered(dual_walker)
	blocker2._on_blocker_body_entered(dual_walker)
	if dual_walker.direction != -1:
		print("[BlockerOverlapTest] FAIL §B-5 dual blocker same-frame: expected direction=-1 got=",
			dual_walker.direction)
		get_tree().quit(1)
		return
	print("[BlockerOverlapTest] PASS §B-5 dual blocker same-frame idempotent")

	# §B-6: cross-frame replay — 같은 (blocker, walker) 쌍의 body_entered가 재발화해도
	#        두 번째부터는 direction 유지 (overlap-scoped guard). body_exited 후 다른
	#        frame에 재진입하면 정상 bounce 복귀.
	var replay_blocker: Ant = ANT_SCENE.instantiate()
	add_child(replay_blocker)
	replay_blocker.global_position = Vector2(50.0, 0.0)
	replay_blocker.set_blocker_active(true)

	var replay_walker: Ant = ANT_SCENE.instantiate()
	add_child(replay_walker)
	replay_walker.global_position = Vector2(45.0, 0.0)
	replay_walker.direction = 1
	replay_blocker._on_blocker_body_entered(replay_walker)
	if replay_walker.direction != -1:
		print("[BlockerOverlapTest] FAIL §B-6 first entry: expected direction=-1 got=",
			replay_walker.direction)
		get_tree().quit(1)
		return
	# 같은 overlap이 재발화 (body_exited 없이 body_entered 재호출) — set 멤버십으로 skip
	replay_blocker._on_blocker_body_entered(replay_walker)
	if replay_walker.direction != -1:
		print("[BlockerOverlapTest] FAIL §B-6 same-pair replay flipped direction: expected -1 got=",
			replay_walker.direction)
		get_tree().quit(1)
		return
	# body_exited 후 다른 frame에 재진입은 정상 bounce 복귀 — physics_frame 진행시켜야
	# per-frame guard도 풀림.
	replay_blocker._on_blocker_body_exited(replay_walker)
	await get_tree().physics_frame
	replay_blocker._on_blocker_body_entered(replay_walker)
	if replay_walker.direction != 1:
		print("[BlockerOverlapTest] FAIL §B-6 re-entry after exit: expected direction=1 got=",
			replay_walker.direction)
		get_tree().quit(1)
		return
	print("[BlockerOverlapTest] PASS §B-6 cross-frame replay idempotent + re-entry")

	# §B-7: walker가 blocker A에 overlap 중인 상태로 distinct blocker B에 다른 frame에
	#        진입하면 B는 정상 bounce해야 함. overlap-only guard만 쓰면 B의 contact가
	#        영구 소비되어 A exit 후에도 재발화 못 하는 결함 (Codex round 5 HIGH 대응).
	var seqA: Ant = ANT_SCENE.instantiate()
	add_child(seqA)
	seqA.global_position = Vector2(100.0, 0.0)
	seqA.set_blocker_active(true)

	var seqB: Ant = ANT_SCENE.instantiate()
	add_child(seqB)
	seqB.global_position = Vector2(120.0, 0.0)
	seqB.set_blocker_active(true)

	var seq_walker: Ant = ANT_SCENE.instantiate()
	add_child(seq_walker)
	seq_walker.global_position = Vector2(95.0, 0.0)
	seq_walker.direction = 1
	seqA._on_blocker_body_entered(seq_walker)
	if seq_walker.direction != -1:
		print("[BlockerOverlapTest] FAIL §B-7 step1 A entry: expected -1 got=",
			seq_walker.direction)
		get_tree().quit(1)
		return
	# 다른 physics frame에 B에 진입 — A는 여전히 overlap 중, B는 distinct
	await get_tree().physics_frame
	seqB._on_blocker_body_entered(seq_walker)
	if seq_walker.direction != 1:
		print("[BlockerOverlapTest] FAIL §B-7 step2 B distinct cross-frame entry: ",
			"expected direction=1 (B should bounce) got=", seq_walker.direction)
		get_tree().quit(1)
		return
	print("[BlockerOverlapTest] PASS §B-7 cross-frame distinct blocker still bounces")

	# §B-8: same-frame 다중 blocker의 정확한 semantics 검증 (Codex round 7 HIGH 대응).
	#        signal order B→A 역순에서도 §B-5와 동일하게 1회만 flip. synthetic next-frame
	#        replay(body_exited 없는 재발화)는 suppress해 지연된 double-flip 방지. 단
	#        body_exited 후 재진입은 fresh bounce — overlap-lifetime 한정의 idempotency.
	var s8_blockerB: Ant = ANT_SCENE.instantiate()
	add_child(s8_blockerB)
	s8_blockerB.global_position = Vector2(200.0, 0.0)
	s8_blockerB.set_blocker_active(true)

	var s8_blockerA: Ant = ANT_SCENE.instantiate()
	add_child(s8_blockerA)
	s8_blockerA.global_position = Vector2(220.0, 0.0)
	s8_blockerA.set_blocker_active(true)

	var s8_walker: Ant = ANT_SCENE.instantiate()
	add_child(s8_walker)
	s8_walker.global_position = Vector2(210.0, 0.0)
	s8_walker.direction = 1
	# Walker 물리 동결 — await 동안의 자연 이동/body_exited가 set을 정리하면 synthetic
	# replay 시나리오를 재현 못 함. _physics_process를 끄고 collision shape도 비활성화.
	s8_walker.set_physics_process(false)
	var s8_walker_col: CollisionShape2D = s8_walker.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if s8_walker_col != null:
		s8_walker_col.set_deferred("disabled", true)
	await get_tree().physics_frame  # collision disable 적용

	# (a) 역순 signal: B → A 같은 frame. B만 bounce, A는 skip — §B-5 대칭 검증.
	s8_blockerB._on_blocker_body_entered(s8_walker)
	s8_blockerA._on_blocker_body_entered(s8_walker)
	if s8_walker.direction != -1:
		print("[BlockerOverlapTest] FAIL §B-8(a) reverse-order same-frame: expected -1 got=",
			s8_walker.direction)
		get_tree().quit(1)
		return

	# (b) synthetic next-frame replay — A는 set에 기록되어 있어 body_exited 없는 재발화는
	#     suppress. 만약 A가 다시 bounce하면 walker direction이 +1로 복귀해 §B-5의
	#     "한 번만 반전" spec을 frame 1개 지연해서 깨는 결함이 됨 (Codex round 7 HIGH).
	await get_tree().physics_frame
	s8_blockerA._on_blocker_body_entered(s8_walker)
	if s8_walker.direction != -1:
		print("[BlockerOverlapTest] FAIL §B-8(b) synthetic next-frame replay double-flipped: ",
			"expected direction=-1 (still suppressed) got=", s8_walker.direction)
		get_tree().quit(1)
		return

	# (c) body_exited 후 재진입은 fresh bounce — 영구 suppress가 아님을 검증.
	s8_blockerA._on_blocker_body_exited(s8_walker)
	await get_tree().physics_frame
	s8_blockerA._on_blocker_body_entered(s8_walker)
	if s8_walker.direction != 1:
		print("[BlockerOverlapTest] FAIL §B-8(c) re-entry after exit should bounce: ",
			"expected direction=1 got=", s8_walker.direction)
		get_tree().quit(1)
		return
	print("[BlockerOverlapTest] PASS §B-8 reverse-order + synthetic-replay suppression + ",
		"re-entry-after-exit fresh bounce")

	print("[BlockerOverlapTest] PASS")
	get_tree().quit(0)

func _expect_bounce(blocker: Ant, walker_pos: Vector2, walker_dir: int,
		expected_dir: int, label: String) -> bool:
	var walker: Ant = ANT_SCENE.instantiate()
	add_child(walker)
	walker.global_position = walker_pos
	walker.direction = walker_dir
	blocker._on_blocker_body_entered(walker)
	if walker.direction != expected_dir:
		print("[BlockerOverlapTest] FAIL ", label, " expected direction=", expected_dir,
			" got=", walker.direction)
		get_tree().quit(1)
		return false
	print("[BlockerOverlapTest] PASS ", label)
	return true
