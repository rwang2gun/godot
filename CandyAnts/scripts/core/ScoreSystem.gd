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

	EventBus.candy_piece_picked.connect(_on_picked)
	EventBus.ant_saved.connect(_on_saved)
	EventBus.candy_piece_lost.connect(_on_lost)

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

func _assert_invariant() -> void:
	assert(saved_pieces + in_transit_pieces + lost_pieces <= original_hp,
		"ScoreSystem invariant: saved+in_transit+lost(%d+%d+%d) > original(%d)" %
		[saved_pieces, in_transit_pieces, lost_pieces, original_hp])
