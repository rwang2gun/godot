extends Node

# Campaign S9 음성 짝 ② — basher만 빼고 bridge+builder는 시전. 게이트2 흙 벽(cols15-16)을 못 뚫어
# 개미가 벽 앞 col14에서 flip(climber 無) → 통로가 안 생겨 단·candy에 도달 불가 → picks==0.
# (bridge는 게이트1을 넘게 해주지만, builder x-window(col17)는 벽에 막혀 영영 도달 못 해 미발동.)
# 이로써 basher가 3관문 중 독립적으로 필수임을 입증(클리어 짝 CampaignS9ClearTest와 대비).
# PASS: stage_failed && picks==0. FAIL: stage_cleared (basher 없이 클리어 = 게이트2 무력) / deadline.

const DEADLINE_FRAMES: int = 30000
const BRIDGE_X_MIN: float = 384.0
const BRIDGE_X_MAX: float = 432.0
const BUILDER_X_MIN: float = 816.0
const BUILDER_X_MAX: float = 864.0

const WALL_APPROACH_X: float = 672.0  # col14 — 호수(cols9-12)+중앙 지면을 건너 흙 벽 직전에 실제 도달한 증거.

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _bridge_applied: bool = false
var _builder_applied: bool = false
var _reached_wall: bool = false  # 어떤 개미가 다리로 호수를 건너 벽 앞(col14)까지 실제 도달했는가(게이트1 통과 증거).

func _ready() -> void:
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS9NoBasherTest] driver ready (bridge+builder only, no basher)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if not _bridge_applied:
		_apply_x_window_skill(BRIDGE_X_MIN, BRIDGE_X_MAX, true)
	if not _builder_applied:
		_apply_x_window_skill(BUILDER_X_MIN, BUILDER_X_MAX, false)
	_track_wall_approach()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d bridge=%s builder=%s (음성 테스트는 stage_failed로 종료돼야 함)" % [
			_picks, _bridge_applied, _builder_applied])

# 어떤 개미가 흙 벽 직전 col14(x>=672)에 실제 도달 = 호수를 다리로 건너 게이트1을 물리적으로 통과한 증거.
# (호수 cols9-12는 갭이라 다리 없이는 이 x에 닿을 수 없다 — apply() 호출만이 아닌 실제 통과를 보증.)
func _track_wall_approach() -> void:
	if _reached_wall:
		return
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a):
			continue
		if a.global_position.x >= WALL_APPROACH_X:
			_reached_wall = true
			return

func _apply_x_window_skill(x_min: float, x_max: float, is_bridge: bool) -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_candy:
			continue
		if a.global_position.x < x_min or a.global_position.x >= x_max:
			continue
		var skill: Skill = BridgeSkill.new() if is_bridge else BuilderSkill.new()
		if not skill.can_apply(a):
			continue
		skill.apply(a)
		if is_bridge:
			_bridge_applied = true
		else:
			_builder_applied = true
		return

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without basher — 흙 벽을 basher 없이 통과 = 게이트2 무력")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	# 개미가 다리로 호수를 건너 벽 앞(col14)까지 실제 도달(_reached_wall)했는데 게이트2(basher 부재)에서 막혀
	# picks==0이어야 basher의 독립 필수성이 증명된다. apply() 호출(_bridge_applied)만으론 부족 — bridge가
	# arm만 되고 개미가 게이트1 전에 죽어도 통과로 오인되므로, 실제 위치 도달을 단언한다(codex R2 MEDIUM).
	if _picks == 0 and _reached_wall:
		print("[CampaignS9NoBasherTest] PASS stage_failed reason=%s picks=0 reached_wall=true bridge=%s builder=%s (basher 필수성 입증) frame=%d" % [
			str(result.get("reason", "?")), _bridge_applied, _builder_applied, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS9NoBasherTest] FAIL stage_failed picks=%d reached_wall=%s bridge=%s (게이트1 미통과 or candy 도달?) frame=%d" % [
			_picks, _reached_wall, _bridge_applied, _frame])
		get_tree().quit(1)

func _fail(msg: String) -> void:
	print("[CampaignS9NoBasherTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
