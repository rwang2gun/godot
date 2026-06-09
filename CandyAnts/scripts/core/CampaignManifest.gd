class_name CampaignManifest
extends Resource

# campaign-50 Phase A — 캠페인 순서/챕터 배치를 씬 id에서 분리하는 매핑 계층 (설계 §5.0, ADR-014).
# chapters[c] = { "title": String, "theme": String, "stage_ids": Array[int] }
#   stage_ids = 그 챕터에 들어갈 씬 id들을 "순서대로" 나열. 재배치 = 이 배열 편집(파일 rename 0).
# 챕터 번호는 공개 API에서 1-based (chapter_of 0 = 미등재). 내부 chapters 배열은 0-based.
# 파생 헬퍼는 모두 chapters에서 계산 — 별도 상태 없음(단일 SoT).

@export var chapters: Array[Dictionary] = []

# 전역 무결성: 비어있지 않음 + 각 챕터 title/theme/stage_ids(int 배열) + 전역 중복 씬 id 금지 +
# stage_ids 비어있지 않은 챕터 1개 이상. (한 씬이 두 챕터에 노출되는 모순 차단.)
func is_valid() -> bool:
	if chapters.is_empty():
		return false
	var seen: Dictionary = {}
	var any_stage: bool = false
	for ch in chapters:
		if typeof(ch) != TYPE_DICTIONARY:
			return false
		if not (ch.has("title") and ch.has("theme") and ch.has("stage_ids")):
			return false
		if typeof(ch["title"]) != TYPE_STRING or typeof(ch["theme"]) != TYPE_STRING:
			return false
		var ids = ch["stage_ids"]
		if typeof(ids) != TYPE_ARRAY:
			return false
		for sid in ids:
			if typeof(sid) != TYPE_INT:
				return false
			# fail-closed: 0/음수 거부 (codex R1 MED-2). 0은 first/next/position의 not-found
			# sentinel이므로 0·음수 씬 id가 valid를 통과하면 sentinel 충돌(미등재와 구분 불가).
			if sid <= 0:
				return false
			if seen.has(sid):
				return false
			seen[sid] = true
			any_stage = true
	return any_stage

# 전 챕터 평탄화 = 캠페인 전역 순서.
func ordered_stage_ids() -> Array[int]:
	var out: Array[int] = []
	for ch in chapters:
		var ids = ch.get("stage_ids", [])
		if typeof(ids) == TYPE_ARRAY:
			for sid in ids:
				out.append(int(sid))
	return out

func chapter_count() -> int:
	return chapters.size()

# 1-based 챕터 번호의 stage_ids. 범위 밖이면 빈 배열.
func stage_ids_in_chapter(chapter_num: int) -> Array[int]:
	var out: Array[int] = []
	if chapter_num < 1 or chapter_num > chapters.size():
		return out
	var ids = chapters[chapter_num - 1].get("stage_ids", [])
	if typeof(ids) == TYPE_ARRAY:
		for sid in ids:
			out.append(int(sid))
	return out

func chapter_title(chapter_num: int) -> String:
	if chapter_num < 1 or chapter_num > chapters.size():
		return ""
	return String(chapters[chapter_num - 1].get("title", ""))

func chapter_theme(chapter_num: int) -> String:
	if chapter_num < 1 or chapter_num > chapters.size():
		return ""
	return String(chapters[chapter_num - 1].get("theme", ""))

# 씬 id가 속한 챕터 번호(1-based). 0 = 미등재.
func chapter_of(scene_id: int) -> int:
	for i in chapters.size():
		var ids = chapters[i].get("stage_ids", [])
		if typeof(ids) == TYPE_ARRAY and ids.has(scene_id):
			return i + 1
	return 0

# 전역 순서상 다음 씬 id. 없으면(미등재 or 마지막) 0.
func next_stage_id(scene_id: int) -> int:
	var ordered: Array[int] = ordered_stage_ids()
	var idx: int = ordered.find(scene_id)
	if idx < 0 or idx + 1 >= ordered.size():
		return 0
	return ordered[idx + 1]

# 전역 1-based 위치. 미등재 0.
func position_of(scene_id: int) -> int:
	var ordered: Array[int] = ordered_stage_ids()
	var idx: int = ordered.find(scene_id)
	return idx + 1 if idx >= 0 else 0

func first_stage_id() -> int:
	var ordered: Array[int] = ordered_stage_ids()
	return ordered[0] if not ordered.is_empty() else 0

func last_stage_id() -> int:
	var ordered: Array[int] = ordered_stage_ids()
	return ordered[ordered.size() - 1] if not ordered.is_empty() else 0
