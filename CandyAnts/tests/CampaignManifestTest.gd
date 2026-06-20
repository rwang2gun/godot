extends Node

# campaign-50 Phase A — CampaignManifest 리소스 + 파생 헬퍼 검증.
# is_valid(정상/중복/빈/타입) + ordered/chapter_of/next/position/first/last/stage_ids_in_chapter 경계.

func _ready() -> void:
	_test_live_manifest()
	if _failed: return
	_test_is_valid_rules()
	if _failed: return
	print("[CampaignManifestTest] PASS")
	get_tree().quit(0)

var _failed: bool = false

func _test_live_manifest() -> void:
	var m: CampaignManifest = load("res://data/campaign_manifest.tres") as CampaignManifest
	if m == null:
		return _fail("campaign_manifest.tres load failed")
	if not m.is_valid():
		return _fail("live manifest is_valid() false")
	if m.chapter_count() != 5:
		return _fail("chapter_count expected 5, got %d" % m.chapter_count())
	var ordered: Array[int] = m.ordered_stage_ids()
	# Ch3~5(파괴/장치/종합)는 under_construction="공사 중" → ordered에서 제외, 캠페인은 Ch2(25)에서 끝.
	# 재개 시 manifest 플래그 제거 + 본 기대값에 6,7,8,9,10 복원.
	var expected: Array[int] = [1, 11, 12, 13, 14, 2, 15, 16, 17, 18, 3, 4, 5, 19, 20, 21, 22, 23, 24, 25]
	if ordered != expected:
		return _fail("ordered_stage_ids expected %s, got %s" % [str(expected), str(ordered)])
	# 공사 중 플래그: Ch1/2 false, Ch3~5 true (카드는 chapters 그대로라 chapter_of/title은 5챕터 유지).
	if m.is_chapter_under_construction(2) or m.is_chapter_under_construction(1):
		return _fail("Ch1/Ch2 should NOT be under_construction")
	for c in [3, 4, 5]:
		if not m.is_chapter_under_construction(c):
			return _fail("Ch%d should be under_construction" % c)
	# chapter_of (1-based, 0=미등재)
	_eq(m.chapter_of(1), 1, "chapter_of(1)")
	_eq(m.chapter_of(12), 1, "chapter_of(12=B1 신규)")
	_eq(m.chapter_of(2), 1, "chapter_of(2=slot6 재배치)")
	_eq(m.chapter_of(3), 2, "chapter_of(3)")
	_eq(m.chapter_of(8), 4, "chapter_of(8)")
	_eq(m.chapter_of(10), 5, "chapter_of(10)")
	_eq(m.chapter_of(99), 0, "chapter_of(99=미등재)")
	# next_stage_id — Ch1 체인 1→11→12→13→14→2→3
	_eq(m.next_stage_id(1), 11, "next(1)")
	_eq(m.next_stage_id(11), 12, "next(11)")
	_eq(m.next_stage_id(14), 2, "next(14)")
	_eq(m.next_stage_id(2), 15, "next(2)")
	_eq(m.next_stage_id(24), 25, "next(24)")
	_eq(m.next_stage_id(25), 0, "next(25=last)")
	# 공사 중 챕터 스테이지는 ordered 밖 → not-found(0). (진입/이어가기 차단의 근거.)
	_eq(m.next_stage_id(8), 0, "next(8=공사중 제외)")
	_eq(m.next_stage_id(10), 0, "next(10=공사중 제외)")
	_eq(m.next_stage_id(99), 0, "next(99=미등재)")
	# position_of
	_eq(m.position_of(1), 1, "position(1)")
	_eq(m.position_of(11), 2, "position(11)")
	_eq(m.position_of(2), 6, "position(2)")
	_eq(m.position_of(25), 20, "position(25=last)")
	_eq(m.position_of(10), 0, "position(10=공사중 제외)")
	_eq(m.position_of(99), 0, "position(99)")
	# first/last — 캠페인 끝은 Ch2 마지막(25).
	_eq(m.first_stage_id(), 1, "first")
	_eq(m.last_stage_id(), 25, "last")
	# stage_ids_in_chapter (1-based)
	if m.stage_ids_in_chapter(1) != ([1, 11, 12, 13, 14, 2, 15, 16, 17, 18] as Array[int]):
		return _fail("chapter1 stage_ids expected [1,11,12,13,14,2,15,16,17,18], got %s" % str(m.stage_ids_in_chapter(1)))
	if m.stage_ids_in_chapter(2) != ([3, 4, 5, 19, 20, 21, 22, 23, 24, 25] as Array[int]):
		return _fail("chapter2 stage_ids expected [3,4,5,19,20,21,22,23,24,25], got %s" % str(m.stage_ids_in_chapter(2)))
	if m.stage_ids_in_chapter(5) != ([9, 10] as Array[int]):
		return _fail("chapter5 stage_ids expected [9,10], got %s" % str(m.stage_ids_in_chapter(5)))
	if not m.stage_ids_in_chapter(99).is_empty():
		return _fail("chapter99 stage_ids expected empty")
	if m.chapter_title(1) != "기초":
		return _fail("chapter_title(1) expected 기초, got %s" % m.chapter_title(1))

func _test_is_valid_rules() -> void:
	# 빈 chapters → invalid
	var empty := CampaignManifest.new()
	empty.chapters = []
	if empty.is_valid():
		return _fail("empty chapters should be invalid")
	# 전역 중복 씬 id → invalid
	var dup := CampaignManifest.new()
	dup.chapters = [
		{"title": "A", "theme": "a", "stage_ids": [1, 2]},
		{"title": "B", "theme": "b", "stage_ids": [2, 3]},
	]
	if dup.is_valid():
		return _fail("duplicate scene id across chapters should be invalid")
	# 키 누락 → invalid
	var missing := CampaignManifest.new()
	missing.chapters = [{"title": "A", "stage_ids": [1]}]
	if missing.is_valid():
		return _fail("missing theme key should be invalid")
	# 모든 챕터 빈 stage_ids → invalid (any_stage false)
	var allempty := CampaignManifest.new()
	allempty.chapters = [{"title": "A", "theme": "a", "stage_ids": []}]
	if allempty.is_valid():
		return _fail("all-empty stage_ids should be invalid")
	# 0 씬 id → invalid (sentinel 충돌, codex R1 MED-2)
	var zero := CampaignManifest.new()
	zero.chapters = [{"title": "A", "theme": "a", "stage_ids": [0, 1]}]
	if zero.is_valid():
		return _fail("scene id 0 should be invalid (sentinel collision)")
	# 음수 씬 id → invalid
	var neg := CampaignManifest.new()
	neg.chapters = [{"title": "A", "theme": "a", "stage_ids": [1, -3]}]
	if neg.is_valid():
		return _fail("negative scene id should be invalid")
	# 정상 → valid
	var ok := CampaignManifest.new()
	ok.chapters = [{"title": "A", "theme": "a", "stage_ids": [1]}, {"title": "B", "theme": "b", "stage_ids": [2]}]
	if not ok.is_valid():
		return _fail("valid manifest reported invalid")
	# 비어있지 않은 챕터 1개 이상이면 일부 빈 챕터 허용
	var mixed := CampaignManifest.new()
	mixed.chapters = [{"title": "A", "theme": "a", "stage_ids": [1]}, {"title": "B", "theme": "b", "stage_ids": []}]
	if not mixed.is_valid():
		return _fail("mixed empty chapter should still be valid")

func _eq(actual: int, expected: int, label: String) -> void:
	if _failed: return
	if actual != expected:
		_fail("%s expected %d, got %d" % [label, expected, actual])

func _fail(msg: String) -> void:
	if _failed: return
	_failed = true
	print("[CampaignManifestTest] FAIL ", msg)
	get_tree().quit(1)
