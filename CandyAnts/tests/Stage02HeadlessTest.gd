extends Node

# Phase 3 통합 회귀 테스트 — Codex HIGH 대응.
# UI 우회로 BuilderSkill을 첫 ant에 자동 적용 → stage_cleared/score 자동 검증.
# PASS: get_tree().quit(0). FAIL: quit(1). 타임아웃: --quit-after로 default 0 (PASS 텍스트 부재로 외부 검증).

const TRIGGER_X: float = 870.0   # ant가 cell 54(x=864..880)에 있을 때 → 첫 타일 cell 55 (x=880..896, 좌측 platform 우측 인접). 안전구간 [864, 879].
const PASS_SCORE: float = 0.6    # 다른 ants도 다리 통과해야 score >= 0.6

var _builder_applied: bool = false
var _result_emitted: bool = false

func _ready() -> void:
	print("[Phase3Test] driver ready, trigger_x=", TRIGGER_X, " pass_score=", PASS_SCORE)
	EventBus.stage_cleared.connect(_on_cleared)
	EventBus.stage_failed.connect(_on_failed)

func _process(_delta: float) -> void:
	if _builder_applied or _result_emitted:
		return
	var ants: Array = get_tree().get_nodes_in_group("ants")
	for n in ants:
		var a: Ant = n as Ant
		if a == null:
			continue
		if a.has_been_carrying:
			continue
		if a.global_position.x < TRIGGER_X:
			continue
		var builder: BuilderSkill = BuilderSkill.new()
		if not builder.can_apply(a):
			continue
		builder.apply(a)
		_builder_applied = true
		print("[Phase3Test] applied Builder to ", a.name, " at x=", a.global_position.x)
		return

func _on_cleared(score: float) -> void:
	if _result_emitted:
		return
	_result_emitted = true
	print("[Phase3Test] cleared score=", score)
	if score >= PASS_SCORE:
		print("[Phase3Test] PASS")
		get_tree().quit(0)
	else:
		print("[Phase3Test] FAIL low_score=", score, " < ", PASS_SCORE)
		get_tree().quit(1)

func _on_failed(reason: String) -> void:
	if _result_emitted:
		return
	_result_emitted = true
	print("[Phase3Test] failed reason=", reason)
	print("[Phase3Test] FAIL")
	get_tree().quit(1)
