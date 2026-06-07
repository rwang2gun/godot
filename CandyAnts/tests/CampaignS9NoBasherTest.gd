extends Node

# Campaign S9 음성 짝 ① — basher만 빼고 bridge는 시전(sand_mound/blocker도 미시전). 게이트2 좌 기둥
# (cols14-15 rows6-9 solid)을 못 뚫어 개미가 기둥 앞 col13에서 flip(climber 無) → 중앙 빈 방·지붕에
# 도달 불가 → candy(지붕 위) 영영 회수 못 함 → picks==0.
# (bridge는 게이트1 호수를 건너게 해주지만, 기둥을 뚫는 유일 수단인 basher가 없으면 col14에서 막힌다.)
# 이로써 basher가 3관문 중 독립적으로 필수임을 입증(클리어 짝 CampaignS9ClearTest와 대비).
# PASS: stage_failed && picks==0 && reached_wall. FAIL: stage_cleared (basher 없이 클리어 = 게이트2 무력) / deadline.

const DEADLINE_FRAMES: int = 30000
const BRIDGE_X_MIN: float = 384.0
const BRIDGE_X_MAX: float = 432.0

# col13 좌측 끝(x∈[624,672)) = 우 base에서 좌 기둥(col14) 직전. 다리로 호수를 건넌 개미만 이 x에 닿는다
# (호수 cols9-11은 갭이라 다리 없이는 불가) → 게이트1 물리 통과 + 게이트2 도달 증거.
const WALL_APPROACH_X: float = 624.0

var _frame: int = 0
var _done: bool = false
var _picks: int = 0
var _bridge_applied: bool = false
var _reached_wall: bool = false

func _ready() -> void:
	Engine.time_scale = 8.0
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)
	EventBus.candy_piece_picked.connect(_on_picked)
	print("[CampaignS9NoBasherTest] driver ready (bridge only, no basher)")

func _physics_process(_delta: float) -> void:
	if _done:
		return
	_frame += 1
	if not _bridge_applied:
		_apply_bridge()
	_track_wall_approach()
	if _frame > DEADLINE_FRAMES:
		_fail("deadline — picks=%d bridge=%s reached_wall=%s (음성 테스트는 stage_failed로 종료돼야 함)" % [
			_picks, _bridge_applied, _reached_wall])

# 어떤 개미가 좌 기둥 직전 col13(x>=624)에 실제 도달 = 호수를 다리로 건너 게이트1을 물리적으로 통과한 증거.
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

func _apply_bridge() -> void:
	for n in get_tree().get_nodes_in_group("ants"):
		var a: Ant = n as Ant
		if a == null or not is_instance_valid(a) or a.state_machine == null:
			continue
		if a.direction != 1 or a.has_candy:
			continue
		if a.global_position.x < BRIDGE_X_MIN or a.global_position.x >= BRIDGE_X_MAX:
			continue
		if not a.cliff_ahead():
			continue
		var bridge: BridgeSkill = BridgeSkill.new()
		if not bridge.can_apply(a):
			continue
		bridge.apply(a)
		_bridge_applied = true
		return

func _on_picked(_remaining_hp: int) -> void:
	_picks += 1

func _on_cleared(_result: Dictionary) -> void:
	if _done:
		return
	_fail("stage_cleared without basher — 좌 기둥을 basher 없이 통과 = 게이트2 무력")

func _on_failed(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	# 개미가 다리로 호수를 건너 기둥 앞(col13)까지 실제 도달(_reached_wall)했는데 게이트2(basher 부재)에서
	# 막혀 picks==0이어야 basher의 독립 필수성이 증명된다. apply() 호출(_bridge_applied)만으론 부족 —
	# bridge가 arm만 되고 개미가 게이트1 전에 죽어도 통과로 오인되므로, 실제 위치 도달을 단언한다.
	if _picks == 0 and _reached_wall:
		print("[CampaignS9NoBasherTest] PASS stage_failed reason=%s picks=0 reached_wall=true bridge=%s (basher 필수성 입증) frame=%d" % [
			str(result.get("reason", "?")), _bridge_applied, _frame])
		get_tree().quit(0)
	else:
		print("[CampaignS9NoBasherTest] FAIL stage_failed picks=%d reached_wall=%s bridge=%s (게이트1 미통과 or candy 도달?) frame=%d" % [
			_picks, _reached_wall, _bridge_applied, _frame])
		get_tree().quit(1)

func _fail(msg: String) -> void:
	print("[CampaignS9NoBasherTest] FAIL %s" % msg)
	_done = true
	get_tree().quit(1)
