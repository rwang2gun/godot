extends Node

# 회귀 — 모든 발행 스테이지는 로드 후 스킬 가이드 컨트롤러 2종을 World에 가져야 한다.
#   AffordanceGlowController : SIGN(표지판)/DEVICE 배치 셀 글로우 + 무장/정착 스킬 개미 글로우
#   PlacementPreview         : DEVICE 장치 설치 ghost
# 허용 경로 2가지(둘 다 OK): ① 씬에 명시 배선(Stage01~09) ② StageRunner 런타임 보강(Stage10+).
# 배경: Stage10이 AffordanceGlowController 누락으로 표지판(digger/cutter) 배치 가이드가 안 떴고,
#   .tscn 편집은 열린 Godot 에디터가 되돌려 StageRunner 런타임 보강으로 해결(2026-06-08).
# 추가로 stage10에서 SIGN 글로우가 실제 valid 셀을 산출하는지(end-to-end)도 확인.

var _ids: Array = []
var _idx: int = 0
var _stage: Node = null
var _phase: int = 0
var _wait: int = 0
var _failures: Array = []

func _ready() -> void:
	SceneFlow.ensure_stage_scan()
	for sid in SceneFlow.PUBLISHED_STAGE_IDS:
		_ids.append(sid)
	_ids.sort()
	print("[StageGuideControllerPresenceTest] published stages: %s" % str(_ids))

func _physics_process(_d: float) -> void:
	match _phase:
		0:
			if _idx >= _ids.size():
				_finish()
				return
			var path: String = SceneFlow.STAGE_SCENES.get(_ids[_idx], "")
			if path == "" or not ResourceLoader.exists(path):
				_failures.append("stage %d: scene path 미해결" % _ids[_idx])
				_idx += 1
				return
			_stage = load(path).instantiate()
			add_child(_stage)
			_wait = 0
			_phase = 1
		1:
			# StageRunner._ready + _ensure_guide_controllers 완료 대기.
			_wait += 1
			if _wait < 3:
				return
			_check_stage(_ids[_idx])
			_stage.queue_free()
			_stage = null
			_idx += 1
			_phase = 0

func _check_stage(sid: int) -> void:
	var world: Node = _find(_stage, "World")
	if world == null:
		_failures.append("stage %d: World 노드 없음" % sid)
		return
	var glow: AffordanceGlowController = null
	var preview: PlacementPreview = null
	for c in world.get_children():
		if c is AffordanceGlowController:
			glow = c
		if c is PlacementPreview:
			preview = c
	if glow == null:
		_failures.append("stage %d: AffordanceGlowController 없음(씬+런타임 모두)" % sid)
	if preview == null:
		_failures.append("stage %d: PlacementPreview 없음(씬+런타임 모두)" % sid)
	# stage10: SIGN 글로우 end-to-end — corridor에서 digger/cutter가 valid 셀을 내는지.
	if sid == 10 and glow != null:
		for skill in ["digger", "cutter"]:
			var res: Dictionary = glow.surface_install_result(skill, Vector2(21 * 48 + 24, 6 * 48 + 24))
			if not res.get("valid", false):
				_failures.append("stage 10: %s SIGN 글로우 invalid (reason=%s)" % [skill, str(res.get("reason"))])
	print("  stage %d: glow=%s preview=%s" % [sid, str(glow != null), str(preview != null)])

func _finish() -> void:
	if _failures.is_empty():
		print("[StageGuideControllerPresenceTest] PASS (%d stages)" % _ids.size())
		get_tree().quit(0)
	else:
		push_error("[StageGuideControllerPresenceTest] FAIL\n" + "\n".join(_failures))
		print("[StageGuideControllerPresenceTest] FAIL\n" + "\n".join(_failures))
		get_tree().quit(1)

func _find(root: Node, nm: String) -> Node:
	if root == null:
		return null
	if root.name == nm:
		return root
	for c in root.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null
