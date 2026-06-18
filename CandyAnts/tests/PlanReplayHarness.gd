extends Node

# auto-solver Phase 1 — 플랜 리플레이 하니스 (헤드리스 씬). spike SolverHarness의 일반화 후속.
#
# env CANDYANTS_PLAN_PATH의 플랜 JSON을 읽어 PlanRunner로 실제 게임을 결정론 헤드리스 재생하고,
# 무수정 게임 verdict를 `SOLVER_RESULT {json}` 한 줄로 보고한다(D4). run_plan.py가 이 씬을 띄운다.
#
# 출력: stdout `SOLVER_RESULT {json}` — {cleared,saved,lost,hp,reason,frame,actions_fired,...}.
# quit code: 0=클리어(saved>=1), 1=미클리어, 2=에러.

var _runner: PlanRunner = null

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
	_runner = PlanRunner.new()
	add_child(_runner)
	_runner.finished.connect(_on_finished)
	_runner.run(parsed)

func _on_finished(result: Dictionary) -> void:
	print("SOLVER_RESULT %s" % JSON.stringify(result))
	if result.has("error"):
		get_tree().quit(2)
		return
	var cleared: bool = bool(result.get("cleared", false)) and int(result.get("saved", 0)) >= 1
	get_tree().quit(0 if cleared else 1)

func _emit_error(msg: String) -> void:
	print("SOLVER_RESULT %s" % JSON.stringify({"error": msg}))
	get_tree().quit(2)
