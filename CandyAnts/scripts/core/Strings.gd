extends Node

# CandyAnts UI 스트링 테이블 — 가벼운 오토로드 (2026-06-02 신설).
# Godot tr()/CSV translation 파이프라인을 쓰지 않는 단일 dict 중앙화 SoT.
#
# 사용:
#   Strings.t("dialog.title_failed")              -> "사탕이 부족했어요"
#   Strings.t("dialog.hero_score", [saved, hp])   -> "3 / 5 조각"  (format % args)
#   Strings.skill_label("climber")                -> "등반"  (미등록 id면 id 그대로)
#
# 범위(2026-06-02): 런타임 .gd 호출부만 이 테이블을 참조한다.
#   씬(.tscn) 고정 text는 의도적으로 미연결 — 일부 라벨("귀가"/"잃음"/"남은 시간" 등)은
#   HUD.tscn Counter의 bottom_label_ko에 정적 중복으로 남아있다.
# key 네임스페이스는 소비 스크립트 기준. 새 문자열 추가 시 해당 섹션에 1줄 추가.

const _TABLE: Dictionary = {
	# StageDialog — scripts/ui/StageDialog.gd
	"dialog.title_last_clear": "마지막 단계 클리어!",
	"dialog.title_cleared": "사탕을 무사히 옮겼어요!",
	"dialog.title_failed": "사탕이 부족했어요",
	"dialog.subtitle_cleared": "Stage cleared",
	"dialog.subtitle_failed": "Stage failed",
	"dialog.hero_score": "%d / %d 조각",
	"dialog.chip_saved": "귀가",
	"dialog.chip_lost": "잃음",
	"dialog.chip_time": "남은 시간",
	"dialog.chip_time_value": "%ds",

	# InputHintLabel — scripts/ui/InputHintLabel.gd
	# 구분자는 가운뎃점(·, U+00B7) 대신 파이프(|) — Jua 폰트에 · 글리프가 없어 웹에서 두부(K-12).
	"hint.mouse": "클릭/드래그: 적용  |  1~8: 스킬  |  Space: 일시정지",
	"hint.pad": "A: 적용  |  LB/RB: 전환  |  View: 일시정지",
	"hint.touch": "탭/드래그: 적용",

	# StageSelect — scripts/ui/StageSelect.gd (현재 챕터 별점 / 챕터 상한. %d 2개)
	"stage_select.total_stars": "수확한 별 ★ %d / %d",

	# ChapterSelect — scripts/ui/ChapterSelect.gd (캠페인 전역 별점 / 전역 상한. %d 2개)
	"chapter_select.total_stars": "모은 별 ★ %d / %d",

	# StageSlotCard — scripts/ui/atoms/StageSlotCard.gd
	"stage_card.title": "스테이지 %d",
	"stage_card.best": "최고 %d",

	# TitleScene — scripts/ui/TitleScene.gd
	"title.hint_pad": "버튼을 눌러 주세요",
	"title.hint_key": "아무 키나 눌러 주세요",

	# StageIntroCard — scripts/ui/StageIntroCard.gd
	# 가이드 없는 스테이지(S9 등)·로드 실패 시 fallback 타이틀/본문.
	"guide.intro_title": "스테이지",
	"guide.intro_body_placeholder": "곧 시작해요!",

	# 입력모델 배지 4종 (SkillAffordance.Category당 1, 스킬 공유 — STAGE_GUIDE_PLAN §0.8.6).
	# 배지는 페이징 카드에 미표시(§2.6.1 은퇴) — inspector·legacy 단일카드 경로 전용. 조작 동사 모드
	# 분기는 인게임 InputHintLabel(hint.*)이 담당하므로 배지는 **모드 중립**("선택")으로 유지한다.
	# 화살표(→, U+2192)는 Jua에 글리프 없어 웹에서 두부(K-12) → 한글 "시"로 표기.
	"guide.badge.ant_armed": "개미 선택 시 자동 발동",
	"guide.badge.ant_settle": "개미 선택 시 정착",
	"guide.badge.sign": "땅 선택 시 표지판",
	"guide.badge.device": "땅 선택 시 장치",

	# 스테이지별 가이드 카피 (STAGE_GUIDE_PLAN §4). data/guides/stageNN_guide.tres가 key로 참조.
	# S1 · 첫 마실 — climber(③) + 글로벌 기본기.
	"guide.s1.goal": "사탕을 한 조각씩 집으로 옮겨요. 5조각을 다 옮기면 성공!",
	"guide.s1.climber_desc": "개미를 탭하면 벽 오르기를 들고 걸어요. 벽을 만나면 스스로 타고 올라가요.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure, 스크린샷 위 오버레이). 3페이지: 획득→운반→벽오르기.
	"guide.s1.page_carry_title": "사탕 조각을 얻어요",
	"guide.s1.page_carry_body": "개미가 사탕에 도착하면 작은 조각을 쪼개 들고 가요.\n개미가 사탕을 쪼갤수록 사탕이 점점 작아져요.",
	"guide.s1.page_deliver_title": "집으로 운반해요",
	"guide.s1.page_deliver_body": "사탕 조각을 집까지 안전하게 옮겨야 해요.\n모든 사탕 조각을 집으로 옮기면 성공!",
	"guide.s1.page_climber_title": "벽 오르기",
	"guide.s1.page_climber_body": "벽 오르기 스킬을 개미에게 주면 벽을 오를 수 있어요.\n벽을 만나면 스스로 타고 올라가요.",
	# S2 · 오르막 — floater(②)·blocker(②, 첫 등장) + 기절 규칙.
	"guide.s2.goal": "높이 올라간 사탕을 가지러 가요. 그런데 내려올 때가 위험해요.",
	"guide.s2.floater_desc": "개미를 탭해 낙하산을 정착시키면, 지나가는 동료들이 낙하산을 받아 높은 곳에서도 안전하게 내려와요.",
	"guide.s2.hazard_stun": "주의: 너무 높이서 떨어지면(6칸 이상) 개미가 기절해 사라져요. 낙하산이 있으면 괜찮아요.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure). 3페이지: 낙하위험→낙하산→길막기.
	"guide.s2.page_danger_title": "높은 곳은 위험해요",
	"guide.s2.page_danger_body": "너무 높은 곳에서 떨어지면, 움직일 수 없어요.",
	"guide.s2.page_floater_title": "낙하산을 나눠줘요",
	"guide.s2.page_floater_body": "낙하산 나눠주기 스킬로 다른 개미를 지켜줄 수 있어요.\n낙하산을 받은 개미는 안전하게 내려갈 수 있어요.",
	# S3 · 사탕 호수 — bridge(③) + 소다물 해저드.
	"guide.s3.goal": "사탕 호수 건너편의 사탕을 가져와요. 물에 빠지면 안 돼요.",
	"guide.s3.bridge_desc": "개미에게 다리만들기를 주면, 낭떠러지에 닿았을 때 스스로 수평 다리를 놓아요. 한 번 놓으면 모두가 건너요.",
	"guide.s3.hazard_water": "주의: 소다물에 닿으면 그 즉시 잃어요. 다리로 건너세요.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure). 2페이지: 물위험→다리.
	"guide.s3.page_water_title": "물에 빠지면 위험해요",
	"guide.s3.page_water_body": "물에 빠지면 다시 올라올 수 없어요.",
	"guide.s3.page_bridge_title": "다리를 놓아요",
	"guide.s3.page_bridge_body": "과자 다리 스킬을 주면 절벽에서 다리를 만들어요.\n다리는 다른 동료도 사용할 수 있어요.",
	# S4 · 계단 공사 — builder(③, 대각 계단).
	"guide.s4.goal": "높은 단 위의 사탕으로 올라가는 계단을 만들어요.",
	"guide.s4.builder_desc": "경사면을 주면 낭떠러지에서 비스듬한 계단을 쌓아 올라가요. 다리는 평평하게, 계단은 위로.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure). 1페이지: 경사면.
	"guide.s4.page_builder_title": "경사면으로 올라가요",
	"guide.s4.page_builder_body": "경사면 스킬로, 높은 곳까지 오르는 다리를 만들 수 있어요.",
	# S5 · 막대과자 탑 — sand_mound(①, 첫 표지판 설치형).
	"guide.s5.goal": "막대과자 사다리를 세워 탑 위 사탕에 닿아요. 내려올 땐 낙하산으로.",
	"guide.s5.sand_mound_desc": "이제는 땅에 표지판을 놓아요. 막대과자 사다리가 세워지고, 무리가 타고 올라가요.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure). 1페이지: 과자 사다리.
	"guide.s5.page_sandmound_title": "과자 사다리",
	"guide.s5.page_sandmound_body": "과자 사다리를 놓을 곳에 표지판을 세우면 사다리를 설치해요.\n과자 사다리로 위층으로 올라갈 수 있어요.",
	# S6 · 땅굴 — digger(①, 수직 아래). 동반 climber는 복습이라 카드 생략(§1: floater 아님 — 안전강하 카피 금지).
	"guide.s6.goal": "땅을 파고 내려가 지하의 사탕을 가져와요.",
	"guide.s6.digger_desc": "땅에 땅파기 표지판을 놓으면, 도착한 개미가 아래로 굴을 파요. 한 번 뚫린 굴은 모두가 써요.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure). 1페이지: 땅파기.
	"guide.s6.page_digger_title": "땅파기",
	"guide.s6.page_digger_body": "땅파기 표지판을 세워두면 땅을 파서 아래층으로 내려갈 수 있어요.",
	# S7 · 옆파기 — basher(①, 수평 앞).
	"guide.s7.goal": "앞을 가로막은 과자 벽을 옆으로 뚫어 길을 내요.",
	"guide.s7.basher_desc": "벽 앞 땅에 벽 부수기 표지판을 놓으면 수평 통로를 파요. 땅파기는 아래로, 벽 부수기는 앞으로.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure). 1페이지: 벽 부수기.
	"guide.s7.page_basher_title": "벽 부수기",
	"guide.s7.page_basher_body": "벽 부수기 표지판을 세워두면 벽을 부숴 터널을 만들어요.\n터널을 지나 반대편으로 이동할 수 있어요.",
	# S8 · 박하 덤불 — cutter(①) + leaf_jump(④, 첫 장치) + 끈끈이 해저드.
	"guide.s8.goal": "박하 덤불을 자르고, 끈끈이를 점프대로 건너 사탕에 닿아요. 서둘러요!",
	"guide.s8.cutter_desc": "식물 자르기는 식물 벽 전용이에요(흙 벽엔 안 통해요).",
	"guide.s8.leaf_jump_desc": "나뭇잎 점프대는 땅에 놓는 장치예요. 개미가 도착하면 폴짝 띄워줘요. 여러 번 써요.",
	"guide.s8.hazard_sticky": "주의: 끈끈이를 밟으면 느려져요(잃지는 않아요). 점프대로 건너뛰세요.",
	# 페이징 카드 페이지 카피 (guide-card-ui-restructure). 3페이지: 끈끈이→점프대→덩굴자르기.
	"guide.s8.page_sticky_title": "카라멜 끈끈이",
	"guide.s8.page_sticky_body": "끈적한 카라멜 끈끈이가 이동을 방해해요.",
	"guide.s8.page_jump_title": "나뭇잎 점프대",
	"guide.s8.page_jump_body": "점프대를 이용하면 장애물을 뛰어넘을 수 있어요.",
	"guide.s8.page_cutter_title": "덩굴 자르기",
	"guide.s8.page_cutter_body": "덩굴 자르기 표지판을 세워두면 앞에 있는 덩굴을 잘라 길을 만들어요.",

	# S11 · 추락 주의 — blocker 튜토리얼 (캠페인 재배치 2026-06-17, 구 S2에서 이동). climber는 복습이라 카드 생략.
	"guide.s11.goal": "추락 주의! 길 막기로 동료들이 떨어지지 않게 막으며 사탕을 모두 옮겨요.",
	"guide.s11.blocker_desc": "개미를 탭해 길 막기를 정착시키면, 그 자리에 버티고 서서 부딪힌 동료의 방향을 되돌려보내요.",
	"guide.s11.page_blocker_title": "위험을 막아줘요",
	"guide.s11.page_blocker_body": "길막기 스킬을 사용하면 자리를 지키고 위험을 알려줘요.\n절벽이나 함정으로 동료들이 가지 못하게 막아요.",

	# 스테이지 표시 이름 SoT = data/stages/stageNN.tres의 display_name (2026-06-17, tres-as-SoT).
	# stage_name(id)이 그 .tres를 로드해 반환하므로 개별 스테이지 이름을 여기 두지 않는다 —
	# 레벨 에디터가 stageNN.tres.display_name에 쓰면 UI(StageSlotCard/StageIntroCard)에 자동 반영된다.
	# coming-soon placeholder("임시")만 시트 소유(미저작 슬롯 = 대응 .tres 없음).
	"stage.coming_soon": "임시",
}

# 스킬 id -> 한글 라벨. 구 SkillToolbar.KO_LABELS를 이관.
# 미등록 id는 skill_label()이 영문 id를 그대로 반환(구 `.get(id, id)` 동작 보존).
const _SKILL_NAMES: Dictionary = {
	"climber": "벽 오르기",
	"floater": "낙하산 나눠주기",
	"blocker": "길막기",
	"slideR": "오른쪽 경사면",
	"slideL": "왼쪽 경사면",
	"sand_mound": "과자 사다리",
	"bridge": "과자 다리",
	"basher": "벽 부수기",
	"digger": "땅파기",
	"cutter": "덩굴 자르기",
	"leaf_jump": "나뭇잎 점프대",
}

# key로 문자열 조회. args 비어있지 않으면 `%` format 적용.
# 미등록 key는 경고 후 key 자체를 반환(렌더 깨짐 없이 누락 노출).
func t(key: String, args: Array = []) -> String:
	if not _TABLE.has(key):
		push_warning("[Strings] missing key: %s" % key)
		return key
	var s: String = _TABLE[key]
	if args.is_empty():
		return s
	return s % args

# 스킬 한글 라벨. 미등록 id는 id 그대로(영문 fallback, 경고 없음).
func skill_label(id: String) -> String:
	return _SKILL_NAMES.get(id, id)

# 스킬 라벨이 명시 등록돼 있는지(영문 fallback과 구분). 스모크 테스트용.
func has_skill_label(id: String) -> bool:
	return _SKILL_NAMES.has(id)

# 스테이지 표시 이름 — data/stages/stageNN.tres의 display_name이 SoT(2026-06-17, tres-as-SoT).
# 레벨 에디터가 쓰는 그 필드를 UI(StageSlotCard/StageIntroCard)가 그대로 읽도록 id로 .tres를 로드해 반환한다.
# 미존재/빈 display_name이면 "" → 소비처가 폴백("임시"/"스테이지 N")을 결정. id별 1회 로드 후 캐시.
var _stage_name_cache: Dictionary = {}

func stage_name(id: int) -> String:
	if _stage_name_cache.has(id):
		return _stage_name_cache[id]
	var nm: String = ""
	var path: String = "res://data/stages/stage%02d.tres" % id
	if ResourceLoader.exists(path):
		var data: Resource = load(path)
		if data != null and "display_name" in data:
			nm = str(data.display_name)
	_stage_name_cache[id] = nm
	return nm

func has_key(key: String) -> bool:
	return _TABLE.has(key)
