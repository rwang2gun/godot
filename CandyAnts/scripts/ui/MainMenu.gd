class_name MainMenu
extends Control

# Phase 13 — plan §3.6.2. MainMenu: 6 버튼 column + Continue 가드 + ComingSoonOverlay.
# Δ14: 본 파일은 StageDialog 전용 legacy alias signal을 emit하지 않는다 — only request_main_menu.
# (SceneFlowEmitContractTest가 정적 grep으로 보장)

@onready var _play_btn: CButton = $Center/VBox/PlayBtn
@onready var _continue_btn: CButton = $Center/VBox/ContinueBtn
@onready var _stage_select_btn: CButton = $Center/VBox/StageSelectBtn
@onready var _settings_btn: CButton = $Center/VBox/SettingsBtn
@onready var _credits_btn: CButton = $Center/VBox/CreditsBtn
@onready var _quit_btn: CButton = $Center/VBox/QuitBtn
# Sweep 1 (phase 13): type annotation 제거 — `: ComingSoonOverlay`가 cold-parse 시점에
# 미해결되면 본 스크립트 통째로 parse fail → MainMenu node script 미부착 → handler connect 0.
# untyped로 두면 `show_overlay()` 호출이 dynamic dispatch + 정적 type checker가 method warning
# 안 냄 (phase 10 lessons §2 "class_name 등록 부트스트랩" 패턴 + codex sweep 1 R1 P1 수용).
@onready var _coming_soon = $ComingSoonOverlay
# 메인 메뉴 마스코트 — 버튼 위 좌·우에 victory 애니메이션 캐릭터 한 쌍을 장식으로 재생.
@onready var _victory_left: AnimatedSprite2D = $VictoryLeft
@onready var _victory_right: AnimatedSprite2D = $VictoryRight

func _ready() -> void:
	_connect_buttons()
	_refresh_continue_state()
	_start_victory_mascot()
	await get_tree().process_frame
	_grab_initial_focus()

# AntFrames.tres의 victory는 loop:false(인게임 1회 재생 의미 유지) — 공유 리소스를 건드리지 않고
# animation_finished에서 각 스프라이트를 재시작해 메뉴에서만 연속 재생한다(중앙 + 우하단 둘 다).
func _start_victory_mascot() -> void:
	for s: AnimatedSprite2D in [_victory_left, _victory_right]:
		if s == null:
			continue
		var cb: Callable = _on_victory_finished.bind(s)
		if not s.animation_finished.is_connected(cb):
			s.animation_finished.connect(cb)
		s.play(&"victory")

func _on_victory_finished(s: AnimatedSprite2D) -> void:
	if is_instance_valid(s):
		s.play(&"victory")

func _connect_buttons() -> void:
	_play_btn.pressed.connect(_on_play_pressed)
	_continue_btn.pressed.connect(_on_continue_pressed)
	_stage_select_btn.pressed.connect(_on_stage_select_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_credits_btn.pressed.connect(_on_credits_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

func _refresh_continue_state() -> void:
	# Δ4: last_played > 0 AND SceneFlow에 stage 존재 AND is_unlocked
	var last_id: int = SaveData.last_played_stage
	SceneFlow.ensure_stage_scan()  # standalone 진입에서도 PUBLISHED_STAGE_IDS 채워짐 보장.
	# 캠페인 published(씬 ∩ menu_layout.available)만 Continue 대상 — 미공개 StageNN 노출 차단(codex HIGH).
	var can_continue: bool = last_id > 0 \
		and SceneFlow.PUBLISHED_STAGE_IDS.has(last_id) \
		and SaveData.is_unlocked(last_id)
	_continue_btn.disabled = not can_continue

func _grab_initial_focus() -> void:
	# Continue가 enabled면 Continue, 아니면 Play.
	var target: CButton = _continue_btn if not _continue_btn.disabled else _play_btn
	if target.is_inside_tree():
		target.grab_focus()

func _on_play_pressed() -> void:
	EventBus.request_play_stage.emit(1)

func _on_continue_pressed() -> void:
	if _continue_btn.disabled:
		return
	EventBus.request_play_stage.emit(SaveData.last_played_stage)

func _on_stage_select_pressed() -> void:
	EventBus.request_stage_select.emit()

func _on_settings_pressed() -> void:
	_coming_soon.show_overlay()

func _on_credits_pressed() -> void:
	_coming_soon.show_overlay()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _unhandled_input(_event: InputEvent) -> void:
	# Δ11: MainMenu ESC 무시 (실수 종료 방지).
	pass
