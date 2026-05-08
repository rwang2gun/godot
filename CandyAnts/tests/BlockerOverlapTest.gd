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
