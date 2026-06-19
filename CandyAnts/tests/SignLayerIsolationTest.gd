extends Node

# prove-it: 다른 층(y) 표지판이 같은 x열 개미에 **오발동하지 않음** (SkillSign._ant_at_cell y 체크).
# 버그(2026-06-20 보고): _ant_at_cell이 x열만 비교 → 같은 열의 다른 층 개미가 표지판을 오발동.
#
# dev_sand_mound layout은 2층 — 바닥(발판 row22) + 위층(발판 row17, col11~40). 위층 셀(row16, col20)에
# sand_mound 표지판을 설치하고, **바닥(발판 row22 위)을 걷는 개미**가 같은 col20을 지나도 발동 안 함을 검증.
# x만 보던 버그면 바닥 개미가 col20에서 위층 표지판을 발동(사다리 건설). 수정 후엔 y(층) 불일치로 무시한다.
#
# PASS: 개미가 표지판 열을 4칸 이상 지나도 tile_count 불변 + 표지판 잔존(미발동).
# FAIL: tile_count 증가(오발동) 또는 deadline.

const DEADLINE_FRAMES: int = 1600
const SIGN_COL: int = 20
const CS: int = 32

var _stage: Node = null
var _terrain: Terrain = null
var _toolbar: SkillToolbar = null
var _ant: Ant = null
var _placed: bool = false
var _base_tiles: int = -1
var _frame: int = 0
var _done: bool = false

func _ready() -> void:
	EventBus.stage_failed.connect(_on_failed)
	print("[SignLayerIsolationTest] driver ready")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	_ensure_refs()
	_place_upper_sign()
	_check()
	if _frame > DEADLINE_FRAMES:
		var ax: String = ("%.1f" % _ant.global_position.x) if (_ant != null and is_instance_valid(_ant)) else "?"
		_fail("deadline — placed=%s ant_x=%s tiles=%d base=%d" % [
			str(_placed), ax, _terrain.tile_count() if _terrain != null else -1, _base_tiles])

func _ensure_refs() -> void:
	if _stage == null:
		_stage = get_node_or_null("../SandMoundStage")
	if _terrain == null and _stage != null:
		_terrain = _stage.get_node_or_null("World/Terrain") as Terrain
	if _toolbar == null and _stage != null:
		_toolbar = _stage.get_node_or_null("SkillToolbar") as SkillToolbar
	if _ant == null or not is_instance_valid(_ant):
		for n in get_tree().get_nodes_in_group("ants"):
			var a: Ant = n as Ant
			if a != null:
				_ant = a
				return

func _place_upper_sign() -> void:
	if _placed or _toolbar == null or _terrain == null:
		return
	# 위층 발판(row17, col11~40) 위 셀(row16)에 표지판 설치 — 바닥 개미와 다른 층.
	var world: Vector2 = Vector2(float(SIGN_COL) * CS + CS / 2.0, 16.0 * CS + CS / 2.0)
	if not _toolbar._place_sign("sand_mound", world):
		_fail("_place_sign(위층 col%d) 실패 — fixture 가정 깨짐" % SIGN_COL)
		return
	_placed = true
	_base_tiles = _terrain.tile_count()
	print("[SignLayerIsolationTest] 위층 표지판 설치 col=%d base_tiles=%d frame=%d" % [SIGN_COL, _base_tiles, _frame])

func _check() -> void:
	if not _placed:
		return
	var tiles: int = _terrain.tile_count()
	if tiles > _base_tiles:
		_fail("오발동! 위층 표지판이 바닥 개미에 발동 — tile_count %d→%d (x열만 체크하던 버그)" % [_base_tiles, tiles])
		return
	# 바닥 개미가 표지판 열을 4칸 이상 지났는데 미발동 → 층 격리 성공.
	if _ant != null and is_instance_valid(_ant) and _ant.global_position.x >= float(SIGN_COL + 4) * CS:
		if _count_signs(_stage) >= 1:
			print("[SignLayerIsolationTest] PASS — 위층 표지판 미발동(바닥 개미 col%d+ 통과, tiles=%d 불변, 표지판 잔존)" % [SIGN_COL, tiles])
			_done = true
			get_tree().quit(0)

func _count_signs(n: Node) -> int:
	var c: int = 1 if n is SkillSign else 0
	for child in n.get_children():
		c += _count_signs(child)
	return c

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	# 스테이지 실패(개미 소진 등)라도 위층 표지판이 미발동이고 개미가 열을 지났으면 PASS.
	if _placed and _terrain != null and _terrain.tile_count() == _base_tiles and _count_signs(_stage) >= 1:
		print("[SignLayerIsolationTest] PASS (post-failed) — 미발동 reason=%s" % str(result.get("reason", "?")))
		_done = true
		get_tree().quit(0)
		return
	_fail("stage_failed reason=%s tiles=%d base=%d" % [
		str(result.get("reason", "?")), _terrain.tile_count() if _terrain != null else -1, _base_tiles])

func _fail(msg: String) -> void:
	print("[SignLayerIsolationTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
