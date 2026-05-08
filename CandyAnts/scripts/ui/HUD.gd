class_name HUD extends CanvasLayer

@onready var _time_label: Label = $Root/Time
@onready var _out_label: Label = $Root/Out
@onready var _saved_label: Label = $Root/Saved
@onready var _lost_label: Label = $Root/Lost
@onready var _candy_label: Label = $Root/Candy
@onready var _dialog: AcceptDialog = $StageCompleteDialog

var _saved: int = 0
var _lost: int = 0
var _in_transit: int = 0
var _candy_hp: int = 0
var _saved_total: int = 0

func _ready() -> void:
	EventBus.candy_piece_picked.connect(_on_picked)
	EventBus.ant_saved.connect(_on_saved)
	EventBus.candy_piece_lost.connect(_on_lost)
	_refresh()

func update_time(seconds: float) -> void:
	if _time_label != null:
		_time_label.text = "Time: %d" % int(ceil(seconds))

func show_dialog(message: String) -> void:
	if _dialog != null:
		_dialog.dialog_text = message
		_dialog.popup_centered()

func _on_picked(remaining_hp: int) -> void:
	_candy_hp = remaining_hp
	_in_transit += 1
	_refresh()

func _on_saved(_ant: Node, with_candy: bool) -> void:
	if with_candy:
		_saved_total += 1
		_in_transit -= 1
	_saved += 1
	_refresh()

func _on_lost(_by_ant: Node) -> void:
	_lost += 1
	_in_transit -= 1
	_refresh()

func _refresh() -> void:
	if _candy_label != null:
		_candy_label.text = "Candy HP: %d" % _candy_hp
	if _out_label != null:
		_out_label.text = "In transit: %d" % _in_transit
	if _saved_label != null:
		_saved_label.text = "Saved: %d" % _saved_total
	if _lost_label != null:
		_lost_label.text = "Lost: %d" % _lost
