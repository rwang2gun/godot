extends RefCounted
# (class_name 미사용 — 소비자는 preload로 참조: 전역 클래스 캐시는 에디터 스캔 의존이라
#  헤드리스 신규 파일에서 미등록일 수 있고, preload-상수와의 shadow 경고도 피한다.)

# auto-solver §R4a — 타일/해저드 self-describing 메타 (D7 확장, 2026-07-10).
#
# 솔버가 타일 의미(water≠sticky, plant≠earth≠cookie)를 하드코딩 없이 읽도록, 스킬 SOLVER_META와
# 동일한 계약으로 엔진이 선언한다. SolverMetaDump가 stdout으로 노출, Python(tools/solver/rl)이 소비.
#
# canonical kind alias (§R4 plan R1-H3): 어휘 3계가 서로 다르다 —
#   ① layout kind = StageLayoutData.tile_map 값("solid"/"plant"/"cookie"/"sand_mound"/"background"/
#      "slope_right"/"slope_left") — 레이아웃 .tres의 SoT.
#   ② engine cell kind = Terrain._cell_kind("earth"/"plant"/"cookie") — StageLayoutBuilder.build()의
#      kind 라우팅이 SoT(solid·slope·sand_mound→"earth", plant→"plant", cookie→"cookie",
#      background→충돌체 없음(비등록)).
#   ③ 스킬 파괴 판정 = Terrain.destroy_tile_at(allowed_kinds): basher/digger=["earth"]
#      (WorkerState), cutter=["plant"] — engine kind 기준.
# 이 테이블은 ①→②③으로의 솔버-가시 사본이며, TileMetadataDriftTest가 (a) 레이아웃 전수 kind ⊆
# TILE_META (b) breakable_by ⊆ SkillRegistry (c) engine_kind ⊆ 엔진 어휘 를 강제한다.
# 값 변경 시 여기가 아니라 SoT(StageLayoutBuilder/Terrain/WorkerState/Ant)를 먼저 보고 정합시킬 것.
#
# 필드 계약(전 kind 필수 — 드리프트 테스트 ③):
#   engine_kind:  Terrain._cell_kind 등록값. ""(빈 문자열) = 충돌체 미등록(background).
#   occupied:     충돌/점유 여부(StageLayoutBuilder._add_cell이 StaticBody2D를 만드는가).
#   traversal:    "solid"(막힘) | "climbable"(사다리 — is_ladder_cell) | "none"(비충돌).
#   breakable_by: 이 셀을 파괴할 수 있는 스킬 id 배열(destroy_tile_at allowed_kinds 라우팅 기준).

const TILE_META := {
	"solid": {"engine_kind": "earth", "occupied": true, "traversal": "solid",
		"breakable_by": ["basher", "digger"]},
	"slope_right": {"engine_kind": "earth", "occupied": true, "traversal": "solid",
		"breakable_by": ["basher", "digger"]},
	"slope_left": {"engine_kind": "earth", "occupied": true, "traversal": "solid",
		"breakable_by": ["basher", "digger"]},
	"plant": {"engine_kind": "plant", "occupied": true, "traversal": "solid",
		"breakable_by": ["cutter"]},
	"cookie": {"engine_kind": "cookie", "occupied": true, "traversal": "solid",
		"breakable_by": []},  # 불괴(S6 "땅굴" 구조 셀) — destroy_tile_at 전 스킬 거부
	"sand_mound": {"engine_kind": "earth", "occupied": true, "traversal": "climbable",
		"breakable_by": ["basher", "digger"]},  # 정적 사다리 — 파괴 시 즉시 FallerState
	"background": {"engine_kind": "", "occupied": false, "traversal": "none",
		"breakable_by": []},  # 시각 전용(StageLayoutBuilder._add_visual_only_cell) — 충돌체·점유 없음
}

# hazard kind 계약(hazard_map 값 — StageLayoutData 주석의 "water"|"sticky"가 SoT):
#   lethal:     true = 접촉이 리타이어로 귀결(water: AdriftState 익사).
#   speed_mult: 겹침 중 이동 속도 배율(sticky = Ant.STICKY_SPEED_MULT 감속 존, 생존·통과 가능).
const HAZARD_META := {
	"water": {"lethal": true, "speed_mult": 1.0},
	"sticky": {"lethal": false, "speed_mult": Ant.STICKY_SPEED_MULT},
}

# 엔진 cell kind 어휘(Terrain._cell_kind에 등장 가능한 값 + 비등록 센티넬 "") — 드리프트 테스트 ②가
# TILE_META.engine_kind ⊆ 이 어휘를 강제. SoT = StageLayoutBuilder.build() kind 라우팅.
const VALID_ENGINE_KINDS := ["", "earth", "plant", "cookie"]
const VALID_TRAVERSALS := ["solid", "climbable", "none"]

static func all_tile_metas() -> Dictionary:
	return TILE_META.duplicate(true)

static func all_hazard_metas() -> Dictionary:
	return HAZARD_META.duplicate(true)
