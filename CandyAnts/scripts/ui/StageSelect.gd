class_name StageSelect
extends Control

# Phase 13 — plan §3.6.3. StageSelect: 슬롯 GridContainer + BackBtn.
# campaign-50 Phase A — 챕터 컨텍스트화(설계 §5.2): menu_layout 고정 10슬롯 폐기 →
#   Campaign.stage_ids_in_chapter(current_chapter)로 가변 개수 슬롯 생성. Back → ChapterSelect.
# Δ11: ESC = BackBtn alias (dialog-local) → request_chapter_select.
# Δ14: 본 파일은 StageDialog 전용 legacy alias signal을 emit하지 않는다 — only request_chapter_select.
#      (SceneFlowEmitContractTest가 정적 grep으로 보장)
# Δ15: SlotState priority = COMING_SOON > CLEARED > PLAYABLE > LOCKED.

const SLOT_CARD_SCENE := preload("res://scenes/ui/atoms/StageSlotCard.tscn")

# go_to_stage_select(chapter)가 add_child 전에 set. 기본 1(직접 인스턴스화 시).
var current_chapter: int = 1

@onready var _slot_grid: GridContainer = $MarginContainer/VBox/SlotGrid
@onready var _back_btn: CButton = $MarginContainer/VBox/Header/BackBtn
@onready var _title_label: Label = $MarginContainer/VBox/Header/Title
@onready var _total_stars_label: Label = $MarginContainer/VBox/Footer/TotalStarsLabel
# Sweep 1 (phase 13): MainMenu.gd 와 동일 — class_name cold-parse 미해결 방지 +
# codex sweep 1 R1 P1 수용 (untyped → dynamic dispatch + method warning 회피).
@onready var _coming_soon = $ComingSoonOverlay

var _slot_cards: Array[StageSlotCard] = []

func _ready() -> void:
	# Codex R9 LOW fix: BackBtn / focus 연결을 슬롯 생성보다 먼저 — 빈 챕터/무효 매니페스트에도
	# 메뉴 복귀 가능 (BackBtn 작동, ESC 작동, 패드 포커스 살아있음).
	_back_btn.pressed.connect(_on_back_pressed)
	_total_stars_label.text = Strings.t("stage_select.total_stars", [SaveData.total_stars()])
	var chapter_title: String = Campaign.chapter_title(current_chapter)
	if not chapter_title.is_empty():
		_title_label.text = chapter_title
	SceneFlow.ensure_stage_scan()  # standalone 진입에서도 STAGE_SCENES(씬 존재) 채워짐 보장.
	_populate_slots()
	await get_tree().process_frame
	if not _slot_cards.is_empty() and _slot_cards[0].is_inside_tree():
		_slot_cards[0].grab_focus()
	else:
		_back_btn.grab_focus()

func _populate_slots() -> void:
	_slot_cards.clear()
	for child in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	for stage_id in Campaign.stage_ids_in_chapter(current_chapter):
		var card: StageSlotCard = SLOT_CARD_SCENE.instantiate() as StageSlotCard
		card.stage_id = stage_id
		var entry: Dictionary = SaveData.get_stage_entry(stage_id)
		var state: int = _resolve_slot_state(stage_id, entry)
		_slot_grid.add_child(card)
		card.set_state(state)
		card.set_progress(entry)
		card.pressed.connect(_on_slot_pressed.bind(stage_id, state))
		_slot_cards.append(card)

func _resolve_slot_state(stage_id: int, entry: Dictionary) -> int:
	# ComingSoon = 매니페스트 등재됐으나 씬 파일 부재(미저작 placeholder). priority 최상위(Δ15).
	if not SceneFlow.STAGE_SCENES.has(stage_id):
		return StageSlotCard.SlotState.COMING_SOON
	if entry.get("cleared", false):
		return StageSlotCard.SlotState.CLEARED
	if Campaign.is_stage_unlocked(stage_id):
		return StageSlotCard.SlotState.PLAYABLE
	return StageSlotCard.SlotState.LOCKED

func _on_slot_pressed(stage_id: int, state: int) -> void:
	match state:
		StageSlotCard.SlotState.PLAYABLE, StageSlotCard.SlotState.CLEARED:
			EventBus.request_play_stage.emit(stage_id)
		StageSlotCard.SlotState.LOCKED:
			EventBus.sfx_request.emit(&"locked")
		StageSlotCard.SlotState.COMING_SOON:
			_coming_soon.show_overlay()

func _on_back_pressed() -> void:
	EventBus.request_chapter_select.emit()

func _unhandled_input(event: InputEvent) -> void:
	# Δ11: ESC = BackBtn alias → ChapterSelect 복귀.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		EventBus.request_chapter_select.emit()
