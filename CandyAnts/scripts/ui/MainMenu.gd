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

func _ready() -> void:
	_connect_buttons()
	_refresh_continue_state()
	await get_tree().process_frame
	_grab_initial_focus()

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
	var can_continue: bool = last_id > 0 \
		and SceneFlow.STAGE_SCENES.has(last_id) \
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
