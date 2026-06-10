extends Node

# campaign-50 B1 가드 (plan H-4) — 신규 스테이지 11~14의 정체성(scene_id) 정합 검증.
# 트리오 copy/repoint 저작에서 생기는 silent 오참조(예: Stage12.tscn이 stage11.tres를 참조,
# stage12.tres의 id가 11로 잔존)를 발행 전에 차단한다.
#   1) data/stages/stageNN.tres 의 StageData.id == NN
#   2) scenes/stages/StageNN.tscn 루트(StageRunner)가 로드하는 stage_data.id == NN
#   3) 검사 대상 간 id 중복 0
# instantiate()만 하고 add_child하지 않으므로 _ready 부작용(스폰 등) 없음.

const TARGET_IDS: Array[int] = [11, 12, 13, 14]

var _failed: bool = false

func _ready() -> void:
	var seen: Dictionary = {}
	for nn in TARGET_IDS:
		_check_stage(nn, seen)
		if _failed:
			return
	print("[StageIdentityTest] PASS ids=%s" % str(TARGET_IDS))
	get_tree().quit(0)

func _check_stage(nn: int, seen: Dictionary) -> void:
	# 1) stageNN.tres id 정합
	var res_path: String = "res://data/stages/stage%d.tres" % nn
	var sd: StageData = load(res_path) as StageData
	if sd == null:
		return _fail("%s load 실패/StageData 아님" % res_path)
	if sd.id != nn:
		return _fail("%s id expected %d, got %d" % [res_path, nn, sd.id])
	# 2) StageNN.tscn → stage_data repoint 정합
	var scene_path: String = "res://scenes/stages/Stage%02d.tscn" % nn
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return _fail("%s load 실패" % scene_path)
	var inst: Node = packed.instantiate()
	var scene_sd: StageData = inst.get("stage_data") as StageData
	if scene_sd == null:
		inst.free()
		return _fail("%s 루트에 stage_data 없음" % scene_path)
	var scene_id: int = scene_sd.id
	inst.free()
	if scene_id != nn:
		return _fail("%s stage_data.id expected %d, got %d (tres repoint 오참조)" % [scene_path, nn, scene_id])
	# 3) 중복 0
	if seen.has(scene_id):
		return _fail("id %d 중복 (이미 검사한 스테이지와 충돌)" % scene_id)
	seen[scene_id] = true
	print("[StageIdentityTest] id %d OK (tres+scene)" % nn)

func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print("[StageIdentityTest] FAIL ", msg)
	get_tree().quit(1)
