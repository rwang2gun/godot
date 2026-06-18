extends Node

# auto-solver Phase 0 — 결정론 게이트.
# 한 스테이지(Stage11)를 결정론 모드(SimConfig.deterministic=true)에서 **동일 빈 플랜으로 2회**
# in-process 실행하고, 매 프레임 개미 스냅샷(spawn_index·위치·속도·상태·방향·has_candy) + 종단 결과가
# 완전히 일치하는지 단언한다. 종단만 비교하지 않는 이유: move_and_slide/Area2D 순서의 부동소수
# 비결정성을 **조기**(어긋난 첫 프레임에서) 검출하기 위함.
#
# 스테이지는 드라이버 _ready에서 SimConfig를 켠 뒤 *프로그램적으로* 인스턴스한다 — .tscn에 자식으로
# 두면 스테이지 _ready(자식 우선)가 드라이버보다 먼저 돌아 결정론 플래그를 못 보기 때문.
# 스킬은 적용하지 않는다(빈 플랜): 결정론 자체만 검증.
#
# PASS: run1 == run2 (per-frame + 종단). FAIL: 첫 불일치 프레임/결과 보고.

const STAGE_PATH: String = "res://scenes/stages/Stage11.tscn"
const DEADLINE_FRAMES: int = 16000

enum Phase { RUN1, BETWEEN, RUN2, DONE }

var _phase: int = Phase.RUN1
var _stage: Node = null
var _rel_frame: int = 0
var _run1: Array[String] = []
var _run2: Array[String] = []
var _run1_result: String = ""
var _run2_result: String = ""
var _concluded: bool = false
var _done: bool = false

func _ready() -> void:
	SimConfig.set_deterministic(true)
	EventBus.stage_cleared.connect(_on_concluded.bind(true))
	EventBus.stage_failed.connect(_on_concluded.bind(false))
	print("[DeterminismReplayTest] deterministic=", SimConfig.deterministic, " stage=", STAGE_PATH)
	_start_stage()

func _start_stage() -> void:
	_rel_frame = 0
	_concluded = false
	var packed: PackedScene = load(STAGE_PATH) as PackedScene
	if packed == null:
		_fail("could not load stage scene %s" % STAGE_PATH)
		return
	_stage = packed.instantiate()
	add_child(_stage)

func _physics_process(_delta: float) -> void:
	if _done:
		return
	match _phase:
		Phase.RUN1:
			_tick_run(_run1)
		Phase.BETWEEN:
			# run1 정리 완료 — run2 인스턴스(한 프레임 gap으로 queue_free 정착 보장).
			_phase = Phase.RUN2
			_start_stage()
		Phase.RUN2:
			_tick_run(_run2)

func _tick_run(buf: Array[String]) -> void:
	buf.append(_snapshot())
	_rel_frame += 1
	if _concluded:
		_finish_run()
	elif _rel_frame > DEADLINE_FRAMES:
		# 결정론 자체는 검증 가능하므로 deadline도 "동일 deadline"이면 PASS 처리(아래 _finish_run).
		_concluded = true
		_record_result("deadline rel_frame=%d" % _rel_frame)
		_finish_run()

func _finish_run() -> void:
	# 스테이지 언로드 — EventBus 연결은 Home/StageRunner._exit_tree가 정리(배치 누수 차단 패턴 선행).
	if _stage != null:
		remove_child(_stage)
		_stage.queue_free()
		_stage = null
	if _phase == Phase.RUN1:
		_phase = Phase.BETWEEN
	else:
		_compare()

func _compare() -> void:
	if _run1.size() != _run2.size():
		_fail("frame count differs: run1=%d run2=%d (result1=%s result2=%s)" % [
			_run1.size(), _run2.size(), _run1_result, _run2_result])
		return
	for i in range(_run1.size()):
		if _run1[i] != _run2[i]:
			_fail("snapshot mismatch at rel_frame=%d\n  run1: %s\n  run2: %s" % [i, _run1[i], _run2[i]])
			return
	if _run1_result != _run2_result:
		_fail("result mismatch: run1=%s run2=%s" % [_run1_result, _run2_result])
		return
	print("[DeterminismReplayTest] PASS frames=%d result=%s" % [_run1.size(), _run1_result])
	_done = true
	get_tree().quit(0)

# 활성 스테이지 루트 하위 alive 개미를 spawn_index→instance_id 순으로 직렬화. instance_id는 run 간
# 다르므로 *비교값*에는 넣지 않고 정렬 tie-break에만 사용(스냅샷 문자열은 spawn_index 기준).
func _snapshot() -> String:
	var ants: Array = []
	for n in get_tree().get_nodes_in_group("ants"):
		if not is_instance_valid(n):
			continue
		if _stage == null or not _stage.is_ancestor_of(n):
			continue
		ants.append(n)
	ants.sort_custom(func(a, b):
		if a.spawn_index != b.spawn_index:
			return a.spawn_index < b.spawn_index
		return a.get_instance_id() < b.get_instance_id())
	var parts: PackedStringArray = []
	for n in ants:
		var a: Ant = n as Ant
		var st: String = "?"
		if a.state_machine != null and a.state_machine.current_state != null:
			st = a.state_machine.current_state.get_class()
			var scr: Script = a.state_machine.current_state.get_script()
			if scr != null and scr.resource_path != "":
				st = scr.resource_path.get_file()
		parts.append("%d:%s:%s:%s:%d:%s" % [
			a.spawn_index, str(a.global_position), str(a.velocity), st, a.direction, str(a.has_candy)])
	return "|".join(parts)

func _on_concluded(result: Dictionary, _cleared: bool) -> void:
	if _done or _concluded:
		return
	_concluded = true
	_record_result("cleared=%s saved=%d lost=%d reason=%s" % [
		str(result.get("cleared", "?")), int(result.get("saved", -1)),
		int(result.get("lost", -1)), str(result.get("reason", "?"))])

func _record_result(s: String) -> void:
	if _phase == Phase.RUN1:
		_run1_result = s
	else:
		_run2_result = s

func _fail(msg: String) -> void:
	print("[DeterminismReplayTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
