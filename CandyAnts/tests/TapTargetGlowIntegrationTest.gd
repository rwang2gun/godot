extends Node

# Phase 2 — 실제 stage 씬 배선 통합 테스트 (codex R1 HIGH 대응).
# Stage01(climber)을 로드해 ① AffordanceGlowController가 씬에 존재하고 NodePath로 toolbar/terrain을
# 해소했는지 ② 스킬 선택 시 _process(실 폴링)가 적격 개미를 글로우하는지 — 컨트롤러 private 필드를
# 수동 주입하지 않고 검증한다(누락된 통합 지점을 실제로 통과).

const DEADLINE: int = 6000

var _frame: int = 0
var _settle_frame: int = -1
var _done: bool = false
var _phase: int = 0
var _ctrl: AffordanceGlowController = null
var _tb: SkillToolbar = null

func _ready() -> void:
	await get_tree().process_frame
	var root: Node = get_tree().current_scene
	_ctrl = _find_by_name(root, "AffordanceGlowController") as AffordanceGlowController
	_tb = _find_by_name(root, "SkillToolbar") as SkillToolbar
	if _ctrl == null:
		_fail("AffordanceGlowController not found in stage scene (씬 미배선)")
		return
	if _tb == null:
		_fail("SkillToolbar not found in stage scene")
		return
	# NodePath export 해소 검증 — 수동 주입 없이 씬 배선만으로 연결됐는지.
	if _ctrl._toolbar == null:
		_fail("controller._toolbar unresolved — toolbar_path 배선 깨짐")
		return
	if _ctrl._terrain == null:
		_fail("controller._terrain unresolved — terrain_path 배선 깨짐")
		return
	print("[TapTargetGlowIntegrationTest] wiring OK — controller resolved toolbar+terrain")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if _frame > DEADLINE:
		_fail("deadline — no walker-on-floor ant appeared")
		return
	if _phase == 0:
		if _first_walker_on_floor() != null:
			# 실제 toolbar의 선택 상태만 세팅(컨트롤러는 이 필드를 폴링) — private 글로우 필드는 주입 안 함.
			_tb._pending_skill_id = "climber"
			_settle_frame = _frame
			_phase = 1
	elif _phase == 1:
		# _process(컨트롤러 폴링)가 몇 frame 돌도록 대기 후 글로우 상태 관찰.
		if _frame - _settle_frame >= 3:
			var glow_count: int = 0
			for n in get_tree().get_nodes_in_group("ants"):
				var a: Ant = n as Ant
				if a == null:
					continue
				var s: Node = a.get_node_or_null("Sprite")
				if s != null and s.has_meta(Glow.META_KEY):
					glow_count += 1
			if glow_count <= 0:
				_fail("climber 선택 후에도 글로우 개미 0 — 실 씬에서 글로우 미작동")
				return
			if _ctrl._surface_marker != null and _ctrl._surface_marker.visible:
				_fail("climber(ANT)인데 surface marker가 표시됨")
				return
			print("[TapTargetGlowIntegrationTest] PASS — %d ant(s) glowing on real Stage01" % glow_count)
			_done = true
			get_tree().quit(0)

func _first_walker_on_floor() -> Ant:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not a.is_alive():
			continue
		if a.state_machine != null and a.state_machine.current_state is WalkerState and a.is_on_floor():
			return a
	return null

func _find_by_name(n: Node, target: String) -> Node:
	if n == null:
		return null
	if n.name == target:
		return n
	for c in n.get_children():
		var found: Node = _find_by_name(c, target)
		if found != null:
			return found
	return null

func _fail(msg: String) -> void:
	push_error("TapTargetGlowIntegrationTest FAIL: " + msg)
	print("[TapTargetGlowIntegrationTest] FAIL ", msg)
	_done = true
	get_tree().quit(1)
