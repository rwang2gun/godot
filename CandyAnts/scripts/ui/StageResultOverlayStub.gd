class_name StageResultOverlayStub extends Control

@onready var _title: Label = $VBox/Title
@onready var _score: Label = $VBox/Score
@onready var _reason: Label = $VBox/Reason
@onready var _replay: Button = $VBox/HBox/ReplayButton
@onready var _next: Button = $VBox/HBox/NextButton
@onready var _menu: Button = $VBox/HBox/MenuButton

func _ready() -> void:
	visible = false
	_replay.pressed.connect(_on_replay_pressed)
	_next.pressed.connect(_on_next_pressed)
	_menu.pressed.connect(_on_menu_pressed)

func show_result(result: Dictionary, is_last_stage: bool) -> void:
	_title.text = "스테이지 클리어!" if result["cleared"] else "스테이지 실패"
	_score.text = "점수: %d%%" % int(round(result["score"] * 100.0))
	if result["cleared"]:
		_reason.visible = false
	else:
		_reason.visible = true
		_reason.text = "사유: %s" % result["reason"]
	_replay.disabled = false
	# Next는 cleared 결과에서만 활성. last stage는 무조건 disable (codex plan-review HIGH 2026-05-10).
	_next.disabled = is_last_stage or not result["cleared"]
	_menu.disabled = false
	visible = true

func hide_overlay() -> void:
	visible = false
	_replay.disabled = false
	_next.disabled = false
	_menu.disabled = false

func _disable_all_buttons() -> void:
	_replay.disabled = true
	_next.disabled = true
	_menu.disabled = true

func _on_replay_pressed() -> void:
	_disable_all_buttons()
	EventBus.request_replay.emit()

func _on_next_pressed() -> void:
	_disable_all_buttons()
	EventBus.request_next.emit()

func _on_menu_pressed() -> void:
	_disable_all_buttons()
	EventBus.request_menu.emit()
