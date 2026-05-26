extends Node

# Stage 진입 시 HUD CounterCandyHp가 stage_data.candy_hp 값을 즉시 표시하는지 검증.
# 회귀 방지: candy_piece_picked는 첫 ant 픽업 시점부터만 발화하므로, 본 push 없으면
# stage 시작 직후 카운터가 0으로 노출되어 사탕 HP를 확인할 수 없음.

var _failed: bool = false

func _ready() -> void:
	await get_tree().process_frame  # SceneFlow._ready / _boot → TITLE 진입

	var main: Node = $Main
	var scene_flow: Node = main.get_node("SceneFlow")
	scene_flow.load_stage(1)
	await get_tree().process_frame  # remove_child + queue_free
	await get_tree().process_frame  # Stage01 instantiation + StageRunner._ready (set_candy_hp 호출 시점)

	var current_stage_root: Node = main.get_node("CurrentStageRoot")
	var stage: Node = current_stage_root.get_child(0) if current_stage_root.get_child_count() > 0 else null
	if stage == null:
		_fail("no stage instance under CurrentStageRoot")
		return

	var runner: StageRunner = stage as StageRunner
	if runner == null:
		_fail("stage root not a StageRunner (type=%s)" % stage.get_class())
		return

	var hud: Node = runner.get_node_or_null(runner.hud_path)
	if hud == null:
		_fail("HUD missing under stage")
		return

	var counter: Node = hud.get_node_or_null("Root/TopLeft/CounterCandyHp")
	if counter == null:
		_fail("CounterCandyHp missing")
		return

	# Counter atom renders value via BigNumber.text — string compare.
	var big: Label = counter.get_node_or_null("MainPanel/VBox/BigNumber") as Label
	if big == null:
		_fail("BigNumber Label missing under Counter")
		return
	var expected: String = str(runner.stage_data.candy_hp)
	if big.text != expected:
		_fail("CounterCandyHp.BigNumber expected=%s got=%s" % [expected, big.text])
		return

	print("[HudInitialCandyHpTest] PASS candy_hp=", big.text)
	get_tree().quit(0)

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[HudInitialCandyHpTest] FAIL ", msg)
	get_tree().quit(1)
