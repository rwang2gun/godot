extends Node

# 설치형 오브젝트 허공 배치 방지 검증 (2026-06-05).
# 버그: 설치 경로가 "점유되지 않은 셀"이면 허공에도 배치했다(cutter 표지판/leaf_jump 점프대 등).
# 수정: 클릭 열을 아래로 훑어 지면 바로 위로 스냅, 바닥이 없으면 거부.
#
# 검증(leaf_jump 점프대 사용, leaf_jump dev 스테이지: 바닥 row22, 컬럼 0~30):
#  (1) 바닥 없는 열(col 40) 상공 클릭 → 거부(false), 인벤토리 미차감.
#  (2) 바닥 있는 열(col 10) 상공 높이(row 5) 클릭 → 설치 성공 + 표지판 cell이 지면 바로 위(10,21)로 스냅.
# PASS: (1)==false AND (2)==true AND 점프대 cell==(10,21).

const DEADLINE_FRAMES: int = 600

var _stage: Node = null
var _terrain: Terrain = null
var _toolbar: SkillToolbar = null
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	print("[SignGroundSnapTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	# 준비 판정: 정적 레이아웃 바닥은 _static_occupancy라 tile_count()(=_placed)에 안 잡힌다 →
	# 알려진 바닥 셀(10,22) 점유로 레이아웃 빌드 완료를 확인.
	var ready: bool = _terrain != null and _toolbar != null and _terrain.is_cell_occupied(Vector2i(10, 22))
	if not ready:
		if _frame > DEADLINE_FRAMES:
			_fail("refs/terrain not ready (terrain=%s toolbar=%s)" % [str(_terrain != null), str(_toolbar != null)])
		return
	_run_checks()

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../LeafJumpStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	if _toolbar == null and _stage != null:
		_toolbar = _stage.get_node_or_null("SkillToolbar") as SkillToolbar

func _run_checks() -> void:
	var cs: int = _terrain.cell_size

	# (1) 바닥 없는 열(col 40) 상공 → 거부.
	var over_pit := Vector2(40.0 * cs + cs / 2.0, 5.0 * cs)
	if _toolbar._place_leaf_jump_pad(over_pit):
		_fail("바닥 없는 열(col 40) 상공인데 설치됨 — 허공 배치 미차단")
		return

	# (2) 바닥 있는 열(col 10) 상공 높이(row 5) → 설치 + 지면(10,21)으로 스냅.
	var high_air := Vector2(10.0 * cs + cs / 2.0, 5.0 * cs)
	if not _toolbar._place_leaf_jump_pad(high_air):
		_fail("바닥 있는 열 상공 클릭이 거부됨 — 지면 스냅 실패(인벤토리/지형 확인)")
		return

	var pad: LeafJumpPad = _find_pad(_stage)
	if pad == null:
		_fail("설치 성공 보고됐으나 LeafJumpPad 노드 없음")
		return
	if pad.cell != Vector2i(10, 21):
		_fail("점프대 cell이 지면으로 스냅 안 됨: %s (기대 (10,21))" % str(pad.cell))
		return

	print("[SignGroundSnapTest] PASS — 허공(col40) 거부 + 상공 클릭 지면 스냅 cell=%s frame=%d" % [str(pad.cell), _frame])
	_done = true
	get_tree().quit(0)

func _find_pad(n: Node) -> LeafJumpPad:
	if n is LeafJumpPad:
		return n as LeafJumpPad
	for c in n.get_children():
		var pad: LeafJumpPad = _find_pad(c)
		if pad != null:
			return pad
	return null

func _fail(msg: String) -> void:
	print("[SignGroundSnapTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
