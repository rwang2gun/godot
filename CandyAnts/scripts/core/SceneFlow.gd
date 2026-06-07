class_name SceneFlow extends Node

# Phase 6 + 12 + 13. plan v2 §3.5 SoT.
# Screen state machine: TITLE / MAIN_MENU / STAGE_SELECT / STAGE.
# 모든 screen 전이는 _swap_screen / load_stage 경유 + _unload_current_screen
# 이 remove_child + queue_free 일괄 → stale emit 0 (plan Δ9 / codex Round 1 HIGH-1).

const GameAction := preload("res://scripts/input/GameAction.gd")

enum ScreenState { TITLE, MAIN_MENU, STAGE_SELECT, STAGE }

# 스테이지 라우팅 — 두 단계로 분리(codex adversarial-review HIGH 대응, 2026-06-04):
#   STAGE_SCENES        = `res://scenes/stages/Stage%02d.tscn` 파일 존재 스캔. load_stage(N)/replay/playtest용.
#                         "파일이 있으면 로드는 가능" — 하지만 캠페인 노출과는 분리한다.
#   PUBLISHED_STAGE_IDS = STAGE_SCENES ∩ menu_layout.tres `available==true`. **캠페인 SoT.**
#                         LAST_STAGE_ID(엔드포인트)·load_next_stage(다음)·Continue 가용성은 이쪽만 본다.
# 근거: 파일 존재만으로 캠페인 routing을 결정하면, 미완성/실수 커밋된 StageNN.tscn이 authored
#   available 게이트를 우회해 Next로 노출되고 엔드포인트(LAST_STAGE_ID)를 멋대로 옮긴다. authored
#   menu_layout 플래그를 캠페인 게이트로 유지하되, 씬 스캔으로 신규 스테이지 "로드 가능"은 자동화한다.
# export 안전: DirAccess(res:// 리매핑 취약) 대신 ResourceLoader.exists로 프로빙.
# lazy 1회 스캔: static var 초기자에서 직접 스캔하면 클래스 로드 타이밍에 엔진 싱글톤 접근으로 크래시 →
#   ensure_stage_scan()을 진입점(_ready/load_*)에서 호출해 런타임에 1회만 채운다.
# dev stage(910~)는 패턴/스캔 상한(1..99) 밖이라 자연 제외(기존 동작 유지).
const STAGE_SCENE_PATTERN := "res://scenes/stages/Stage%02d.tscn"
const STAGE_SCAN_MAX := 99
const MENU_LAYOUT_PATH := "res://data/menu_layout.tres"
static var STAGE_SCENES: Dictionary = {}
static var PUBLISHED_STAGE_IDS: Dictionary = {}
static var LAST_STAGE_ID: int = 0
static var _stage_scan_done := false

# 스테이지 스캔을 1회 보장. SceneFlow._ready를 거치지 않고 STAGE_SCENES/PUBLISHED_STAGE_IDS/
# LAST_STAGE_ID를 읽는 외부 호출자(예: MainMenu standalone)도 채워진 값을 보도록 진입점에서 호출한다.
static func ensure_stage_scan() -> void:
	if _stage_scan_done:
		return
	_stage_scan_done = true
	# (1) 씬 스캔 — 파일 존재만(load_stage/replay/playtest용, 캠페인 노출 아님).
	var scenes := {}
	for id in range(1, STAGE_SCAN_MAX + 1):
		var path: String = STAGE_SCENE_PATTERN % id
		if ResourceLoader.exists(path):
			scenes[id] = path
	STAGE_SCENES = scenes
	# (2) 캠페인 published — 씬 존재 ∩ menu_layout.available. authored 게이트로 미완성 스테이지 노출 차단.
	# **fail closed**: menu_layout이 없거나 MenuLayout이 아니거나 is_valid()가 거짓이면 published를 비운다.
	#   (fail open으로 씬 스캔을 전부 published 하면, 손상된 빌드+미공개 StageNN 동시 발생 시 HIGH가 재현됨.)
	#   is_valid() 통과 시에만 slot 직접 인덱싱(타입·길이·stage_id 정합 보장됨).
	var published := {}
	var last := 0
	var layout: Resource = ResourceLoader.load(MENU_LAYOUT_PATH) if ResourceLoader.exists(MENU_LAYOUT_PATH) else null
	if layout is MenuLayout and layout.is_valid():
		for slot: Dictionary in layout.slots:
			var sid: int = int(slot["stage_id"])
			if bool(slot["available"]) and scenes.has(sid):
				published[sid] = scenes[sid]
				last = maxi(last, sid)
	else:
		# 손상된 빌드: 미공개 스테이지를 노출하느니 캠페인을 닫는다(published 비움, LAST_STAGE_ID=0).
		push_error("[SceneFlow] menu_layout 누락/무효 — 캠페인 published 비움(fail closed)")
	PUBLISHED_STAGE_IDS = published
	LAST_STAGE_ID = last

const TITLE_SCENE := "res://scenes/ui/TitleScene.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const STAGE_SELECT_SCENE := "res://scenes/ui/StageSelect.tscn"

@export var current_stage_root_path: NodePath
@export var overlay_path: NodePath
@export var virtual_cursor_path: NodePath
@export var cursor_targeting_resolver_path: NodePath
# Phase 4 (intro-card-infra) — 스테이지 진입 인트로 카드. 비어 있으면(미배선) 카드 없이 즉시 begin.
@export var intro_card_path: NodePath
# 카드 노출 토글. false면 항상 스킵(즉시 begin). 헤드리스는 별도로 자동 스킵(_intro_enabled).
@export var show_intro_cards: bool = true
# Phase 13 — SceneFlowBootBypassTest 전용 (plan Δ10). production 부트는 0 → TITLE.
# add_child(main) 전에 export 설정해야 _ready에서 인식. 0이면 정상 title 부트.
@export var boot_to_stage_id: int = 0

var _current_stage_root: Node = null
var _overlay: Node = null
var _current_stage_id: int = 0
var _current_stage_node: Node = null
var _resolver: Node = null
var _last_result: Dictionary = {}
# Phase 4 — 인트로 카드 + begin() 게이트.
var _intro_card: Node = null
var _pending_intro_stage: Node = null
# 테스트 seam: 헤드리스에서도 카드 노출 경로(게이트→dismiss→begin)를 검증하려고 헤드리스 스킵을 우회.
var _test_force_intro: bool = false

var current_screen: ScreenState = ScreenState.TITLE

func _ready() -> void:
	ensure_stage_scan()
	_current_stage_root = get_node(current_stage_root_path)
	_overlay = get_node(overlay_path)
	if not intro_card_path.is_empty():
		_intro_card = get_node_or_null(intro_card_path)

	if not virtual_cursor_path.is_empty():
		var cursor: Control = get_node_or_null(virtual_cursor_path) as Control
		if cursor != null:
			InputRouter.set_virtual_cursor(cursor)
	if not cursor_targeting_resolver_path.is_empty():
		_resolver = get_node_or_null(cursor_targeting_resolver_path)

	EventBus.stage_cleared.connect(_on_stage_result)
	EventBus.stage_failed.connect(_on_stage_result)
	EventBus.request_replay.connect(_on_request_replay)
	EventBus.request_next.connect(_on_request_next)
	EventBus.request_menu.connect(_on_request_menu)
	EventBus.request_main_menu.connect(_on_request_main_menu)
	EventBus.request_stage_select.connect(_on_request_stage_select)
	EventBus.request_play_stage.connect(_on_request_play_stage)
	EventBus.request_title.connect(_on_request_title)
	EventBus.action_triggered.connect(_on_action_triggered)

	_boot()

func _exit_tree() -> void:
	# Phase 4 — 카드 표시 중 SceneFlow(Main) teardown 시 InputRouter(autoload) 인트로 게이트가
	# true로 남는 leak 방어. 다음 SceneFlow가 blocked로 시작하지 않도록 자기 게이트만 해제.
	if _pending_intro_stage != null:
		_set_intro_pause_block(false)
		_pending_intro_stage = null

func _boot() -> void:
	if boot_to_stage_id > 0 and STAGE_SCENES.has(boot_to_stage_id):
		load_stage(boot_to_stage_id)
	else:
		go_to_title()

# ─── screen 전이 (public) ────────────────────────────────────────
func start_game() -> void:
	# Legacy. phase 13에서 _boot()가 대체. 호환 보존.
	go_to_title()

func go_to_title() -> void:
	_swap_screen(load(TITLE_SCENE).instantiate(), ScreenState.TITLE)

func go_to_main_menu() -> void:
	_swap_screen(load(MAIN_MENU_SCENE).instantiate(), ScreenState.MAIN_MENU)

func go_to_stage_select() -> void:
	_swap_screen(load(STAGE_SELECT_SCENE).instantiate(), ScreenState.STAGE_SELECT)

func go_to_menu() -> void:
	# phase 6 legacy 시그니처 보존 — main menu alias.
	go_to_main_menu()

func load_stage(stage_id: int) -> void:
	ensure_stage_scan()
	# Codex R6 HIGH fix: 잘못된 stage_id에 대해 _unload_current_screen()를 먼저 호출하면
	# blank screen + 복구 경로 없음. 검증을 unload 전에 옮기고, 미존재 stage는 fallback.
	if not STAGE_SCENES.has(stage_id):
		push_error("[SceneFlow] unknown stage_id %d — falling back to main menu" % stage_id)
		# blank 회피 — 현재 screen이 STAGE면 main menu로, 그 외엔 그대로 유지.
		if current_screen == ScreenState.STAGE:
			go_to_main_menu()
		return
	# Codex(세션 8) — 등록된 stage_id라도 그 .tscn/.tres가 누락(미커밋·export 제외)이면 load()가 null 반환 →
	# instantiate() 크래시. **_unload_current_screen() 전에** load+검증해(codex 재리뷰 MEDIUM) 실패 시 현재 화면을
	# 파괴하지 않고 보존 — unknown stage_id 가드와 동일 정책(STAGE면 main menu, 그 외엔 유지).
	var scene: PackedScene = load(STAGE_SCENES[stage_id])
	if scene == null:
		push_error("[SceneFlow] stage %d 리소스 load 실패(%s) — 현재 화면 보존(STAGE면 main menu)" % [stage_id, STAGE_SCENES[stage_id]])
		if current_screen == ScreenState.STAGE:
			go_to_main_menu()
		return
	_unload_current_screen()
	_last_result = {}
	var stage_node: Node = scene.instantiate()
	# Phase 4 — 인트로 카드 게이트. 카드를 띄울 땐 add_child(=_ready) 전에 auto_begin=false로 둬서
	# _ready가 spawn을 시작하지 않게 하고, 카드 dismiss 후 begin()을 호출한다. has_method 가드로
	# begin()이 없는 비-StageRunner 루트는 자연히 즉시 시작(set()은 미존재 시 무해한 no-op).
	var gate_with_card: bool = _intro_enabled() and stage_node.has_method("begin")
	if gate_with_card:
		stage_node.set("auto_begin", false)
	_current_stage_root.add_child(stage_node)
	_current_stage_node = stage_node
	_current_stage_id = stage_id
	current_screen = ScreenState.STAGE
	if _resolver != null and _resolver.has_method("set_active_stage_root"):
		_resolver.set_active_stage_root(stage_node)
	if gate_with_card:
		_show_intro_card(stage_node)

# ─── Phase 4: 인트로 카드 게이트 ────────────────────────────────
# 카드를 띄울지 여부. show_intro_cards 토글 + 카드 배선 + (헤드리스 자동 스킵 | 테스트 강제) 조합.
func _intro_enabled() -> bool:
	if not show_intro_cards:
		return false
	if _intro_card == null:
		return false
	if _test_force_intro:
		return true
	# 헤드리스(자동 테스트·서버)는 카드 스킵 → 즉시 begin. 기존 SceneFlow 구동 헤드리스 테스트 회귀 0.
	return DisplayServer.get_name() != "headless"

func _show_intro_card(stage_node: Node) -> void:
	_pending_intro_stage = stage_node
	if not _intro_card.intro_dismissed.is_connected(_on_intro_dismissed):
		_intro_card.intro_dismissed.connect(_on_intro_dismissed, CONNECT_ONE_SHOT)
	var stage_data: StageData = null
	if "stage_data" in stage_node:
		stage_data = stage_node.stage_data
	_intro_card.show_intro(stage_data)
	# codex impl-review R1 MEDIUM — 카드 표시 중 pause/step/restart 입력을 중앙 게이트에서 차단.
	# StepFrame의 tree.paused 토글 + PauseMenu 표시 둘 다 PAUSE_TOGGLE emit에 의존하므로 InputRouter
	# 단일 지점에서 막으면 "begin 전 모달 스택" 전체를 봉쇄한다(카드 Esc는 _unhandled_input이라 무영향).
	_set_intro_pause_block(true)

func _on_intro_dismissed() -> void:
	var node: Node = _pending_intro_stage
	_pending_intro_stage = null
	_set_intro_pause_block(false)
	# 카드가 닫혔을 때의 현재 스테이지가 게이트한 노드와 동일할 때만 begin (전환 race 방어).
	if node != null and is_instance_valid(node) and node == _current_stage_node and node.has_method("begin"):
		node.begin()

func _reset_intro_card() -> void:
	if _intro_card == null:
		return
	if _intro_card.intro_dismissed.is_connected(_on_intro_dismissed):
		_intro_card.intro_dismissed.disconnect(_on_intro_dismissed)
	if _intro_card.has_method("hide_intro"):
		_intro_card.hide_intro()
	# 카드 구간이 열려 있었으면(pending 존재) pause block을 닫는다 — 메뉴 전환 후 stuck 차단.
	if _pending_intro_stage != null:
		_set_intro_pause_block(false)
	_pending_intro_stage = null

# 카드 표시 동안 pause-affecting action(PAUSE_TOGGLE/STEP_FRAME/RESTART_STAGE) emit을 막는다.
# InputRouter의 인트로 전용 게이트(StepFrame과 독립)를 토글 → in-flight StepFrame continuation의
# release가 카드 block을 clobber하지 못함(codex impl-review R2 MEDIUM 해소).
func _set_intro_pause_block(blocked: bool) -> void:
	if InputRouter != null and InputRouter.has_method("set_intro_pause_blocked"):
		InputRouter.set_intro_pause_blocked(blocked)

func load_next_stage() -> void:
	var next_id: int = _current_stage_id + 1
	# 캠페인 진행은 published(=씬 ∩ menu_layout.available)만. 미완성/미공개 StageNN 파일이 있어도
	# Next로 넘어가지 않는다(codex HIGH). 다음 published가 없으면 last-stage clear → main menu.
	if not PUBLISHED_STAGE_IDS.has(next_id):
		go_to_main_menu()
		return
	load_stage(next_id)

func replay_stage() -> void:
	load_stage(_current_stage_id)

func get_active_stage_node() -> Node:
	if _current_stage_node == null:
		return null
	if not is_instance_valid(_current_stage_node):
		_current_stage_node = null
		return null
	return _current_stage_node

# ─── 내부 헬퍼 ──────────────────────────────────────────────────
# plan Δ9 (codex HIGH-1): remove_child + queue_free 일괄.
# queue_free 단독 사용 시 deferred deletion이라 다음 frame까지 tree에 남음 →
# 그 사이 _process가 깨어나 stale stage_cleared/failed emit 가능.
# remove_child로 즉시 tree에서 분리 후 queue_free → _process 중단 보장.
# CurrentStageRoot 자체 process_mode를 INHERIT으로 복귀하면서 메뉴 진입 후 frozen
# 잔존 차단 (frozen된 채 메뉴 _process가 안 도는 버그 차단).
func _unload_current_screen() -> void:
	# Phase 4 — 화면 파괴 전 인트로 카드도 강제 정리(카드 표시 중 replay/menu 전환 시 stale begin 차단).
	_reset_intro_card()
	var children: Array = _current_stage_root.get_children()
	for child in children:
		_current_stage_root.remove_child(child)
		child.queue_free()
	_current_stage_node = null
	_current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT
	if _resolver != null and _resolver.has_method("set_active_stage_root"):
		_resolver.set_active_stage_root(null)

func _swap_screen(new_node: Node, new_state: ScreenState) -> void:
	_unload_current_screen()
	_current_stage_node = null
	_current_stage_id = 0
	_last_result = {}
	_current_stage_root.add_child(new_node)
	current_screen = new_state

func _freeze_current_stage() -> void:
	# phase 12 산출. StageDialog 표시 중 stage 정지.
	_current_stage_root.process_mode = Node.PROCESS_MODE_DISABLED

func _unfreeze_current_stage() -> void:
	_current_stage_root.process_mode = Node.PROCESS_MODE_INHERIT

# ─── EventBus 핸들러 ───────────────────────────────────────────
func _on_stage_result(result: Dictionary) -> void:
	_last_result = result
	_freeze_current_stage()
	# Phase 20 — `>=` → `==` 등치 변경 (R1-H4). 미래 STAGE_SCENES 확장 시 last-stage 오인 회피.
	# dev stage(910~)는 STAGE_SCENES 미등록 → SceneFlow 경유 안 함 (자연 분기 유지).
	_overlay.show_result(result, result["stage_id"] == LAST_STAGE_ID)

func _on_request_replay() -> void:
	_overlay.hide_overlay()
	if current_screen != ScreenState.STAGE or _current_stage_id <= 0:
		return
	_unfreeze_current_stage()
	replay_stage()

func _on_request_next() -> void:
	# Next는 cleared 결과에서만 (phase 6 산출, plan §3.5.4)
	if not _last_result.get("cleared", false):
		return
	_overlay.hide_overlay()
	_unfreeze_current_stage()
	load_next_stage()

func _on_request_menu() -> void:
	# Δ14 legacy alias — StageDialog Menu 버튼만 emit. main menu 복귀로 매핑.
	_on_request_main_menu()

func _on_request_main_menu() -> void:
	_overlay.hide_overlay()
	go_to_main_menu()

func _on_request_stage_select() -> void:
	_overlay.hide_overlay()
	go_to_stage_select()

func _on_request_play_stage(stage_id: int) -> void:
	# 캠페인 trust boundary는 여기서 중앙 강제(codex MEDIUM). request_play_stage는 player 경로
	# (MainMenu Play/Continue·StageSelect 슬롯)이므로 published(=씬 ∩ menu_layout.available)만 허용.
	# 미공개 StageNN.tscn이 있어도, 어떤 호출자가 request_play_stage(N)을 emit해도 로드되지 않는다.
	# (replay/내부 직접 진행은 load_stage를 직접 호출 — 이미 published 경유로 들어온 현재 스테이지만 대상.)
	ensure_stage_scan()
	if not PUBLISHED_STAGE_IDS.has(stage_id):
		push_error("[SceneFlow] request_play_stage(%d) 거부 — 미공개 스테이지(campaign gate)" % stage_id)
		return
	_overlay.hide_overlay()
	load_stage(stage_id)

func _on_request_title() -> void:
	_overlay.hide_overlay()
	go_to_title()

func _on_action_triggered(name: StringName, _payload: Dictionary) -> void:
	if name != GameAction.RESTART_STAGE:
		return
	# 메뉴에서 Ctrl+R/pad B-hold 무시 (plan §3.5.5)
	if current_screen != ScreenState.STAGE:
		return
	if InputRouter != null and InputRouter.has_method("are_pause_actions_blocked") \
			and InputRouter.are_pause_actions_blocked():
		return
	EventBus.request_replay.emit()
