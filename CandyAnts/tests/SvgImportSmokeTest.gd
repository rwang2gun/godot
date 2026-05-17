extends Node

# Phase 9 complete 차단 조건 (phase 11에서 ui icons 2장 추가 → 15장).
# production SVG sanity + svg_color_map sanity_invariants 4종 + import Godot 4.6 실제 4종 키 검증.
# invariant[3] (handoff class 매핑 entry 존재)은 normalize_svg.py --scan-handoff-all 책임.
# (flags/filter는 Godot 4 .import key 부재, ProjectSettings default Linear 의존 — impl R1-H2 정정.)

const PRODUCTION_SVGS := [
	"res://assets/logo/wordmark.svg",
	"res://assets/logo/icon.svg",
	"res://assets/logo/mascot.svg",
	"res://assets/icons/skills/basher.svg",
	"res://assets/icons/skills/blocker.svg",
	"res://assets/icons/skills/bomber.svg",
	"res://assets/icons/skills/builder.svg",
	"res://assets/icons/skills/climber.svg",
	"res://assets/icons/skills/digger.svg",
	"res://assets/icons/skills/floater.svg",
	"res://assets/icons/skills/miner.svg",
	"res://assets/sprites/home.svg",
	"res://assets/illustrations/stage_bg.svg",
	# Phase 11: PauseBtn icon assets (토큰 hex #3A2A1C 1:1, normalize_svg.py 외 수동 작성).
	"res://assets/icons/ui/pause.svg",
	"res://assets/icons/ui/play.svg",
]

# UI_GUIDE §1.1·§1.2 토큰 oklch 문자열 (canonical handoff form).
const TOKEN_OKLCH_STRINGS := [
	"0.985 0.012 75", "0.965 0.020 70", "0.93 0.030 70", "0.88 0.040 65",
	"0.26 0.045 50", "0.40 0.060 50", "0.58 0.045 55",
	"0.90 0.08 35", "0.78 0.155 28", "0.62 0.165 30",
	"0.92 0.07 175", "0.82 0.13 175", "0.60 0.13 175",
	"0.86 0.10 10", "0.70 0.20 15", "0.55 0.20 15",
	"0.95 0.10 95", "0.88 0.16 95", "0.72 0.16 90",
	"0.88 0.07 300", "0.72 0.14 300", "0.55 0.14 300",
	"0.92 0.05 235", "0.88 0.07 140",
]

# UI_GUIDE §1.1·§1.2 토큰 hex (lowercase).
const TOKEN_HEXES := [
	"#fbf8f1", "#f5efe3", "#e9dfcb", "#d9c9ac",
	"#3a2a1c", "#5c4530", "#8c7660",
	"#fad9c4", "#f2a48f", "#d17a60",
	"#d4f0e5", "#9ed9c2", "#5ea88a",
	"#f7c9c4", "#e48579", "#b85546",
	"#fcefc2", "#f0d77b", "#c9a93c",
	"#dccee2", "#b49ac5", "#7e5a9a",
	"#ccdfea", "#b0dcb4",
]

func _ready() -> void:
	var failures: Array[String] = []
	var color_map: Dictionary = _load_color_map()
	if color_map.is_empty():
		_finish(["color_map load failed"])
		return

	var allowed_hex: Dictionary = _build_allowed_hex_set(color_map)
	var alpha_variants_rgba: Array = _alpha_variants_target_rgba(color_map)
	var alpha_hit: Dictionary = {}
	for r in alpha_variants_rgba:
		alpha_hit[r] = false

	for path in PRODUCTION_SVGS:
		# (1) load + size
		var tex: Texture2D = load(path) as Texture2D
		if tex == null or tex.get_size().x == 0:
			failures.append("[load] " + path); continue

		# (2) 비-blank ≥ 5%
		var img: Image = tex.get_image()
		if img == null:
			failures.append("[get_image] " + path); continue
		var non_blank: int = 0
		var total: int = img.get_width() * img.get_height()
		if total <= 0:
			failures.append("[zero-size] " + path); continue
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.01:
					non_blank += 1
		if float(non_blank) / float(total) < 0.05:
			failures.append("[blank] " + path + " ratio=" + str(float(non_blank)/float(total)))
			continue

		var text: String = FileAccess.get_file_as_string(path)

		# (3) invariant[2] — 잔여 0건
		if text.contains("oklch("):
			failures.append("[oklch] " + path)
		if text.contains("class=\""):
			failures.append("[class] " + path)
		if text.contains("<style"):
			failures.append("[style] " + path)

		# (4) invariant[1] — hex 부분집합
		for hex in _extract_hex_from_color_attrs(text):
			if not allowed_hex.has(hex.to_lower()):
				failures.append("[hex] " + path + " hex=" + hex)

		# (5) invariant[4] — alpha_variants 사용 누적
		for r in alpha_variants_rgba:
			if text.contains(r):
				alpha_hit[r] = true

		# (6) 임포트 설정 4종 (Godot 4.6 실제 키)
		_check_import_settings(path, failures)

	# (7) invariant[0] — oklch_extras 토큰 중복
	var extras: Dictionary = color_map.get("oklch_extras", {})
	for key in extras.keys():
		if (key as String).begins_with("_"):
			continue
		if TOKEN_OKLCH_STRINGS.has(key):
			failures.append("[sanity-0] oklch_extras has token oklch: " + key)

	# (8) invariant[4] — 미사용 alpha_variants 키
	for r in alpha_hit.keys():
		if not alpha_hit[r]:
			failures.append("[sanity-4] alpha_variants unused: " + r)

	_finish(failures)


func _finish(failures: Array) -> void:
	if failures.size() > 0:
		push_error("SvgImportSmokeTest FAIL — " + str(failures.size()) + ":\n" + "\n".join(failures))
		print("[SvgImportSmokeTest] FAIL — ", failures.size(), " issues")
		for f in failures:
			print("  ", f)
		get_tree().quit(1)
	else:
		print("[SvgImportSmokeTest] PASS — %d SVG verified, 4 sanity invariants checked, imports OK" % PRODUCTION_SVGS.size())
		print("  (invariant[3] handoff class mapping — normalize_svg.py --scan-handoff-all gate)")
		get_tree().quit(0)


func _load_color_map() -> Dictionary:
	var path := "res://scripts/tools/svg_color_map.json"
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _build_allowed_hex_set(color_map: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	# UI_GUIDE token hex
	for h in TOKEN_HEXES:
		out[h] = true
	# oklch_extras hex values
	for k in color_map.get("oklch_extras", {}).keys():
		var v = color_map["oklch_extras"][k]
		if v is String and (v as String).begins_with("#"):
			out[(v as String).to_lower()] = true
	# literal_color_map: both keys (origin) and values (target) end up in output
	var lmap: Dictionary = color_map.get("literal_color_map", {})
	for k in lmap.keys():
		var v = lmap[k]
		if v is String and (v as String).begins_with("#"):
			out[(v as String).to_lower()] = true
	# allowed_literals
	var al: Array = color_map.get("allowed_literals", {}).get("values", [])
	for v in al:
		if v is String and (v as String).begins_with("#"):
			out[(v as String).to_lower()] = true
	return out


func _alpha_variants_target_rgba(color_map: Dictionary) -> Array:
	var out: Array = []
	var av: Dictionary = color_map.get("alpha_variants", {})
	for k in av.keys():
		if (k as String).begins_with("_"):
			continue
		var v = av[k]
		if v is String:
			out.append(v)
	return out


func _extract_hex_from_color_attrs(text: String) -> Array[String]:
	# Scan for hex tokens anywhere in the text. SVG is small; brute-force regex.
	var out: Array[String] = []
	var rx := RegEx.new()
	rx.compile("#[0-9a-fA-F]{3,8}")
	for m in rx.search_all(text):
		out.append(m.get_string())
	return out


func _check_import_settings(path: String, failures: Array) -> void:
	# UI_GUIDE §2.5 — Godot 4.6 SVG importer 실제 키 이름 매핑:
	#   svg/scale=1.0              ↔ UI_GUIDE 'svg/scale=1.0'
	#   compress/mode=0            ↔ UI_GUIDE 'compress/mode=0' (lossless)
	#   process/fix_alpha_border=true ↔ UI_GUIDE 동일
	#   mipmaps/generate=true      ↔ UI_GUIDE 'flags/mipmaps=true' (Godot 3 키, 4.6은 mipmaps/generate)
	#   (UI_GUIDE 'flags/filter=true' — Godot 4.6은 .import에 없음. 텍스처 필터는 CanvasItem.texture_filter
	#    또는 ProjectSettings/rendering/textures/canvas_textures/default_texture_filter로 제어, 기본 Linear.
	#    본 phase는 default Linear 의존을 허용 — atom phase 10에서 atom 노드의 texture_filter override 가능.)
	var import_path: String = path + ".import"
	var cfg := ConfigFile.new()
	if cfg.load(import_path) != OK:
		failures.append("[import-missing] " + import_path)
		return
	var checks: Array = [
		["params", "svg/scale", 1.0],
		["params", "compress/mode", 0],
		["params", "process/fix_alpha_border", true],
		["params", "mipmaps/generate", true],
	]
	for c in checks:
		var section: String = c[0]
		var entry: String = c[1]
		var expected = c[2]
		var actual = cfg.get_value(section, entry, null)
		if actual == null:
			failures.append("[import-key-missing] " + path + " " + section + "/" + entry)
		elif actual != expected:
			failures.append("[import] " + path + " " + section + "/" + entry + " expected=" + str(expected) + " got=" + str(actual))
