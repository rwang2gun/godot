extends SceneTree
# 헤드리스: 레벨 에디터 dock의 "웹 드래프트 가져오기"(_apply_web_draft) 매핑 검증.
# 에디터 @tool dock을 런타임 인스턴스화해 드래프트 Dictionary → UI 상태 매핑과
# 스킬 저장 권위((A) 스냅샷 경로)를 단언한다.
# 실행: godot --headless -s res://tests/WebDraftImportTest.gd  (run_test.py 아닌 -s 스크립트)

func _initialize() -> void:
	var failures: Array[String] = []
	var dock_script: Script = load("res://addons/candyants_level_tool/level_tool_dock.gd")
	var dock: Node = dock_script.new()
	get_root().add_child(dock)  # _ready 동기 실행 → UI 구성

	var draft := {
		"format": "candyants-level-draft", "v": 1, "stageId": 7, "name": "드래프트테스트", "cellSize": 48,
		"homeCell": {"x": 2, "y": 9}, "candyCell": {"x": 20, "y": 9}, "cameraCell": {"x": 11, "y": 6},
		"settlementOn": false, "settlementCell": {"x": 30, "y": 27},
		"spawnDirection": 1, "spawnAlternate": false, "theme": "cookie_crust",
		"totalAnts": 8, "candyHp": 4, "timeLimit": 130.0, "releaseRate": 25,
		"skills": {"bridge": 3, "basher": 2, "climber": 0},
		"hazardMap": {"9,10": "water", "10,10": "water"},
		"tileMap": {"0,10": "solid", "1,10": "solid", "2,10": "solid", "1,9": "plant", "1,8": "sand_mound"},
	}
	dock._apply_web_draft(draft)

	_eq(failures, "stageId", dock._id_spin.value, 7)
	_eq(failures, "name", dock._name_edit.text, "드래프트테스트")
	_eq(failures, "totalAnts", dock._total_ants_spin.value, 8)
	_eq(failures, "candyHp", dock._candy_hp_spin.value, 4)
	_eq(failures, "timeLimit", dock._time_limit_spin.value, 130.0)
	_eq(failures, "releaseRate", dock._release_rate_spin.value, 25)
	_eq(failures, "cellSize", dock._cell_size_spin.value, 48)
	_eq(failures, "home.x", dock._home_cell_x_spin.value, 2)
	_eq(failures, "home.y", dock._home_cell_y_spin.value, 9)
	_eq(failures, "candy.x", dock._candy_cell_x_spin.value, 20)
	_eq(failures, "camera.x", dock._camera_cell_x_spin.value, 11)
	_eq(failures, "skill.bridge", dock._skill_spins["bridge"].value, 3)
	_eq(failures, "skill.basher", dock._skill_spins["basher"].value, 2)
	_eq(failures, "skill.climber", dock._skill_spins["climber"].value, 0)
	_eq(failures, "hazard 9,10", str(dock._hazard_map.get("9,10", "")), "water")
	_eq(failures, "hazard 10,10", str(dock._hazard_map.get("10,10", "")), "water")

	# tile_map 라운드트립 (드래프트 dict → 텍스트 → 파싱)
	var tm: Dictionary = dock._parse_tile_map(dock._platform_text.text)
	_eq(failures, "tile 0,10", str(tm.get("0,10", "")), "solid")
	_eq(failures, "tile 2,10", str(tm.get("2,10", "")), "solid")
	_eq(failures, "tile 1,9 plant", str(tm.get("1,9", "")), "plant")
	_eq(failures, "tile 1,8 sand_mound", str(tm.get("1,8", "")), "sand_mound")

	# 스킬 저장 권위: 같은 ID로 _build_stage_data → (A) 스냅샷 = 드래프트 스킬이 그대로 기록.
	var sd: Resource = dock._build_stage_data(7, "드래프트테스트", "", "res://data/stage_layouts/stage07_layout.tres", "res://data/stages/stage07.tres")
	if sd == null:
		failures.append("build_stage_data가 null 반환")
	else:
		var inv: Dictionary = sd.skill_inventory
		_eq(failures, "saved bridge", int(inv.get("bridge", -1)), 3)
		_eq(failures, "saved basher", int(inv.get("basher", -1)), 2)
		_eq(failures, "saved climber 없음", inv.has("climber"), false)

	if failures.is_empty():
		print("PASS WebDraftImportTest")
	else:
		print("FAIL WebDraftImportTest")
		for f in failures:
			print("  - ", f)
	quit(0 if failures.is_empty() else 1)

func _eq(failures: Array, label: String, got: Variant, want: Variant) -> void:
	if got != want:
		failures.append("%s: got=%s want=%s" % [label, str(got), str(want)])
