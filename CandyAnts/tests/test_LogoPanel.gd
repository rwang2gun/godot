extends Node

# LogoPanel.wordmark_min_size 회귀 테스트.
# 배경(2026-06-09): MainMenu가 내부 Wordmark 노드에 custom_minimum_size override를
# 직접 걸었더니 export 바이너리 패킹에서 유실 → 빌드에서만 로고가 작아지는 버그.
# 수정: LogoPanel 루트 export 속성 wordmark_min_size를 _ready에서 내부 노드에 적용.
# 이 테스트는 "루트 속성이 내부 Wordmark.custom_minimum_size로 반영"됨을 보장한다.

const LogoScene := preload("res://scenes/ui/atoms/LogoPanel.tscn")

func _ready() -> void:
	# (a) 기본값 — 기존 사용처(TitleScene) 불변 보장.
	var a: LogoPanel = LogoScene.instantiate()
	add_child(a)
	await get_tree().process_frame
	var wa: TextureRect = a.get_node("VBox/Wordmark")
	if wa.custom_minimum_size != Vector2(540, 135):
		return _fail("기본 wordmark_min_size 미반영: %s" % wa.custom_minimum_size)

	# (b) 설정값이 내부 Wordmark에 반영되는지 (= 패킹에 안전한 경로).
	var b: LogoPanel = LogoScene.instantiate()
	b.wordmark_min_size = Vector2(820, 440)
	add_child(b)
	await get_tree().process_frame
	var wb: TextureRect = b.get_node("VBox/Wordmark")
	if wb.custom_minimum_size != Vector2(820, 440):
		return _fail("설정 wordmark_min_size 미반영: %s" % wb.custom_minimum_size)

	print("[test_LogoPanel] PASS")
	get_tree().quit(0)

func _fail(msg: String) -> void:
	print("[test_LogoPanel] FAIL ", msg)
	get_tree().quit(1)
