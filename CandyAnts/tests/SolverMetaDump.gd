extends Node

# auto-solver Phase 2 — D7 능력/메타 덤프 브리지 (헤드리스 씬).
#
# 솔버(tools/solver/solve.py, Python)가 게임 지식을 하드코딩하지 않도록(D7), 스킬 self-describing
# 메타(SkillRegistry.all_solver_metas())와 전역 능력(capabilities.tres)을 stdout JSON 한 줄로 노출한다.
# solve.py가 1회 호출·캐시해 행동공간 enumeration을 이 메타로 구동한다(스킬별 하드코딩 0).
#
# 솔버는 SkillRegistry라는 단일 권위 뷰에서 generic 열거하므로, 신규 스킬이 등록+메타를 갖추면
# 이 덤프에 자동 반영된다(SkillMetadataDriftTest가 완전성을 강제). 씬 기반인 이유: SkillRegistry는
# autoload라 --script 하니스에선 미동작([[headless-script-harness-limits]]).
#
# 출력: stdout `SOLVER_CAPS {json}` — {skills:{id:meta}, capabilities:{...}}.
# quit code: 0=성공, 2=에러.

const CAPABILITIES_PATH := "res://data/solver/capabilities.tres"
# §R4a — preload 참조(class_name 전역 캐시는 에디터 스캔 의존, 헤드리스 안전).
const TileSolverMeta := preload("res://scripts/core/TileSolverMeta.gd")

func _ready() -> void:
	var metas: Dictionary = SkillRegistry.all_solver_metas()
	var caps: Resource = load(CAPABILITIES_PATH)
	if caps == null:
		print("SOLVER_CAPS %s" % JSON.stringify({"error": "capabilities load failed: %s" % CAPABILITIES_PATH}))
		get_tree().quit(2)
		return
	var caps_dict: Dictionary = {
		"has_pause": caps.has_pause,
		"has_slow_motion": caps.has_slow_motion,
		"input_methods": caps.input_methods,
		"t_human_comfortable_s": caps.t_human_comfortable_s,
		"t_human_hard_s": caps.t_human_hard_s,
		"t_human_machine_only_s": caps.t_human_machine_only_s,
	}
	# §R4a — 타일/해저드 self-describing 메타 동봉(가산 키 — 기존 소비자는 skills/capabilities만 읽음).
	# TileMetadataDriftTest가 완전성·alias 정합을 강제하므로 여기서는 그대로 노출만 한다.
	var out: Dictionary = {
		"skills": metas,
		"capabilities": caps_dict,
		"tiles": TileSolverMeta.all_tile_metas(),
		"hazards": TileSolverMeta.all_hazard_metas(),
	}
	print("SOLVER_CAPS %s" % JSON.stringify(out))
	get_tree().quit(0)
