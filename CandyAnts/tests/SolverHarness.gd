extends Node

# auto-solver spike — blocker 전용 플랜 리플레이 하니스 (Phase 1 PlanRunner 전구체).
#
# 목적: 솔버(Python)가 만든 *후보 플랜*(blocker 배치 목록)을 받아 **실제 게임을 결정론 헤드리스로** 재생하고,
# 무수정 게임 코드(StageRunner._conclude_stage)가 내는 클리어/실패 verdict를 JSON으로 보고한다(D4).
# 손코딩 CampaignSxx 드라이버를 데이터(플랜)로 대체하는 첫 수직 슬라이스. blocker만 지원(S11/S12 인벤토리).
#
# 입력: env CANDYANTS_PLAN_PATH = 플랜 JSON 파일 경로.
#   { "stage": "res://scenes/stages/Stage12.tscn", "deadline_frames": 8000, "blocker_budget": 3,
#     "actions": [ {"sel":"min_x"|"max_x", "x":264.0, "cmp":"le"|"ge",
#                   "y_min":580.0, "y_max":9999.0, "dir": -1 (optional) } ] }
#   각 action = "y-band 안에서 select(min_x/max_x)된 walker가 cmp(x, threshold)를 만족하면 그 개미에 blocker 1회".
#
# 출력(stdout): `SOLVER_RESULT {json}` 한 줄 — {cleared, saved, lost, hp, reason, frame, blockers_used}. quit code: 0=클리어(saved>=1), 1=미클리어.
#
# 결정론: _ready에서 SimConfig.set_deterministic(true) 후 스테이지를 *프로그램적으로* 인스턴스
# (.tscn 자식이면 스테이지 _ready가 먼저 돌아 결정론 플래그를 못 봄). 헤드리스는 --fixed-fps로 가속.

var _plan: Dictionary = {}
var _stage: Node = null
var _actions: Array = []          # 각 원소에 "_fired" 플래그를 얹어 사용
var _blocker_budget: int = 0
var _blockers_used: int = 0
var _deadline_frames: int = 16000
var _frame: int = 0
var _done: bool = false
# 진척 휴리스틱 — beam search가 클리어 못한 플랜끼리 우열을 가릴 때 사용.
# _best_min_y: 어떤 개미든 도달한 최고점(작을수록 높이 올라감). 등반 진척 프록시.
# _any_picked: candy를 한 번이라도 운반한 개미가 있었나(왕복의 절반=픽업 달성).
# _best_carry_home_dist: 운반 중 개미가 home에 가장 가까이 간 거리(왕복 완성 근접도). 픽업+복귀를 포착해
#   "올라가기만" 편향을 교정 — S12류 왕복 스테이지에서 단조 height 휴리스틱의 함정을 보완.
var _best_min_y: float = 1.0e20
var _any_picked: bool = false
var _best_carry_home_dist: float = 1.0e20
var _home_pos: Vector2 = Vector2(1.0e20, 1.0e20)

func _ready() -> void:
	var path: String = OS.get_environment("CANDYANTS_PLAN_PATH")
	if path == "":
		_emit_error("CANDYANTS_PLAN_PATH not set")
		return
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		_emit_error("plan file empty or unreadable: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_emit_error("plan JSON not an object: %s" % path)
		return
	_plan = parsed
	_deadline_frames = int(_plan.get("deadline_frames", 16000))
	_blocker_budget = int(_plan.get("blocker_budget", 0))
	_actions = (_plan.get("actions", []) as Array).duplicate(true)
	for a in _actions:
		(a as Dictionary)["_fired"] = false
	var stage_path: String = str(_plan.get("stage", ""))

	SimConfig.set_deterministic(true)
	EventBus.stage_cleared.connect(_on_concluded.bind(true))
	EventBus.stage_failed.connect(_on_concluded.bind(false))
	var packed: PackedScene = load(stage_path) as PackedScene
	if packed == null:
		_emit_error("could not load stage: %s" % stage_path)
		return
	_stage = packed.instantiate()
	add_child(_stage)
	var homes: Array = _stage.find_children("*", "Home", true, false)
	if not homes.is_empty():
		_home_pos = (homes[0] as Node2D).global_position
	print("[SolverHarness] stage=%s budget=%d actions=%d deadline=%d" % [
		stage_path, _blocker_budget, _actions.size(), _deadline_frames])

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_track_progress()
	_apply_actions()
	if _frame > _deadline_frames:
		_report(false, 0, 0, -1, "deadline")

func _track_progress() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if _stage == null or not _stage.is_ancestor_of(a):
			continue
		if a.global_position.y < _best_min_y:
			_best_min_y = a.global_position.y
		if a.has_candy:
			_any_picked = true
			if _home_pos.x < 1.0e19:
				var d: float = a.global_position.distance_to(_home_pos)
				if d < _best_carry_home_dist:
					_best_carry_home_dist = d

func _apply_actions() -> void:
	if _blockers_used >= _blocker_budget:
		return
	for a in _actions:
		var act: Dictionary = a
		if act.get("_fired", false):
			continue
		var ant: Ant = _select_target(act)
		if ant == null:
			continue
		var skill: BlockerSkill = BlockerSkill.new()
		if not skill.can_apply(ant):
			continue
		skill.apply(ant)
		act["_fired"] = true
		_blockers_used += 1
		print("[SolverHarness] blocker -> spawn_index=%d pos=%s frame=%d (%d/%d)" % [
			ant.spawn_index, str(ant.global_position), _frame, _blockers_used, _blocker_budget])
		if _blockers_used >= _blocker_budget:
			return

# 활성 스테이지 루트 하위 walker 중 y-band + dir 필터 통과분에서 select(min_x/max_x). 그 개미가 cmp(x, threshold)
# 충족 시 반환(트리거 발화), 아니면 null. CarryingState도 blocker 대상이지만 트리거는 보행 walker 기준(드라이버 관행).
func _select_target(act: Dictionary) -> Ant:
	var y_min: float = float(act.get("y_min", -1.0e20))
	var y_max: float = float(act.get("y_max", 1.0e20))
	var want_dir: int = int(act.get("dir", 0))
	var sel: String = str(act.get("sel", "max_x"))
	var best: Ant = null
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if _stage == null or not _stage.is_ancestor_of(a):
			continue
		if not (a.state_machine.current_state is WalkerState):
			continue
		var p: Vector2 = a.global_position
		if p.y < y_min or p.y > y_max:
			continue
		if want_dir != 0 and a.direction != want_dir:
			continue
		if best == null:
			best = a
		elif sel == "min_x":
			if p.x < best.global_position.x or (p.x == best.global_position.x and a.spawn_index < best.spawn_index):
				best = a
		else: # max_x
			if p.x > best.global_position.x or (p.x == best.global_position.x and a.spawn_index < best.spawn_index):
				best = a
	if best == null:
		return null
	var cmp: String = str(act.get("cmp", "ge"))
	var thr: float = float(act.get("x", 0.0))
	var bx: float = best.global_position.x
	if cmp == "le":
		return best if bx <= thr else null
	return best if bx >= thr else null

func _on_concluded(result: Dictionary, _cleared: bool) -> void:
	if _done:
		return
	_report(bool(result.get("cleared", false)), int(result.get("saved", -1)),
		int(result.get("lost", -1)), int(result.get("original_hp", -1)), str(result.get("reason", "")))

func _report(cleared: bool, saved: int, lost: int, hp: int, reason: String) -> void:
	if _done:
		return
	_done = true
	var out: Dictionary = {
		"cleared": cleared, "saved": saved, "lost": lost, "hp": hp,
		"reason": reason, "frame": _frame, "blockers_used": _blockers_used,
		"best_min_y": (_best_min_y if _best_min_y < 1.0e19 else -1.0),
		"picked": _any_picked,
		"best_carry_home_dist": (_best_carry_home_dist if _best_carry_home_dist < 1.0e19 else -1.0),
	}
	print("SOLVER_RESULT %s" % JSON.stringify(out))
	# 솔버는 별 1개(=saved>=1)면 클리어. exit 0=클리어, 1=미클리어.
	get_tree().quit(0 if (cleared and saved >= 1) else 1)

func _emit_error(msg: String) -> void:
	if _done:
		return
	_done = true
	print("SOLVER_RESULT %s" % JSON.stringify({"error": msg}))
	get_tree().quit(2)
