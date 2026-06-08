extends Node

# map-editor 트랙(2026-06-04) — SceneFlow 스테이지 스캔 + 캠페인 게이트 회귀 가드.
# 설계: STAGE_SCENES = 파일 존재 스캔(load_stage용) / PUBLISHED_STAGE_IDS = 씬 ∩ menu_layout.available(캠페인 SoT).
# (1) 현재 파일시스템(Stage01~10) + menu_layout(1~10 모두 available) 반영. Stage10 정식 발행(2026-06-08).
# (2) codex adversarial-review HIGH 회귀: menu_layout에 슬롯이 없는 StageNN.tscn 파일이 생겨도
#     씬 스캔엔 잡히나 캠페인엔 노출 안 되고(PUBLISHED 제외) LAST_STAGE_ID(엔드포인트)는 이동하지 않는다.
#     Stage10이 발행됐으므로 미발행 프로브를 slot 없는 stage 11로 이동.

func _ready() -> void:
	var ok := true
	SceneFlow.ensure_stage_scan()

	# (1) 기존 스테이지 반영
	ok = _check(ok, SceneFlow.STAGE_SCENES.has(1), "scenes has 1")
	ok = _check(ok, SceneFlow.STAGE_SCENES.has(10), "scenes has 10")
	ok = _check(ok, SceneFlow.STAGE_SCENES.get(1, "") == "res://scenes/stages/Stage01.tscn", "stage1 path")
	ok = _check(ok, SceneFlow.PUBLISHED_STAGE_IDS.has(10), "published has 10 (slot10 available)")
	ok = _check(ok, SceneFlow.LAST_STAGE_ID == 10, "LAST_STAGE_ID == 10 (max published)")

	# (2) HIGH 회귀: menu_layout에 슬롯 없는 Stage11.tscn 파일 추가 → 씬 스캔엔 잡히나 캠페인엔 노출 안 됨.
	var probe_id := 11
	var p := "res://scenes/stages/Stage%02d.tscn" % probe_id
	if not ResourceLoader.exists(p):
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string("[gd_scene format=3]\n\n[node name=\"StageScanProbe\" type=\"Node2D\"]\n")
		f.close()
		SceneFlow._stage_scan_done = false
		SceneFlow.ensure_stage_scan()
		var scene_seen := SceneFlow.STAGE_SCENES.has(probe_id)        # 로드 가능(파일 존재)
		var not_published := not SceneFlow.PUBLISHED_STAGE_IDS.has(probe_id)  # 캠페인 미노출(slot11 없음)
		var endpoint_held := SceneFlow.LAST_STAGE_ID == 10            # 엔드포인트 이동 안 함
		# 정리 먼저(어서션 실패해도 임시 파일 누수 방지) → 스캔 원복
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		SceneFlow._stage_scan_done = false
		SceneFlow.ensure_stage_scan()
		ok = _check(ok, scene_seen, "scene scan discovers Stage11 file")
		ok = _check(ok, not_published, "Stage11 NOT in campaign (no menu_layout slot11)")
		ok = _check(ok, endpoint_held, "LAST_STAGE_ID stays 10 (endpoint not moved by file presence)")
		ok = _check(ok, SceneFlow.LAST_STAGE_ID == 10 and not SceneFlow.STAGE_SCENES.has(probe_id), "cleanup restored scan")
	else:
		print("[SceneFlowStageScanTest] NOTE: Stage11 이미 존재 — HIGH 회귀 케이스 skip")

	# (3) 가이드 컨트롤러 가드는 런타임 검증으로 이관 — StageGuideControllerPresenceTest.
	#     (씬 파일에 명시 배선[stage01~09] 또는 StageRunner 런타임 보강[stage10+] 둘 다 허용하므로
	#      PackedScene 파일 스캔은 더 이상 옳은 레이어가 아니다.)

	if ok:
		print("[SceneFlowStageScanTest] PASS")
		get_tree().quit(0)
	else:
		print("[SceneFlowStageScanTest] FAIL")
		get_tree().quit(1)

func _check(prev: bool, cond: bool, label: String) -> bool:
	print(("  OK   " if cond else "  FAIL ") + label)
	return prev and cond
