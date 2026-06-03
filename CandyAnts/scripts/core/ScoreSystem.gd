class_name ScoreSystem extends RefCounted

var original_hp: int = 0
var saved_pieces: int = 0
var in_transit_pieces: int = 0
var lost_pieces: int = 0

func start(total_hp: int) -> void:
	original_hp = total_hp
	saved_pieces = 0
	in_transit_pieces = 0
	lost_pieces = 0
	print("[ScoreSystem] start total_hp=", original_hp)

	# 멱등 — 같은 ScoreSystem이 두 번 start되어도 중복 connect 안 함.
	# RefCounted라 owner가 사라지면 자동 free되지만 EventBus(autoload)는 그대로라
	# 누적 connect가 stage reload 시 카운트 중복 증가를 만든다 (phase 5 sweep).
	if not EventBus.candy_piece_picked.is_connected(_on_picked):
		EventBus.candy_piece_picked.connect(_on_picked)
	if not EventBus.ant_saved.is_connected(_on_saved):
		EventBus.ant_saved.connect(_on_saved)
	if not EventBus.candy_piece_lost.is_connected(_on_lost):
		EventBus.candy_piece_lost.connect(_on_lost)
	if not EventBus.candy_piece_recovered.is_connected(_on_recovered):
		EventBus.candy_piece_recovered.connect(_on_recovered)

func stop() -> void:
	# StageRunner._exit_tree에서 호출. RefCounted라 GC 시점이 비결정적이라
	# disconnect를 owner의 _exit_tree에 명시적으로 묶는다.
	if EventBus.candy_piece_picked.is_connected(_on_picked):
		EventBus.candy_piece_picked.disconnect(_on_picked)
	if EventBus.ant_saved.is_connected(_on_saved):
		EventBus.ant_saved.disconnect(_on_saved)
	if EventBus.candy_piece_lost.is_connected(_on_lost):
		EventBus.candy_piece_lost.disconnect(_on_lost)
	if EventBus.candy_piece_recovered.is_connected(_on_recovered):
		EventBus.candy_piece_recovered.disconnect(_on_recovered)

func is_cleared(candy_hp: int) -> bool:
	return candy_hp == 0 and in_transit_pieces == 0

func score() -> float:
	if original_hp <= 0:
		return 0.0
	return float(saved_pieces) / float(original_hp)

func _on_picked(_remaining_hp: int) -> void:
	in_transit_pieces += 1
	_assert_invariant()

func _on_saved(_ant: Node, with_candy: bool) -> void:
	if with_candy:
		saved_pieces += 1
		in_transit_pieces -= 1
	_assert_invariant()

func _on_lost(_by_ant: Node) -> void:
	lost_pieces += 1
	in_transit_pieces -= 1
	_assert_invariant()

func _on_recovered(_by_ant: Node) -> void:
	# 바닥 드롭 사탕 재획득 — 드롭 시 lost로 계산했던 조각을 다시 in_transit로 보정.
	lost_pieces -= 1
	in_transit_pieces += 1
	_assert_invariant()

func _assert_invariant() -> void:
	assert(saved_pieces + in_transit_pieces + lost_pieces <= original_hp,
		"ScoreSystem invariant: saved+in_transit+lost(%d+%d+%d) > original(%d)" %
		[saved_pieces, in_transit_pieces, lost_pieces, original_hp])
