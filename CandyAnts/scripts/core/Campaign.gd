extends Node

# campaign-50 Phase A — 캠페인 순서/언락 파생의 단일 진입점 (autoload). 설계 §5.0.
# CampaignManifest(순서·챕터 배치) + SaveData(cleared/stars 저장)를 합성해 ordering/unlock을 제공한다.
# SaveData는 순수 저장 유지(ordering 무지) — 디커플링(ADR). 본 autoload는 SaveData/EventBus 이후 로드.
# fail-closed: manifest 누락/무효면 빈 캠페인(전부 닫힘, 크래시 금지) — SceneFlow 정책과 동형.

const MANIFEST_PATH := "res://data/campaign_manifest.tres"

var _manifest: CampaignManifest = null

func _ready() -> void:
	_load_manifest()

func _load_manifest() -> void:
	var m: Resource = ResourceLoader.load(MANIFEST_PATH) if ResourceLoader.exists(MANIFEST_PATH) else null
	if m is CampaignManifest and m.is_valid():
		_manifest = m
	else:
		push_error("[Campaign] manifest 누락/무효 — 캠페인 닫힘(fail-closed)")
		_manifest = null
	# SceneFlow는 published/LAST를 Campaign.manifest()에서 파생한다(단일 SoT). 매니페스트가 바뀌면
	# SceneFlow 캐시를 무효화해 다음 스캔이 갱신본으로 재빌드되게 한다(codex impl R1 MED).
	SceneFlow.invalidate_stage_scan()

func manifest() -> CampaignManifest:
	return _manifest

func has_manifest() -> bool:
	return _manifest != null

func ordered_stage_ids() -> Array[int]:
	return _manifest.ordered_stage_ids() if _manifest != null else ([] as Array[int])

func chapter_count() -> int:
	return _manifest.chapter_count() if _manifest != null else 0

func stage_ids_in_chapter(chapter_num: int) -> Array[int]:
	return _manifest.stage_ids_in_chapter(chapter_num) if _manifest != null else ([] as Array[int])

func chapter_title(chapter_num: int) -> String:
	return _manifest.chapter_title(chapter_num) if _manifest != null else ""

func chapter_of(scene_id: int) -> int:
	return _manifest.chapter_of(scene_id) if _manifest != null else 0

func next_stage_id(scene_id: int) -> int:
	return _manifest.next_stage_id(scene_id) if _manifest != null else 0

# 스테이지 언락: manifest 순서상 첫 스테이지거나, 직전(한 칸 앞) 스테이지가 cleared. (±1 산술 아님.)
func is_stage_unlocked(scene_id: int) -> bool:
	if _manifest == null:
		return false
	var ordered: Array[int] = _manifest.ordered_stage_ids()
	var idx: int = ordered.find(scene_id)
	if idx < 0:
		return false
	if idx == 0:
		return true
	return _is_cleared(ordered[idx - 1])

# 챕터 언락: 1번 챕터는 항상, 그 외는 직전 *비어있지 않은* 챕터의 마지막 스테이지 cleared 시.
# (빈 챕터는 skip해 그 앞으로 거슬러 — 데드 게이트 방지.)
# 챕터 번호는 1-based 계약(0/음수 = not-found sentinel). 범위 밖은 fail-closed 거부 (codex R2 MED-1).
func is_chapter_unlocked(chapter_num: int) -> bool:
	if _manifest == null:
		return false
	if chapter_num < 1 or chapter_num > _manifest.chapter_count():
		return false
	if chapter_num == 1:
		return true
	for c in range(chapter_num - 1, 0, -1):
		var ids: Array[int] = _manifest.stage_ids_in_chapter(c)
		if ids.is_empty():
			continue
		return _is_cleared(ids[ids.size() - 1])
	return true

func chapter_stars(chapter_num: int) -> int:
	if _manifest == null:
		return 0
	var sum: int = 0
	for sid in _manifest.stage_ids_in_chapter(chapter_num):
		sum += int(SaveData.get_stage_entry(sid).get("stars", 0))
	return sum

# 챕터 별점 상한 = 그 챕터 스테이지 수 × 3 (전역 규칙: 스테이지당 최대 ★3).
func chapter_star_cap(chapter_num: int) -> int:
	return stage_ids_in_chapter(chapter_num).size() * 3

# 캠페인 전역 별점 — **매니페스트 등재 스테이지만** 합산(manifest-bounded).
# SaveData.total_stars()는 등재 밖 stale 진행도까지 더해 오버플로(39/30)를 내므로 UI는 이쪽을 쓴다.
func total_stars() -> int:
	if _manifest == null:
		return 0
	var sum: int = 0
	for c in range(1, _manifest.chapter_count() + 1):
		sum += chapter_stars(c)
	return sum

# 전역 별점 상한 = 등재 전 스테이지 수 × 3.
func total_star_cap() -> int:
	return ordered_stage_ids().size() * 3

# 챕터 클리어 = 그 챕터 전 스테이지 cleared (빈 챕터는 false).
func is_chapter_cleared(chapter_num: int) -> bool:
	if _manifest == null:
		return false
	var ids: Array[int] = _manifest.stage_ids_in_chapter(chapter_num)
	if ids.is_empty():
		return false
	for sid in ids:
		if not _is_cleared(sid):
			return false
	return true

# Play 버튼용 — 순서상 첫 미클리어(=이어가기). 전부 클리어면 첫 스테이지.
func next_unlocked_stage() -> int:
	if _manifest == null:
		return 0
	var ordered: Array[int] = _manifest.ordered_stage_ids()
	for sid in ordered:
		if not _is_cleared(sid):
			return sid
	return ordered[0] if not ordered.is_empty() else 0

func _is_cleared(scene_id: int) -> bool:
	return bool(SaveData.get_stage_entry(scene_id).get("cleared", false))

# ─── test seam (CampaignUnlockOrderTest) ───────────────────────────
# 테스트가 통제된 manifest를 주입해 ordering/unlock 파생을 결정적으로 검증.
# SceneFlow 캐시도 무효화 → published/LAST/next가 주입 매니페스트를 따른다(단일 SoT, codex impl R1 MED).
func _test_set_manifest(m: CampaignManifest) -> void:
	_manifest = m
	SceneFlow.invalidate_stage_scan()
