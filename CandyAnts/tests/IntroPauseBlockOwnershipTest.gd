extends Node

# Phase 4 (codex impl-review R2 MEDIUM) — InputRouter pause-block 소유권 분리.
# StepFrame 게이트(set_pause_actions_blocked)와 인트로 카드 게이트(set_intro_pause_blocked)는
# 독립 저장 → 한쪽 release가 다른 쪽 block을 clobber하지 못한다(공유 bool 시 clobber 재현).
# 시나리오: stepping 중(StepFrame block) replay가 새 stage+카드 로드(인트로 block) → in-flight
# StepFrame continuation의 _release_gate()가 카드 block을 지우면 begin 전 모달 게이트가 뚫림.

var _failed: bool = false

func _ready() -> void:
	if InputRouter.are_pause_actions_blocked():
		return _fail("baseline: expected unblocked")

	# 두 소유자 모두 ON (stepping 중 카드 표시 interleaving 모사)
	InputRouter.set_pause_actions_blocked(true)    # StepFrame acquire
	InputRouter.set_intro_pause_blocked(true)       # SceneFlow 카드 표시
	if not InputRouter.are_pause_actions_blocked():
		return _fail("both ON: expected blocked")

	# in-flight StepFrame continuation release → 자기 게이트만 내려야 함
	InputRouter.set_pause_actions_blocked(false)
	if not InputRouter.are_pause_actions_blocked():
		return _fail("StepFrame release cleared intro block (clobber!)")

	# 카드 dismiss → 인트로 게이트 내림 → 완전 해제
	InputRouter.set_intro_pause_blocked(false)
	if InputRouter.are_pause_actions_blocked():
		return _fail("after both released: expected unblocked")

	# 역방향 — 인트로 release가 StepFrame 게이트를 clobber하지 않음
	InputRouter.set_intro_pause_blocked(true)
	InputRouter.set_pause_actions_blocked(true)
	InputRouter.set_intro_pause_blocked(false)
	if not InputRouter.are_pause_actions_blocked():
		return _fail("intro release cleared StepFrame block (reverse clobber!)")
	InputRouter.set_pause_actions_blocked(false)
	if InputRouter.are_pause_actions_blocked():
		return _fail("cleanup: expected unblocked")

	print("[IntroPauseBlockOwnershipTest] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	InputRouter.set_pause_actions_blocked(false)
	InputRouter.set_intro_pause_blocked(false)
	print("[IntroPauseBlockOwnershipTest] FAIL ", msg)
	get_tree().quit(1)
