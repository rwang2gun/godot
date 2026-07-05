class_name ChapterSelect
extends Control

# campaign-50 Phase A — 챕터 선택 화면 (설계 §5.2). Campaign 매니페스트의 챕터를 카드로 노출한다.
# 카드 상태: LOCKED(이전 챕터 미클리어) / PLAYABLE / CLEARED(챕터 전 스테이지 클리어).
# 선택 → request_stage_select(chapter_num)(잠금 카드는 locked sfx). Back/ESC → request_main_menu.
# 챕터 번호는 1-based (Campaign/CampaignManifest 계약과 동일).

# ChapterCard.CardState와 enum 순서를 맞춘다(LOCKED=0/PLAYABLE=1/CLEARED=2/UNDER_CONSTRUCTION=3 — 본 화면 SoT).
# ChapterCard는 자체 CardState enum을 갖지만 정수값이 동일해 직접 전달한다.
# UNDER_CONSTRUCTION = "공사 중"(진행 순서 밖, 진입 차단·곧 재개). 진행도 LOCKED와 별개(플래그가 우선).
enum ChapterState { LOCKED, PLAYABLE, CLEARED, UNDER_CONSTRUCTION }

const CARD_SCENE := preload("res://scenes/ui/atoms/ChapterCard.tscn")

@onready var _row: HBoxContainer = $MarginContainer/VBox/ChapterRow
@onready var _back_btn: CButton = $MarginContainer/VBox/Header/BackBtn
@onready var _total_stars_label: Label = $MarginContainer/VBox/Footer/TotalStarsLabel

var _cards: Array[ChapterCard] = []
var _states: Array[int] = []      # _states[i] = ChapterState of chapter (i+1)

func _ready() -> void:
	# BackBtn / ESC는 카드 채우기 실패와 무관하게 항상 살아있도록 먼저 연결(StageSelect와 동형).
	_back_btn.pressed.connect(_on_back_pressed)
	# 전역 별점(매니페스트 등재 한정 — stale 배제). 챕터 카드는 챕터별, 본 footer는 캠페인 누적.
	_total_stars_label.text = Strings.t("chapter_select.total_stars",
		[Campaign.total_stars(), Campaign.total_star_cap()])
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
		var card: ChapterCard = CARD_SCENE.instantiate()
		_row.add_child(card)
		# add_child 후 setup — @onready 노드가 채워진 뒤 렌더(StageSelect.set_state/progress와 동형).
		card.setup(c, state, Campaign.chapter_stars(c), Campaign.chapter_star_cap(c))
		card.pressed.connect(_on_card_pressed.bind(c, state))
		_cards.append(card)

func _resolve_state(chapter_num: int) -> int:
	# 공사 중 플래그가 진행도보다 우선 — ch2를 다 깨 진행상 unlock돼도 진입 차단 유지.
	if Campaign.is_chapter_under_construction(chapter_num):
		return ChapterState.UNDER_CONSTRUCTION
	if not Campaign.is_chapter_unlocked(chapter_num):
		return ChapterState.LOCKED
	if Campaign.is_chapter_cleared(chapter_num):
		return ChapterState.CLEARED
	return ChapterState.PLAYABLE

# 테스트용 (1-based). 범위 밖이면 -1.
func chapter_state(chapter_num: int) -> int:
	if chapter_num < 1 or chapter_num > _states.size():
		return -1
	return _states[chapter_num - 1]

func _on_card_pressed(chapter_num: int, state: int) -> void:
	# LOCKED(진행 미달)·UNDER_CONSTRUCTION(공사 중) 둘 다 진입 불가 → locked sfx만, 화면 전환 없음.
	if state == ChapterState.LOCKED or state == ChapterState.UNDER_CONSTRUCTION:
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
