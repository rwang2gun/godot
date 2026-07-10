extends Node

# auto-solver §R4a — 타일-의미 자동 인지 drift 가드 (SkillMetadataDriftTest의 타일판, 2026-07-10).
# 솔버는 타일/해저드 의미를 TileSolverMeta(단일 솔버-가시 사본)에서 읽는다. 새 타일 kind가 메타 없이
# 레이아웃에 추가되면 관측이 조용히 뭉개지므로(§R4 배경) 이 테스트가 FAIL로 차단한다.
#
# 단언:
#   ① 레이아웃 전수 kind 커버리지: 모든 레이아웃 .tres(data/stage_layouts/ + dev_stages/*/)의
#      tile_map 값 ⊆ TILE_META, hazard_map 값 ⊆ HAZARD_META. (미지 kind = fail-closed.)
#   ② canonical alias 정합: TILE_META.engine_kind ⊆ VALID_ENGINE_KINDS(엔진 어휘) +
#      breakable_by의 스킬 id ⊆ SkillRegistry 등록 스킬 + 파괴-라우팅 상수 대조
#      (earth↔basher/digger, plant↔cutter — WorkerState/Terrain destroy_tile_at 계약).
#   ③ 메타 필드 완전성: 전 kind에 engine_kind/occupied/traversal/breakable_by 필수 +
#      traversal ∈ VALID_TRAVERSALS. hazard에 lethal/speed_mult 필수 + 타입 검사.
#   ④ 구조 불변 교차 검증: background만 occupied=false / sticky만 non-lethal 감속
#      (speed_mult = Ant.STICKY_SPEED_MULT 참조 일치 — 상수 drift 차단).

# preload 참조(class_name 전역 캐시는 에디터 스캔 의존이라 헤드리스 신규 파일에서 미등록일 수 있음).
const TileSolverMeta := preload("res://scripts/core/TileSolverMeta.gd")

const REQUIRED_TILE_FIELDS := ["engine_kind", "occupied", "traversal", "breakable_by"]
const REQUIRED_HAZARD_FIELDS := ["lethal", "speed_mult"]
# 파괴-라우팅 계약 SoT 사본: destroy_tile_at(allowed_kinds) 호출부(WorkerState=earth, Terrain cutter=plant).
const BREAK_ROUTING := {"earth": ["basher", "digger"], "plant": ["cutter"], "cookie": [], "": []}

func _ready() -> void:
	var failures: Array[String] = []

	var tile_meta: Dictionary = TileSolverMeta.all_tile_metas()
	var hazard_meta: Dictionary = TileSolverMeta.all_hazard_metas()

	# --- ① 레이아웃 전수 kind ⊆ 메타 ---
	var layout_paths: Array[String] = _collect_layout_paths()
	if layout_paths.is_empty():
		failures.append("① 레이아웃 .tres를 하나도 못 찾음(스캔 경로 회귀?)")
	for path: String in layout_paths:
		var res: Resource = load(path)
		if res == null or not ("tile_map" in res):
			continue  # StageLayoutData가 아닌 .tres(StageData 등)는 스킵
		for key in res.tile_map:
			var kind: String = str(res.tile_map[key])
			if not tile_meta.has(kind):
				failures.append("① %s tile kind '%s' 미등록(TileSolverMeta.TILE_META에 추가 필요)" % [path, kind])
		if "hazard_map" in res:
			for key in res.hazard_map:
				var hkind: String = str(res.hazard_map[key])
				if not hazard_meta.has(hkind):
					failures.append("① %s hazard kind '%s' 미등록(HAZARD_META에 추가 필요)" % [path, hkind])

	# --- ②③ alias 정합 + 필드 완전성 ---
	var registered_skills: Dictionary = {}
	for id: String in SkillRegistry.skill_ids():
		registered_skills[id] = true
	for kind: String in tile_meta:
		var meta: Dictionary = tile_meta[kind]
		for field: String in REQUIRED_TILE_FIELDS:
			if not meta.has(field):
				failures.append("③ tile '%s' 필드 '%s' 누락" % [kind, field])
		var engine_kind: String = str(meta.get("engine_kind", "?"))
		if not TileSolverMeta.VALID_ENGINE_KINDS.has(engine_kind):
			failures.append("② tile '%s' engine_kind %r ∉ 엔진 어휘 %s" % [kind, engine_kind, str(TileSolverMeta.VALID_ENGINE_KINDS)])
		if not TileSolverMeta.VALID_TRAVERSALS.has(str(meta.get("traversal", "?"))):
			failures.append("③ tile '%s' traversal %r ∉ %s" % [kind, str(meta.get("traversal")), str(TileSolverMeta.VALID_TRAVERSALS)])
		var breakable: Array = meta.get("breakable_by", [])
		for sid in breakable:
			if not registered_skills.has(str(sid)):
				failures.append("② tile '%s' breakable_by '%s' ∉ SkillRegistry" % [kind, str(sid)])
		# 파괴-라우팅 상수 대조 — engine_kind가 결정하는 파괴자 집합과 일치해야 함(순서 무관).
		if BREAK_ROUTING.has(engine_kind):
			var expected: Array = BREAK_ROUTING[engine_kind]
			var got: Array = breakable.duplicate()
			got.sort()
			var exp_sorted: Array = expected.duplicate()
			exp_sorted.sort()
			if got != exp_sorted:
				failures.append("② tile '%s'(engine %s) breakable_by %s != 파괴-라우팅 계약 %s" % [kind, engine_kind, str(got), str(exp_sorted)])
	for hkind: String in hazard_meta:
		var hmeta: Dictionary = hazard_meta[hkind]
		for field: String in REQUIRED_HAZARD_FIELDS:
			if not hmeta.has(field):
				failures.append("③ hazard '%s' 필드 '%s' 누락" % [hkind, field])
		if hmeta.has("lethal") and typeof(hmeta["lethal"]) != TYPE_BOOL:
			failures.append("③ hazard '%s' lethal 타입 오류(bool 아님)" % hkind)

	# --- ④ 구조 불변 교차 검증 ---
	for kind: String in tile_meta:
		var occupied: bool = bool(tile_meta[kind].get("occupied", true))
		if kind == "background" and occupied:
			failures.append("④ background는 비충돌(occupied=false)이어야 함(StageLayoutBuilder._add_visual_only_cell)")
		if kind != "background" and not occupied:
			failures.append("④ tile '%s' occupied=false — 충돌 셀인데 비점유 선언(builder는 background만 비충돌)" % kind)
	if hazard_meta.has("sticky"):
		var sticky: Dictionary = hazard_meta["sticky"]
		if bool(sticky.get("lethal", true)):
			failures.append("④ sticky는 non-lethal 감속 존(Ant.gd 2026-06-07 재설계)")
		if not is_equal_approx(float(sticky.get("speed_mult", -1.0)), Ant.STICKY_SPEED_MULT):
			failures.append("④ sticky speed_mult(%s) != Ant.STICKY_SPEED_MULT(%s) — 상수 drift" % [str(sticky.get("speed_mult")), str(Ant.STICKY_SPEED_MULT)])
	if hazard_meta.has("water") and not bool(hazard_meta["water"].get("lethal", false)):
		failures.append("④ water는 lethal이어야 함(AdriftState 익사)")

	# --- 결과 ---
	if failures.is_empty():
		print("[TileMetadataDriftTest] PASS — %d layouts scanned, %d tile kinds, %d hazard kinds, alias/routing in sync" % [
			layout_paths.size(), tile_meta.size(), hazard_meta.size()])
		get_tree().quit(0)
	else:
		push_error("TileMetadataDriftTest FAIL: " + str(failures))
		print("[TileMetadataDriftTest] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)

# 레이아웃 .tres 전수 수집: data/stage_layouts/ 직속 + dev_stages/<slug>/ 하위(dev fixture 규약).
func _collect_layout_paths() -> Array[String]:
	var paths: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/stage_layouts")
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while fname != "":
			if fname.ends_with(".tres"):
				paths.append("res://data/stage_layouts/" + fname)
			fname = dir.get_next()
		dir.list_dir_end()
	var dev: DirAccess = DirAccess.open("res://dev_stages")
	if dev != null:
		dev.list_dir_begin()
		var sub: String = dev.get_next()
		while sub != "":
			if dev.current_is_dir() and not sub.begins_with("."):
				var sdir: DirAccess = DirAccess.open("res://dev_stages/" + sub)
				if sdir != null:
					sdir.list_dir_begin()
					var f2: String = sdir.get_next()
					while f2 != "":
						if f2.ends_with(".tres"):
							paths.append("res://dev_stages/%s/%s" % [sub, f2])
						f2 = sdir.get_next()
					sdir.list_dir_end()
			sub = dev.get_next()
		dev.list_dir_end()
	return paths
