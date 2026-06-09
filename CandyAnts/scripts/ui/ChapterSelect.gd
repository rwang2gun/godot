class_name ChapterSelect
extends Control

# campaign-50 Phase A — 챕터 선택 화면 (설계 §5.2). Campaign 매니페스트의 챕터를 카드로 노출한다.
# 카드 상태: LOCKED(이전 챕터 미클리어) / PLAYABLE / CLEARED(챕터 전 스테이지 클리어).
# 선택 → request_stage_select(chapter_num)(잠금 카드는 locked sfx). Back/ESC → request_main_menu.
# 챕터 번호는 1-based (Campaign/CampaignManifest 계약과 동일).

enum ChapterState { LOCKED, PLAYABLE, CLEARED }

const CARD_SCENE := preload("res://scenes/ui/atoms/CButton.tscn")

@onready var _row: HBoxContainer = $MarginContainer/VBox/ChapterRow
@onready var _back_btn: CButton = $MarginContainer/VBox/Header/BackBtn

var _cards: Array[CButton] = []
var _states: Array[int] = []      # _states[i] = ChapterState of chapter (i+1)

func _ready() -> void:
	# BackBtn / ESC는 카드 채우기 실패와 무관하게 항상 살아있도록 먼저 연결(StageSelect와 동형).
	_back_btn.pressed.connect(_on_back_pressed)
	_populate()
	await get_tree().process_frame
	if not _cards.is_empty() and _cards[0].is_inside_tree():
		_cards[0].grab_focus()
	else:
		_back_btn.grab_focus()

func _populate() -> void:
	_cards.clear()
	_states.clear()
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	var count: int = Campaign.chapter_count()
	for c in range(1, count + 1):
		var state: int = _resolve_state(c)
		_states.append(state)
		var card: CButton = CARD_SCENE.instantiate()
		card.kind = CButton.ButtonKind.SECONDARY
		card.custom_minimum_size = Vector2(220, 150)
		card.text = _card_text(c, state)
		if state == ChapterState.LOCKED:
			card.modulate.a = 0.6
		_row.add_child(card)
		card.pressed.connect(_on_card_pressed.bind(c, state))
		_cards.append(card)

func _resolve_state(chapter_num: int) -> int:
	if not Campaign.is_chapter_unlocked(chapter_num):
		return ChapterState.LOCKED
	if Campaign.is_chapter_cleared(chapter_num):
		return ChapterState.CLEARED
	return ChapterState.PLAYABLE

func _card_text(chapter_num: int, state: int) -> String:
	var title: String = Campaign.chapter_title(chapter_num)
	if state == ChapterState.LOCKED:
		return "%d. %s\n잠김" % [chapter_num, title]
	var stage_ct: int = Campaign.stage_ids_in_chapter(chapter_num).size()
	var stars: int = Campaign.chapter_stars(chapter_num)
	return "%d. %s\n★ %d/%d" % [chapter_num, title, stars, stage_ct * 3]

# 테스트용 (1-based). 범위 밖이면 -1.
func chapter_state(chapter_num: int) -> int:
	if chapter_num < 1 or chapter_num > _states.size():
		return -1
	return _states[chapter_num - 1]

func _on_card_pressed(chapter_num: int, state: int) -> void:
	if state == ChapterState.LOCKED:
		EventBus.sfx_request.emit(&"locked")
		return
	EventBus.request_stage_select.emit(chapter_num)

func _on_back_pressed() -> void:
	EventBus.request_main_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	# ESC = BackBtn alias (메인 메뉴 복귀).
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		EventBus.request_main_menu.emit()
