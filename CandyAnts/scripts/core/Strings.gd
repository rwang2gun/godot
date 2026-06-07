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
	"hint.mouse": "클릭/드래그: 적용  ·  1~8: 스킬  ·  Space: 일시정지",
	"hint.pad": "A: 적용  ·  LB/RB: 전환  ·  View: 일시정지",
	"hint.touch": "탭/드래그: 적용",

	# StageSelect — scripts/ui/StageSelect.gd
	"stage_select.total_stars": "수확한 별 ★ %d / 30",

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
	# "개미 탭 / 땅 탭"으로 ②③↔①④의 2지선다를 앞세우고(§0.8.4), 카테고리별 결과를 덧붙인다.
	"guide.badge.ant_armed": "개미 탭 → 자동 발동",
	"guide.badge.ant_settle": "개미 탭 → 정착",
	"guide.badge.sign": "땅 탭 → 푯말",
	"guide.badge.device": "땅 탭 → 장치",

	# 스테이지별 가이드 카피 (STAGE_GUIDE_PLAN §4). data/guides/stageNN_guide.tres가 key로 참조.
	# S1 · 첫 마실 — climber(③) + 글로벌 기본기.
	"guide.s1.goal": "사탕을 한 조각씩 집으로 옮겨요. 5조각을 다 옮기면 성공!",
	"guide.s1.climber_desc": "개미를 탭하면 벽 오르기를 들고 걸어요. 벽을 만나면 스스로 타고 올라가요.",
	# S2 · 오르막 — floater(②)·blocker(②, 첫 등장) + 기절 규칙.
	"guide.s2.goal": "높이 올라간 사탕을 가지러 가요. 그런데 내려올 때가 위험해요.",
	"guide.s2.floater_desc": "개미를 탭해 낙하산을 정착시키면, 지나가는 동료들이 낙하산을 받아 높은 곳에서도 안전하게 내려와요.",
	"guide.s2.blocker_desc": "개미를 탭해 길 막기를 정착시키면, 그 자리에 버티고 서서 부딪힌 동료의 방향을 되돌려보내요.",
	"guide.s2.hazard_stun": "⚠ 너무 높이서 떨어지면(6칸↑) 개미가 기절해 사라져요. 낙하산이 있으면 괜찮아요.",
	# S3 · 사탕 호수 — bridge(③) + 소다물 해저드.
	"guide.s3.goal": "사탕 호수 건너편의 사탕을 가져와요. 물에 빠지면 안 돼요.",
	"guide.s3.bridge_desc": "개미에게 다리만들기를 주면, 낭떠러지에 닿았을 때 스스로 수평 다리를 놓아요. 한 번 놓으면 모두가 건너요.",
	"guide.s3.hazard_water": "⚠ 소다물에 닿으면 그 즉시 잃어요. 다리로 건너세요.",
	# S4 · 계단 공사 — builder(③, 대각 계단).
	"guide.s4.goal": "높은 단 위의 사탕으로 올라가는 계단을 만들어요.",
	"guide.s4.builder_desc": "경사면을 주면 낭떠러지에서 비스듬한 계단을 쌓아 올라가요. 다리는 평평하게, 계단은 위로.",
	# S5 · 막대과자 탑 — sand_mound(①, 첫 푯말 설치형).
	"guide.s5.goal": "막대과자 사다리를 세워 탑 위 사탕에 닿아요. 내려올 땐 낙하산으로.",
	"guide.s5.sand_mound_desc": "이제는 땅에 푯말을 놓아요. 막대과자 사다리가 세워지고, 무리가 타고 올라가요.",
	# S6 · 땅굴 — digger(①, 수직 아래). 동반 climber는 복습이라 카드 생략(§1: floater 아님 — 안전강하 카피 금지).
	"guide.s6.goal": "땅을 파고 내려가 지하의 사탕을 가져와요.",
	"guide.s6.digger_desc": "땅에 땅파기 푯말을 놓으면, 도착한 개미가 아래로 굴을 파요. 한 번 뚫린 굴은 모두가 써요.",
	# S7 · 옆파기 — basher(①, 수평 앞).
	"guide.s7.goal": "앞을 가로막은 과자 벽을 옆으로 뚫어 길을 내요.",
	"guide.s7.basher_desc": "벽 앞 땅에 벽 부수기 푯말을 놓으면 수평 통로를 파요. 땅파기는 아래로, 벽 부수기는 앞으로.",
	# S8 · 박하 덤불 — cutter(①) + leaf_jump(④, 첫 장치) + 끈끈이 해저드.
	"guide.s8.goal": "박하 덤불을 자르고, 끈끈이를 점프대로 건너 사탕에 닿아요. 서둘러요!",
	"guide.s8.cutter_desc": "식물 자르기는 식물 벽 전용이에요(흙 벽엔 안 통해요).",
	"guide.s8.leaf_jump_desc": "나뭇잎 점프대는 땅에 놓는 장치예요 — 개미가 도착하면 폴짝 띄워줘요. 여러 번 써요.",
	"guide.s8.hazard_sticky": "⚠ 끈끈이를 밟으면 3초 멈춰요(잃지는 않아요). 점프대로 건너뛰세요.",
}

# 스킬 id -> 한글 라벨. 구 SkillToolbar.KO_LABELS를 이관.
# 미등록 id는 skill_label()이 영문 id를 그대로 반환(구 `.get(id, id)` 동작 보존).
const _SKILL_NAMES: Dictionary = {
	"climber": "벽 오르기",
	"floater": "낙하산 분배",
	"blocker": "길 막기",
	"builder": "경사면",
	"sand_mound": "막대세우기",
	"bridge": "다리만들기",
	"basher": "벽 부수기",
	"digger": "땅파기",
	"cutter": "식물 자르기",
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

func has_key(key: String) -> bool:
	return _TABLE.has(key)
