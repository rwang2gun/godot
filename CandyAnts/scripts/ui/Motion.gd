class_name Motion
extends RefCounted

# UI_GUIDE §4 — phase 9 작성, 시그니처 freeze.
# phase 10 atoms (CButton boop / Counter caPop) + phase 12 (StageDialog fade) 호출.

# scale .8 → 1.08 → 1.0, 220ms total, TRANS_BACK + EASE_OUT
static func caPop(node: CanvasItem) -> Tween:
	var t := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	node.scale = Vector2(0.8, 0.8)
	t.tween_property(node, "scale", Vector2(1.08, 1.08), 0.10)
	t.tween_property(node, "scale", Vector2(1.0, 1.0),  0.12)
	return t

# position += (2,2) → 0, 120ms 선형
static func boop(node: Control) -> Tween:
	var t := node.create_tween()
	var base := node.position
	t.tween_property(node, "position", base + Vector2(2, 2), 0.06)
	t.tween_property(node, "position", base, 0.06)
	return t

# scale 1.0 ↔ amplitude, period s, infinite loop, SINE in_out
static func idle_bob(node: CanvasItem, amplitude: float = 1.03, period: float = 1.6) -> Tween:
	var t := node.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(node, "scale", Vector2(amplitude, amplitude), period * 0.5)
	t.tween_property(node, "scale", Vector2(1.0, 1.0), period * 0.5)
	return t

# 페이드 트랜지션. pause_safe=true 시 SceneTree.paused 상태에서도 tween 진행 (모달 fade용).
# pause_safe=false (default) 시 노드의 process_mode 따름 — pause 시 정지.
static func fade_in(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween:
	var t := node.create_tween()
	if pause_safe:
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	node.modulate.a = 0.0
	t.tween_property(node, "modulate:a", 1.0, duration)
	return t

static func fade_out(node: CanvasItem, duration: float = 0.3, pause_safe: bool = false) -> Tween:
	var t := node.create_tween()
	if pause_safe:
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(node, "modulate:a", 0.0, duration)
	return t
