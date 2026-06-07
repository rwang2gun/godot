class_name SignPlacement
extends RefCounted

# 설치형(①표지판) · 장치(④) 스킬의 **공유 배치 검증 API** (STAGE_GUIDE_PLAN §0.8.2, codex R1 MEDIUM).
# 기존 SkillToolbar._ground_cell_for_sign(점유 거부 + 아래 64칸 스냅) + _leaf_jump_pad_exists(중복 거부)
# 로직을 추출해 단일 출처화. 글로우("어디가 클릭 성공 셀인가")와 실제 배치가 같은 규칙을 쓰도록 보장.
# ⚠ 트리거 규칙(SkillSign._ant_at_cell = "걷는 개미가 나중에 발동")과 다름 — 여긴 "지금 클릭 성공" 셀.

const LeafJumpPadScript := preload("res://scripts/world/LeafJumpPad.gd")
const SNAP_MAX_CELLS: int = 64

# world_or_cell: world 좌표(Vector2) 또는 셀(Vector2i) 둘 다 허용.
# sign_parent: leaf_jump(DEVICE) 중복 pad 검사용 부모 노드(없으면 중복 검사 생략).
# 반환: { cell: Vector2i, valid: bool, reason: String }  reason ∈ {ok,no_terrain,no_ground,pad_exists}
static func resolve_surface_install_cell(terrain: Terrain, skill_id: String, world_or_cell, sign_parent: Node = null) -> Dictionary:
	if terrain == null:
		return {"cell": Vector2i.MAX, "valid": false, "reason": "no_terrain"}
	var cs: int = terrain.cell_size
	var clicked: Vector2i
	if world_or_cell is Vector2i:
		clicked = world_or_cell
	else:
		var w: Vector2 = world_or_cell
		clicked = Vector2i(int(floor(w.x / cs)), int(floor(w.y / cs)))
	var cell: Vector2i = _ground_cell(terrain, clicked)
	if cell == Vector2i.MAX:
		return {"cell": Vector2i.MAX, "valid": false, "reason": "no_ground"}
	# DEVICE(leaf_jump) — 같은 셀에 이미 점프대가 있으면 중복 거부.
	if skill_id == "leaf_jump" and sign_parent != null and _leaf_jump_pad_exists(sign_parent, cell):
		return {"cell": cell, "valid": false, "reason": "pad_exists"}
	return {"cell": cell, "valid": true, "reason": "ok"}

# 클릭 셀을 같은 열의 지면 위 빈 셀로 스냅 — 아래로 훑어 첫 바닥 타일 바로 위를 반환.
# 클릭 셀이 점유(지형 내부)거나 아래 SNAP_MAX_CELLS 칸 내 바닥이 없으면 Vector2i.MAX(=실패).
static func _ground_cell(terrain: Terrain, cell: Vector2i) -> Vector2i:
	if terrain.is_cell_occupied(cell):
		return Vector2i.MAX
	for dy: int in range(1, SNAP_MAX_CELLS + 1):
		if terrain.is_cell_occupied(cell + Vector2i(0, dy)):
			return cell + Vector2i(0, dy - 1)
	return Vector2i.MAX

static func _leaf_jump_pad_exists(parent: Node, cell: Vector2i) -> bool:
	for child in parent.get_children():
		var pad: LeafJumpPad = child as LeafJumpPad
		if pad != null and pad.cell == cell:
			return true
	return false
