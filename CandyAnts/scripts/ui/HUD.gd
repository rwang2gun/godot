class_name HUD extends CanvasLayer

# Phase 11 rewrite (plan v2 §3). 5 placeholder Label + AcceptDialog 제거 →
# Counter atom 5 (CANDY_HP/IN_TRANSIT/SAVED/LOST/TIME) + ReleaseRateStepper + PauseBtn.
# 외부 API `update_time(seconds)`만 보존. (phase 12에서 show_dialog stub 제거 — StageDialog가 EventBus.stage_cleared/failed 라우팅)
# HUD root = INHERIT (Counter caPop이 pause 시 정지). (2026-06-02: 하단 InputHintLabel 가이드 라벨 + AlwaysBranch 제거)
# EventBus 구독은 기존 3-시그널(candy_piece_picked / ant_saved / candy_piece_lost) 유지
# — phase doc의 candy_hp_changed/ant_in_transit_changed 등은 미존재, 본 HUD가 4-카운터 derive.

@onready var _counter_candy: Counter = $Root/TopLeft/CounterCandyHp
@onready var _counter_in_transit: Counter = $Root/TopLeft/CounterInTransit
@onready var _counter_saved: Counter = $Root/TopLeft/CounterSaved
@onready var _counter_lost: Counter = $Root/TopLeft/CounterLost
@onready var _counter_time: Counter = $Root/TopRight/CounterTime

var _saved: int = 0
var _lost: int = 0
var _in_transit: int = 0
var _candy_hp: int = 0
var _last_time_int: int = -1

func _ready() -> void:
	if not EventBus.candy_piece_picked.is_connected(_on_picked):
		EventBus.candy_piece_picked.connect(_on_picked)
	if not EventBus.ant_saved.is_connected(_on_saved):
		EventBus.ant_saved.connect(_on_saved)
	if not EventBus.candy_piece_lost.is_connected(_on_lost):
		EventBus.candy_piece_lost.connect(_on_lost)
	_refresh_all()

func _exit_tree() -> void:
	if EventBus.candy_piece_picked.is_connected(_on_picked):
		EventBus.candy_piece_picked.disconnect(_on_picked)
	if EventBus.ant_saved.is_connected(_on_saved):
		EventBus.ant_saved.disconnect(_on_saved)
	if EventBus.candy_piece_lost.is_connected(_on_lost):
		EventBus.candy_piece_lost.disconnect(_on_lost)

# StageRunner._ready가 stage 시작 시 1회 호출 — 초기 candy_hp를 카운터에 표시.
# candy_piece_picked는 ant가 첫 piece 픽업 시점부터만 발화하므로, 본 메서드 없으면 시작
# 직후 0으로 노출되는 회귀 (CounterCandyHp가 stage 시작 HP 표시 안 됨).
func set_candy_hp(hp: int) -> void:
	_candy_hp = hp
	if _counter_candy != null:
		_counter_candy.set_value(_candy_hp)

# StageRunner._process가 매 frame 호출 — 정수 변동 시점에만 caPop 발화.
func update_time(seconds: float) -> void:
	var s: int = int(ceil(seconds))
	if s == _last_time_int:
		return
	_last_time_int = s
	if _counter_time != null:
		_counter_time.set_value(s)

func _on_picked(remaining_hp: int) -> void:
	_candy_hp = remaining_hp
	_in_transit += 1
	_refresh_candy_and_in_transit()

func _on_saved(_ant: Node, with_candy: bool) -> void:
	if with_candy:
		_saved += 1
		_in_transit -= 1
	_refresh_saved_and_in_transit()

func _on_lost(_by_ant: Node) -> void:
	_lost += 1
	_in_transit -= 1
	_refresh_lost_and_in_transit()

func _refresh_all() -> void:
	if _counter_candy != null: _counter_candy.set_value(_candy_hp)
	if _counter_in_transit != null: _counter_in_transit.set_value(_in_transit)
	if _counter_saved != null: _counter_saved.set_value(_saved)
	if _counter_lost != null: _counter_lost.set_value(_lost)

func _refresh_candy_and_in_transit() -> void:
	if _counter_candy != null: _counter_candy.set_value(_candy_hp)
	if _counter_in_transit != null: _counter_in_transit.set_value(_in_transit)

func _refresh_saved_and_in_transit() -> void:
	if _counter_saved != null: _counter_saved.set_value(_saved)
	if _counter_in_transit != null: _counter_in_transit.set_value(_in_transit)

func _refresh_lost_and_in_transit() -> void:
	if _counter_lost != null: _counter_lost.set_value(_lost)
	if _counter_in_transit != null: _counter_in_transit.set_value(_in_transit)
