extends Node

# map-editor 트랙(2026-06-04) — SceneFlow 스테이지 스캔 + 캠페인 게이트 회귀 가드.
# 설계: STAGE_SCENES = 파일 존재 스캔(load_stage용) / PUBLISHED_STAGE_IDS = 씬 ∩ menu_layout.available(캠페인 SoT).
# (1) 현재 파일시스템(Stage01~09) + menu_layout(1~9 available, 10 coming-soon) 반영.
# (2) codex adversarial-review HIGH 회귀: Stage10.tscn 파일이 생겨도 menu_layout slot10=unavailable이면
#     캠페인에 노출되지 않고(PUBLISHED 제외) LAST_STAGE_ID는 9로 유지 — Next가 Stage10을 로드하지 않는다.

func _ready() -> void:
	var ok := true
	SceneFlow.ensure_stage_scan()

	# (1) 기존 스테이지 반영
	ok = _check(ok, SceneFlow.STAGE_SCENES.has(1), "scenes has 1")
	ok = _check(ok, SceneFlow.STAGE_SCENES.has(9), "scenes has 9")
	ok = _check(ok, SceneFlow.STAGE_SCENES.get(1, "") == "res://scenes/stages/Stage01.tscn", "stage1 path")
	ok = _check(ok, SceneFlow.PUBLISHED_STAGE_IDS.has(9), "published has 9")
	ok = _check(ok, SceneFlow.LAST_STAGE_ID == 9, "LAST_STAGE_ID == 9 (max published)")

	# (2) HIGH 회귀: 미공개 Stage10.tscn 파일 추가 → 씬 스캔엔 잡히나 캠페인엔 노출 안 됨.
	var probe_id := 10
	var p := "res://scenes/stages/Stage%02d.tscn" % probe_id
	if not ResourceLoader.exists(p):
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("[gd_scene format=3]\n\n[node name=\"StageScanProbe\" type=\"Node2D\"]\n")
		f.close()
		SceneFlow._stage_scan_done = false
		SceneFlow.ensure_stage_scan()
		var scene_seen := SceneFlow.STAGE_SCENES.has(probe_id)        # 로드 가능(파일 존재)
		var not_published := not SceneFlow.PUBLISHED_STAGE_IDS.has(probe_id)  # 캠페인 미노출(slot10 unavailable)
		var endpoint_held := SceneFlow.LAST_STAGE_ID == 9             # 엔드포인트 이동 안 함
		# 정리 먼저(어서션 실패해도 임시 파일 누수 방지) → 스캔 원복
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		SceneFlow._stage_scan_done = false
		SceneFlow.ensure_stage_scan()
		ok = _check(ok, scene_seen, "scene scan discovers Stage10 file")
		ok = _check(ok, not_published, "Stage10 NOT in campaign (menu_layout slot10 unavailable)")
		ok = _check(ok, endpoint_held, "LAST_STAGE_ID stays 9 (endpoint not moved by file presence)")
		ok = _check(ok, SceneFlow.LAST_STAGE_ID == 9 and not SceneFlow.STAGE_SCENES.has(probe_id), "cleanup restored scan")
	else:
		print("[SceneFlowStageScanTest] NOTE: Stage10 이미 존재 — HIGH 회귀 케이스 skip")

	if ok:
		print("[SceneFlowStageScanTest] PASS")
		get_tree().quit(0)
	else:
		print("[SceneFlowStageScanTest] FAIL")
		get_tree().quit(1)

func _check(prev: bool, cond: bool, label: String) -> bool:
	print(("  OK   " if cond else "  FAIL ") + label)
	return prev and cond
