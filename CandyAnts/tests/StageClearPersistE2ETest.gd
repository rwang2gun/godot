extends Node

# E2E 회귀 — 실제 Main 씬에서 Stage01을 자연 클리어시킨 뒤, SaveData가 디스크에 영속하고
# "재실행"(fresh load) 후에도 cleared/unlock이 복원되는지 검증한다.
# (스테이지 클리어 → 다음 스테이지 해금이 게임 재실행 후에도 유지됨을 보장하는 단일 진입점 테스트.)
# SaveData는 autoload라 엔진 부트에서 user://save.cfg를 이미 로드한 상태 → 테스트 시작 시 temp 경로로
# 전환(_test_reset)해 실제 save.cfg를 오염시키지 않는다.

const TEMP_PATH := "user://test_clear_persist_e2e.cfg"

var _main: Node = null
var _scene_flow: Node = null
var _handled: bool = false
var _frame: int = 0

func _ready() -> void:
	Engine.time_scale = 8.0
	# SaveData를 temp 경로로 전환(실제 저장 보호) + 기존 잔여 파일 정리.
	SaveData._test_cleanup_files(TEMP_PATH)
	SaveData._test_reset(TEMP_PATH)

	_main = $Main
	_scene_flow = _main.get_node("SceneFlow")
	if _scene_flow == null:
		_fail("SceneFlow missing")
		return
	EventBus.stage_cleared.connect(_on_cleared)
	await get_tree().process_frame
	if _scene_flow.current_screen != _scene_flow.ScreenState.STAGE:
		_scene_flow.load_stage(1)
		await get_tree().process_frame
		await get_tree().process_frame

func _physics_process(_delta: float) -> void:
	if _handled:
		return
	_frame += 1
	if _frame > 20000:
		_fail("deadline — stage1 never cleared")
		return
	_apply_climber_if_ready()

func _apply_climber_if_ready() -> void:
	if _scene_flow == null or _scene_flow._current_stage_id != 1:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_been_carrying or a.has_trait(&"climber"):
			continue
		if a.global_position.y > 490.0 and a.global_position.y < 560.0 and a.global_position.x >= 336.0 and a.global_position.x < 528.0:
			var climber: ClimberSkill = ClimberSkill.new()
			if climber.can_apply(a):
				climber.apply(a)

func _on_cleared(result: Dictionary) -> void:
	if _handled:
		return
	if int(result.get("stage_id", 0)) != 1:
		return
	_handled = true
	var fails: Array[String] = []

	# 1) SaveData(autoload)가 stage_cleared를 받아 record_clear 했는지 (in-memory).
	var entry_mem: Dictionary = SaveData.get_stage_entry(1)
	if not entry_mem.get("cleared", false):
		fails.append("in-memory: stage1 cleared=false after stage_cleared (record_clear 미동작) entry=%s" % str(entry_mem))
	if not SaveData.is_unlocked(2):
		fails.append("in-memory: stage2 미해금")

	# 2) 디스크 파일 존재 확인.
	if not FileAccess.file_exists(TEMP_PATH):
		fails.append("디스크 저장 파일 없음: %s" % ProjectSettings.globalize_path(TEMP_PATH))

	# 3) "재실행" 모사 — in-memory 폐기 후 디스크에서 재로드.
	SaveData._test_reset(TEMP_PATH)
	var entry_disk: Dictionary = SaveData.get_stage_entry(1)
	if not entry_disk.get("cleared", false):
		fails.append("RESTART: stage1 cleared=false (디스크 영속 실패) entry=%s" % str(entry_disk))
	if not SaveData.is_unlocked(2):
		fails.append("RESTART: stage2 미해금 (클리어 정보 미적용)")

	print("[StageClearPersistE2ETest] result=%s" % str(result))
	print("[StageClearPersistE2ETest] disk entry=%s saved=%d/%d" % [
		str(entry_disk), int(result.get("saved", -1)), int(result.get("original_hp", -1))])

	SaveData._test_cleanup_files(TEMP_PATH)

	if fails.is_empty():
		print("[StageClearPersistE2ETest] PASS")
		get_tree().quit(0)
	else:
		print("[StageClearPersistE2ETest] FAIL")
		for f in fails:
			print("  ", f)
		get_tree().quit(1)

func _fail(msg: String) -> void:
	if _handled:
		return
	_handled = true
	print("[StageClearPersistE2ETest] FAIL ", msg)
	SaveData._test_cleanup_files(TEMP_PATH)
	get_tree().quit(1)
