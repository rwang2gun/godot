extends Node

# map-editor 트랙(2026-06-04) — SceneFlow.STAGE_SCENES 자동 스캔 회귀 가드.
# 구 하드코딩 dict → `res://scenes/stages/Stage%02d.tscn` 파일시스템 스캔으로 전환.
# (1) 현재 파일시스템(Stage01~09) 반영 + LAST_STAGE_ID = max id.
# (2) 새 스테이지 파일 추가 시 rescan이 자동 등록 (레벨 에디터 Create Stage 시나리오).

func _ready() -> void:
	var ok := true
	SceneFlow.ensure_stage_scan()

	# (1) 기존 스테이지 반영
	ok = _check(ok, SceneFlow.STAGE_SCENES.has(1), "has stage 1")
	ok = _check(ok, SceneFlow.STAGE_SCENES.has(9), "has stage 9")
	ok = _check(ok, SceneFlow.STAGE_SCENES.get(1, "") == "res://scenes/stages/Stage01.tscn", "stage1 path")
	ok = _check(ok, SceneFlow.LAST_STAGE_ID == _max_key(SceneFlow.STAGE_SCENES), "LAST_STAGE_ID == max key")
	var base_count: int = SceneFlow.STAGE_SCENES.size()

	# (2) 동적 추가 → rescan 자동 등록
	var probe_id := 10
	var p := "res://scenes/stages/Stage%02d.tscn" % probe_id
	var dyn_ok := true
	if not ResourceLoader.exists(p):
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("[gd_scene format=3]\n\n[node name=\"StageScanProbe\" type=\"Node2D\"]\n")
		f.close()
		SceneFlow._stage_scan_done = false
		SceneFlow.ensure_stage_scan()
		dyn_ok = ResourceLoader.exists(p) \
			and SceneFlow.STAGE_SCENES.has(probe_id) \
			and SceneFlow.LAST_STAGE_ID >= probe_id \
			and SceneFlow.STAGE_SCENES.size() == base_count + 1
		# 정리: 임시 파일 제거 후 스캔 원복 (다른 테스트/실행 오염 방지)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		SceneFlow._stage_scan_done = false
		SceneFlow.ensure_stage_scan()
		ok = _check(ok, dyn_ok, "rescan auto-registers new Stage10")
		ok = _check(ok, SceneFlow.STAGE_SCENES.size() == base_count, "rescan after cleanup restores count")
	else:
		print("[SceneFlowStageScanTest] NOTE: Stage10 already exists — dynamic add 케이스 skip")

	if ok:
		print("[SceneFlowStageScanTest] PASS")
		get_tree().quit(0)
	else:
		print("[SceneFlowStageScanTest] FAIL")
		get_tree().quit(1)

func _max_key(d: Dictionary) -> int:
	var m := 0
	for k: int in d.keys():
		m = maxi(m, k)
	return m

func _check(prev: bool, cond: bool, label: String) -> bool:
	print(("  OK   " if cond else "  FAIL ") + label)
	return prev and cond
