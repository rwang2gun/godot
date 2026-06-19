class_name PlanRunner
extends Node

# auto-solver Phase 1 — 플랜 리플레이 엔진 (spike SolverHarness 일반화·다중스킬·타이밍 트리거).
#
# 플랜(JSON dict)을 받아 실제 게임을 결정론 헤드리스로 재생한다. 매 _physics_process마다 각 액션의
# 트리거를 평가(스코프 = 활성 스테이지 루트 하위)하고, 발화 시 SkillApplier로 **인벤토리-충실** 적용
# (총량 = stage StageData.skill_inventory budget, D4). 무수정 게임 코드(StageRunner._conclude_stage)가
# 내는 stage_cleared/failed verdict를 캐치해 결과 dict로 emit(D4 비순환 — verdict는 게임 본체가 emit).
#
# 솔버는 게임 지식을 하드코딩하지 않는다(D7): 대상 방식("ant"/"cell")은 스킬 SOLVER_META에서 읽고
# (target 미지정 시), 적용은 SkillApplier 단일 규칙 출처를 경유한다.
#
# 사용:
#   var pr := PlanRunner.new(); add_child(pr)
#   pr.finished.connect(func(res): ...)
#   pr.run(plan_dict)
# 배치 재사용: finished 후 내부에서 스테이지를 free + EventBus 연결 해제 → 다음 run() 상태누수 0.

signal finished(result: Dictionary)

# 플랜/액션 스키마 (v1):
#   { "stage": "res://scenes/stages/Stage11.tscn", "deadline_frames": 7000,
#     "actions": [
#       # 개미 대상(②③): select로 후보 선정 + 트리거로 발화 시점 결정.
#       { "skill":"blocker",
#         "target": {"mode":"ant", "select":"max_x"|"min_x"|"spawn_index", "spawn_index":3,
#                    "y_min":520.0, "y_max":9999.0, "dir":-1, "state":"walker"|"any"},
#         "trigger": {"type":"ant_reaches_x", "cmp":"ge"|"le", "x":960.0},
#         "repeat": false },
#       # 셀 대상(①④): 표지판/장치 설치. cell 또는 world 좌표 + 발화 시점 트리거.
#       { "skill":"sand_mound", "target": {"mode":"cell", "cell":[20,14]},
#         "trigger": {"type":"at_frame", "frame":0} }
#     ] }
# trigger.type: at_frame{frame} | ant_reaches_x{cmp,x} | ant_at_cliff | ant_on_wall |
#               active_ants_le{n} | picked_ge{n} | after{ref(label/index),delay} | immediate.
# (at_frame/active_ants_le/picked_ge/after = 시점 게이팅; ant_* = 선택 개미 조건; immediate = 매 프레임 시도.)

var _plan: Dictionary = {}
var _stage: Node = null
var _actions: Array = []
var _inventory: Dictionary = {}       # id → 잔여 budget (StageData.skill_inventory에서 복제, D4)
var _deadline_frames: int = 16000
var _frame: int = 0
var _done: bool = false
var _running: bool = false
var _picked_total: int = 0
var _fired_frame: Dictionary = {}     # action label/index → 발화 프레임(after 트리거용)
var _actions_fired: int = 0
# verdict 수신은 글로벌 EventBus가 아니라 **현재 런 스테이지의 StageRunner 인스턴스 시그널**(concluded)로만
# 받는다(codex R3 HIGH). 같은 stage_id의 stale/동시 런이라도 다른 인스턴스의 시그널은 우리에게 안 오므로
# cross-talk가 구조적으로 불가능(StageData.id 비교 같은 약한 가드 불필요).
var _stage_runner: Node = null

# 프로세스 단일 활성 런 가드(codex R4 HIGH). ScoreSystem·글로벌 candy 이벤트(candy_piece_picked 등)는
# 스테이지-스코프가 아니라, 한 프로세스에 **두 스테이지가 동시에 살아있으면** 회계(saved/lost/in_transit)와
# picked_ge 트리거가 오염된다. 솔버 병렬화는 ScoreSystem을 재설계하는 대신 **별도 프로세스**로 한다
# (run_plan.py가 헤드리스 subprocess + CANDYANTS_SAVE_PATH pid 격리로 띄움 → 프로세스마다 autoload 독립).
# 한 프로세스엔 활성 PlanRunner 런이 1개뿐임을 이 가드가 강제 → 동시 cross-talk의 전제를 구조적으로 제거.
static var _active_run: PlanRunner = null
# SimConfig.deterministic는 프로세스-전역 플래그(StageRunner/AntSpawner/Home/Ant 타이밍 소비). run()이
# 강제로 켜므로, **우리가 켠 경우에만** 종료 시 이전 값으로 복원해 in-process 누수를 막는다(codex R7 MED).
var _prior_deterministic: bool = false
var _det_forced: bool = false

# 진척 휴리스틱 (Phase 2 탐색 원료 — spike에서 이관).
var _best_min_y: float = 1.0e20
var _any_picked: bool = false
var _best_carry_home_dist: float = 1.0e20
var _home_pos: Vector2 = Vector2(1.0e20, 1.0e20)

# verdict는 글로벌 버스가 아니라 현재 스테이지의 StageRunner.concluded(인스턴스 시그널)로 받는다(run()에서
# 연결). 여기선 진척 휴리스틱용 candy_piece_picked(글로벌)만 1회 연결 — 이건 verdict가 아니라 보조 지표라
# _running 가드로 충분. verdict 귀속 방어:
#   (1) 인스턴스 시그널 — 우리 스테이지 인스턴스만 우리에게 emit(다른/stale 스테이지는 닿지 않음).
#   (2) `_running`/`_done` 가드 — 런 밖/종료 후 무시.
#   (3) 종료/재시작 시 스테이지를 트리에서 **동기 분리**(_finish·_teardown의 remove_child) — 옛 스테이지 정지.
func _ready() -> void:
	if not EventBus.candy_piece_picked.is_connected(_on_picked):
		EventBus.candy_piece_picked.connect(_on_picked)

func run(plan: Dictionary) -> void:
	# 동시 in-process 런 금지(codex R4 HIGH) — 다른 PlanRunner가 활성이면 ScoreSystem/글로벌 candy
	# 이벤트가 오염되므로 시작하지 않고 error 반환. (자기 자신이 잡고 있던 락은 아래 _teardown이 해제.)
	if _active_run != null and is_instance_valid(_active_run) and _active_run != self:
		push_error("[PlanRunner] concurrent in-process run unsupported — 솔버 병렬화는 subprocess로(run_plan.py)")
		finished.emit({"error": "concurrent_run_unsupported"})
		return
	if _running:
		# 같은 인스턴스 재진입(첫 런 진행 중 run() 재호출) — 첫 런을 teardown으로 중단하면 그 런의
		# finished가 영영 안 나와 await 호출자가 hang한다(codex R5 HIGH). 첫 런을 보존하기 위해
		# teardown/emit 없이 거부한다(여기서 finished.emit하면 첫 런 await 호출자가 오인).
		push_error("[PlanRunner] run() while this instance is still running — ignored(첫 런 보존)")
		return
	# 이전 런이 남긴(또는 중단된) 스테이지를 즉시 강제 정리 — stale stage가 새 런에 verdict를
	# 흘리는 race 차단(codex R1 HIGH). run()은 시그널 콜백 밖이라 free() 안전.
	# (_teardown은 우리가 강제했던 deterministic도 복원하므로, 아래 capture는 복원된 현재값을 읽는다.)
	_teardown()
	# 결정론은 스테이지 인스턴스 *전에* 켜야 stage _ready가 플래그를 본다(spike 관행). 이전 값을
	# 잡아 두고(우리가 켠 표식) 종료 시 복원 — 전역 플래그 in-process 누수 차단(codex R7 MED).
	_prior_deterministic = SimConfig.deterministic
	SimConfig.set_deterministic(true)
	_det_forced = true
	_reset_state()
	_plan = plan
	_deadline_frames = int(plan.get("deadline_frames", 16000))
	_actions = (plan.get("actions", []) as Array).duplicate(true)
	for i in range(_actions.size()):
		var a: Dictionary = _actions[i]
		a["_fired"] = false
		a["_index"] = i
		# 명시 label 우선, 없으면 skill#i. after 트리거 ref는 label 또는 index(문자열) 둘 다 가능.
		a["_label"] = str(a.get("label", "%s#%d" % [str(a.get("skill", "?")), i]))
	var stage_path: String = str(plan.get("stage", ""))
	var packed: PackedScene = load(stage_path) as PackedScene
	if packed == null:
		_finish({"error": "could not load stage: %s" % stage_path})
		return
	_stage = packed.instantiate()
	add_child(_stage)
	# D4 budget — 실행 중 스테이지의 StageData.skill_inventory를 권위로 사용(드라이버·플랜이 임의 증액 못 함).
	# 스테이지 씬 루트가 곧 StageRunner라 find_children(루트 제외)로는 못 잡으므로 루트를 우선 확인.
	var sr: Node = _stage if (_stage is StageRunner) else _find_node_of_class("StageRunner")
	if sr != null and sr.get("stage_data") != null:
		var sd: Resource = sr.get("stage_data")
		if sd != null and "skill_inventory" in sd:
			_inventory = (sd.skill_inventory as Dictionary).duplicate(true)
	# verdict는 이 스테이지 인스턴스의 concluded 시그널로만 수신(codex R3 HIGH — 글로벌 버스 cross-talk 차단).
	_stage_runner = sr
	if sr != null and sr.has_signal("concluded") and not sr.concluded.is_connected(_on_concluded):
		sr.concluded.connect(_on_concluded)
	var homes: Array = _stage.find_children("*", "Home", true, false)
	if not homes.is_empty():
		_home_pos = (homes[0] as Node2D).global_position
	_active_run = self     # 단일 활성 런 락 획득(codex R4 HIGH)
	_running = true
	print("[PlanRunner] stage=%s actions=%d deadline=%d inventory=%s" % [
		stage_path, _actions.size(), _deadline_frames, str(_inventory)])

# 진행 중이던(또는 직전) 스테이지를 트리에서 즉시 떼어내고 free. run() 컨텍스트(시그널 콜백 밖)
# 호출이라 free() 안전. 정상 종료 시엔 _finish가 이미 queue_free·_stage=null 했으니 보통 no-op.
# 런 도중 queue_free/씬 teardown으로 **취소**될 때 전역 상태 누수 차단(codex R8 MED):
# deterministic 복원 + 단일-활성-런 락 해제 + verdict 시그널 해제. finished는 emit하지 않는다
# (취소를 정상 종료로 오해시키지 않음). _stage는 자식이라 이 노드와 함께 자동 free.
func _exit_tree() -> void:
	_restore_deterministic()
	if _active_run == self:
		_active_run = null
	if _stage_runner != null and is_instance_valid(_stage_runner) \
			and _stage_runner.has_signal("concluded") and _stage_runner.concluded.is_connected(_on_concluded):
		_stage_runner.concluded.disconnect(_on_concluded)
	_stage_runner = null

# 우리가 강제했던 SimConfig.deterministic를 이전 값으로 복원(우리가 켠 경우에만). 멱등.
func _restore_deterministic() -> void:
	if _det_forced:
		SimConfig.set_deterministic(_prior_deterministic)
		_det_forced = false

func _teardown() -> void:
	_restore_deterministic()
	if _stage_runner != null and is_instance_valid(_stage_runner) \
			and _stage_runner.has_signal("concluded") and _stage_runner.concluded.is_connected(_on_concluded):
		_stage_runner.concluded.disconnect(_on_concluded)
	_stage_runner = null
	if _stage != null and is_instance_valid(_stage):
		var parent: Node = _stage.get_parent()
		if parent != null:
			parent.remove_child(_stage)
		_stage.free()
	_stage = null
	_running = false
	_done = false
	if _active_run == self:
		_active_run = null     # 단일 활성 런 락 해제

func _reset_state() -> void:
	_stage = null
	_actions = []
	_inventory = {}
	_frame = 0
	_done = false
	_running = false
	_picked_total = 0
	_fired_frame = {}
	_actions_fired = 0
	_stage_runner = null
	_best_min_y = 1.0e20
	_any_picked = false
	_best_carry_home_dist = 1.0e20
	_home_pos = Vector2(1.0e20, 1.0e20)

func _physics_process(_delta: float) -> void:
	if not _running or _done:
		return
	_frame += 1
	_track_progress()
	_evaluate_actions()
	if _frame > _deadline_frames:
		_report(false, 0, 0, -1, "deadline")

func _on_picked(_remaining_hp: int) -> void:
	if not _running or _done:
		return
	_picked_total += 1

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

func _evaluate_actions() -> void:
	for a in _actions:
		var act: Dictionary = a
		var repeat: bool = bool(act.get("repeat", false))
		if act.get("_fired", false) and not repeat:
			continue
		if not _time_ready(act):
			continue
		var skill: String = str(act.get("skill", ""))
		if skill == "":
			continue
		if _target_mode(act, skill) == "cell":
			if _fire_cell(act, skill):
				_mark_fired(act)
		else:
			var ant: Ant = _select_ant(act)
			if ant == null:
				continue
			if not _ant_trigger_ok(act, ant):
				continue
			if SkillApplier.apply_to_ant(skill, ant, _inventory):
				print("[PlanRunner] %s -> spawn_index=%d pos=%s frame=%d" % [
					skill, ant.spawn_index, str(ant.global_position), _frame])
				_mark_fired(act)

func _mark_fired(act: Dictionary) -> void:
	act["_fired"] = true
	# after 앵커는 **첫 발화** 프레임으로 고정한다(codex R6 MED). repeat:true 액션이 매번 덮어쓰면
	# 의존 액션의 after가 "첫 발화+delay"가 아니라 마지막 발화까지 밀리므로, 키가 없을 때만 기록.
	# label·index 두 키 모두 지원(after.ref가 label/index 어느 쪽이든 해결, codex R5 MED).
	var label: String = str(act.get("_label"))
	var idx: String = str(act.get("_index"))
	if not _fired_frame.has(label):
		_fired_frame[label] = _frame
	if not _fired_frame.has(idx):
		_fired_frame[idx] = _frame
	_actions_fired += 1

# 대상 방식 결정 — target.mode 우선, 없으면 스킬 SOLVER_META.target(D7), 그래도 없으면 "ant".
func _target_mode(act: Dictionary, skill: String) -> String:
	var t: Dictionary = act.get("target", {})
	if t.has("mode"):
		return str(t["mode"])
	var meta: Dictionary = SkillRegistry.solver_meta(skill)
	return str(meta.get("target", "ant"))

# 시점 게이팅 트리거(개미 무관). ant_* / immediate은 여기서 항상 true(조건은 _ant_trigger_ok에서).
func _time_ready(act: Dictionary) -> bool:
	var trig: Dictionary = act.get("trigger", {})
	var ttype: String = str(trig.get("type", "immediate"))
	match ttype:
		"at_frame":
			return _frame >= int(trig.get("frame", 0))
		"active_ants_le":
			return _active_ant_count() <= int(trig.get("n", 0))
		"picked_ge":
			return _picked_total >= int(trig.get("n", 0))
		"after":
			var ref: String = str(trig.get("ref", ""))
			if not _fired_frame.has(ref):
				return false
			return _frame >= int(_fired_frame[ref]) + int(trig.get("delay", 0))
		_:
			return true

# 셀 대상 발화 — 표지판/장치를 cell(또는 world)에 설치. 성공 시 true.
func _fire_cell(act: Dictionary, skill: String) -> bool:
	var terrain: Terrain = _find_node_of_class("Terrain") as Terrain
	if terrain == null:
		return false
	var parent: Node = terrain.get_parent()
	if parent == null:
		return false
	var t: Dictionary = act.get("target", {})
	var where: Variant
	if t.has("cell"):
		var c: Array = t["cell"]
		where = Vector2i(int(c[0]), int(c[1]))
	elif t.has("world"):
		var w: Array = t["world"]
		where = Vector2(float(w[0]), float(w[1]))
	else:
		return false
	var res: Dictionary = SkillApplier.place_on_cell(skill, terrain, where, parent, _inventory)
	if bool(res.get("placed", false)):
		print("[PlanRunner] %s placed cell=%s frame=%d" % [skill, str(res.get("cell")), _frame])
		return true
	return false

# 개미 대상 후보 선택 — 활성 스테이지 루트 하위 walker(또는 any) 중 y-band/dir 필터 통과분에서
# select(max_x/min_x/spawn_index). tie-break = spawn_index(결정론). 없으면 null.
func _select_ant(act: Dictionary) -> Ant:
	var t: Dictionary = act.get("target", {})
	var y_min: float = float(t.get("y_min", -1.0e20))
	var y_max: float = float(t.get("y_max", 1.0e20))
	var want_dir: int = int(t.get("dir", 0))
	var sel: String = str(t.get("select", "max_x"))
	var state_filter: String = str(t.get("state", "walker"))
	var want_spawn: int = int(t.get("spawn_index", -1))
	var best: Ant = null
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if _stage == null or not _stage.is_ancestor_of(a):
			continue
		if not _state_ok(a, state_filter):
			continue
		var p: Vector2 = a.global_position
		if p.y < y_min or p.y > y_max:
			continue
		if want_dir != 0 and a.direction != want_dir:
			continue
		if sel == "spawn_index":
			if a.spawn_index == want_spawn:
				return a
			continue
		if best == null:
			best = a
		elif sel == "min_x":
			if p.x < best.global_position.x or (p.x == best.global_position.x and a.spawn_index < best.spawn_index):
				best = a
		else: # max_x
			if p.x > best.global_position.x or (p.x == best.global_position.x and a.spawn_index < best.spawn_index):
				best = a
	return best

func _state_ok(a: Ant, state_filter: String) -> bool:
	if state_filter == "any":
		return a.is_alive()
	var s: AntState = a.state_machine.current_state
	if state_filter == "carrying":
		return s is CarryingState
	# 기본 "walker" — 보행 walker(드라이버 관행). spike와 동일.
	return s is WalkerState

# 선택된 개미에 대한 트리거 조건(개미 의존 트리거만; 그 외는 _time_ready가 게이팅).
func _ant_trigger_ok(act: Dictionary, ant: Ant) -> bool:
	var trig: Dictionary = act.get("trigger", {})
	var ttype: String = str(trig.get("type", "immediate"))
	match ttype:
		"ant_reaches_x":
			var cmp: String = str(trig.get("cmp", "ge"))
			var thr: float = float(trig.get("x", 0.0))
			var bx: float = ant.global_position.x
			return bx <= thr if cmp == "le" else bx >= thr
		"ant_at_cliff":
			return ant.cliff_ahead()
		"ant_on_wall":
			return not ant.forward_cell_open()
		_:
			return true

func _active_ant_count() -> int:
	var c: int = 0
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if _stage == null or not _stage.is_ancestor_of(a):
			continue
		if a.is_alive():
			c += 1
	return c

# 스테이지 루트 하위에서 class_name이 cls인 첫 노드(StageRunner/Terrain/Home). find_children는
# 루트 자신을 제외하지만 이들은 모두 스테이지 하위 노드라 안전.
func _find_node_of_class(cls: String) -> Node:
	if _stage == null:
		return null
	var found: Array = _stage.find_children("*", cls, true, false)
	if not found.is_empty():
		return found[0]
	return null

# 현재 런 스테이지(StageRunner)의 인스턴스 시그널 — 무수정 게임이 계산한 결과 dict를 그대로 받는다(D4).
# 인스턴스 스코프라 다른/stale 스테이지의 verdict는 여기 오지 않는다(codex R3 HIGH 해소).
func _on_concluded(result: Dictionary) -> void:
	if not _running or _done:
		return
	_report(bool(result.get("cleared", false)), int(result.get("saved", -1)),
		int(result.get("lost", -1)), int(result.get("original_hp", -1)),
		str(result.get("reason", "concluded")))

func _report(cleared: bool, saved: int, lost: int, hp: int, reason: String) -> void:
	if _done:
		return
	var out: Dictionary = {
		"cleared": cleared, "saved": saved, "lost": lost, "hp": hp,
		"reason": reason, "frame": _frame, "actions_fired": _actions_fired,
		"best_min_y": (_best_min_y if _best_min_y < 1.0e19 else -1.0),
		"picked": _any_picked,
		"best_carry_home_dist": (_best_carry_home_dist if _best_carry_home_dist < 1.0e19 else -1.0),
	}
	_finish(out)

# 결과 emit + 스테이지 정리. 시그널은 _ready에서 1회 연결돼 인스턴스 수명 동안 유지(해제 안 함);
# verdict 귀속은 _running/_done 가드 + run()의 _teardown으로 보장(상단 _ready 주석). 스테이지는
# 자기 시그널 콜백 안에서 호출될 수 있어 queue_free(지연)로 안전 해제 — 다음 run()의 _teardown이
# 미처리분을 즉시 강제 정리한다.
func _finish(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	_running = false
	_restore_deterministic()   # 전역 deterministic 복원(우리가 켠 경우만) — in-process 누수 차단(codex R7 MED)
	# 인스턴스 verdict 시그널 해제(곧 free될 스테이지지만 명시적으로). 자기 콜백 중 disconnect 안전.
	if _stage_runner != null and is_instance_valid(_stage_runner) \
			and _stage_runner.has_signal("concluded") and _stage_runner.concluded.is_connected(_on_concluded):
		_stage_runner.concluded.disconnect(_on_concluded)
	_stage_runner = null
	# 스테이지를 트리에서 **동기적으로** 분리한 뒤 queue_free — 분리 즉시 _process/emit이 멈춰,
	# finished 콜백서 곧장 재실행해도 옛 스테이지가 late verdict를 흘릴 수 없다(codex R2 HIGH).
	# remove_child는 시그널 콜백 안에서도 안전(노드는 살아있고 트리에서만 빠짐), 메모리 해제는 지연.
	if _stage != null and is_instance_valid(_stage):
		var parent: Node = _stage.get_parent()
		if parent != null:
			parent.remove_child(_stage)
		_stage.queue_free()
		_stage = null
	if _active_run == self:
		_active_run = null     # 단일 활성 런 락 해제
	finished.emit(result)
