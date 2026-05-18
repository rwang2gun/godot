class_name StageSelect
extends Control

# Phase 13 — plan §3.6.3. StageSelect: 10 슬롯 GridContainer + BackBtn.
# Δ11: ESC = BackBtn alias (dialog-local).
# Δ14: 본 파일은 StageDialog 전용 legacy alias signal을 emit하지 않는다 — only request_main_menu.
#      (SceneFlowEmitContractTest가 정적 grep으로 보장)
# Δ15: SlotState priority = COMING_SOON > CLEARED > PLAYABLE > LOCKED.

const LAYOUT_PATH := "res://data/menu_layout.tres"
const SLOT_CARD_SCENE := preload("res://scenes/ui/atoms/StageSlotCard.tscn")

@onready var _slot_grid: GridContainer = $MarginContainer/VBox/SlotGrid
@onready var _back_btn: CButton = $MarginContainer/VBox/Header/BackBtn
@onready var _total_stars_label: Label = $MarginContainer/VBox/Footer/TotalStarsLabel
@onready var _coming_soon: ComingSoonOverlay = $ComingSoonOverlay

var _slot_cards: Array[StageSlotCard] = []

func _ready() -> void:
	# Codex R9 LOW fix: BackBtn / focus 연결을 layout 검증보다 먼저 — invalid layout 시에도
	# 메뉴 복귀 가능 (BackBtn 작동, ESC 작동, 패드 포커스 살아있음).
	_back_btn.pressed.connect(_on_back_pressed)
	_total_stars_label.text = "수확한 별 ★ %d / 30" % SaveData.total_stars()
	var layout: MenuLayout = load(LAYOUT_PATH) as MenuLayout
	if layout == null or not layout.is_valid():
		push_error("[StageSelect] invalid menu_layout.tres — showing empty grid, BackBtn 활성")
	else:
		_populate_slots(layout)
	await get_tree().process_frame
	_back_btn.grab_focus()

func _populate_slots(layout: MenuLayout) -> void:
	_slot_cards.clear()
	for child in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	for i in 10:
		var meta: Dictionary = layout.slots[i]
		var stage_id: int = int(meta["stage_id"])
		var card: StageSlotCard = SLOT_CARD_SCENE.instantiate() as StageSlotCard
		card.stage_id = stage_id
		var entry: Dictionary = SaveData.get_stage_entry(stage_id)
		var state: int = _resolve_slot_state(meta, stage_id, entry)
		_slot_grid.add_child(card)
		card.set_state(state)
		card.set_progress(entry)
		card.pressed.connect(_on_slot_pressed.bind(stage_id, state))
		_slot_cards.append(card)

func _resolve_slot_state(meta: Dictionary, stage_id: int, entry: Dictionary) -> int:
	# Δ15: priority — coming_soon은 cleared/playable보다 우선.
	if not bool(meta.get("available", false)):
		return StageSlotCard.SlotState.COMING_SOON
	if entry.get("cleared", false):
		return StageSlotCard.SlotState.CLEARED
	if SaveData.is_unlocked(stage_id):
		return StageSlotCard.SlotState.PLAYABLE
	return StageSlotCard.SlotState.LOCKED

func _on_slot_pressed(stage_id: int, state: int) -> void:
	match state:
		StageSlotCard.SlotState.PLAYABLE, StageSlotCard.SlotState.CLEARED:
			EventBus.request_play_stage.emit(stage_id)
		StageSlotCard.SlotState.LOCKED:
			EventBus.sfx_request.emit(&"sfx:locked")
		StageSlotCard.SlotState.COMING_SOON:
			_coming_soon.show_overlay()

func _on_back_pressed() -> void:
	EventBus.request_main_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	# Δ11: ESC = BackBtn alias.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		EventBus.request_main_menu.emit()
