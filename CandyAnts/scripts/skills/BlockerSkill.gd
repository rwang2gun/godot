class_name BlockerSkill extends Skill

const ID: String = "blocker"

# 솔버 self-describing 메타 (auto-solver Phase 1, D7). 솔버는 SkillRegistry로 이걸 generic 열거해
# 행동공간을 구성한다(스킬별 하드코딩 금지). category는 SkillAffordance.SKILL_CATEGORY와 동기
# (SkillMetadataDriftTest가 일치를 강제). target: 적용 대상 = 개미 탭("ant") vs 표면 셀 설치("cell").
const SOLVER_META := {
	"target": "ant",
	"category": "ANT_SETTLE",
	"routing": "reverse",
	"purpose": "앞 보행 개미를 정지시켜 벽을 만들고 뒤따르는 개미를 반전시킨다",
	"hints": {"effect": "stop_and_reverse_walkers"},
}

# can_apply 단일 진실 출처 (phase04-review HIGH 대응).
# 운반 중(CarryingState/has_candy)에도 적용 가능 (2026-06-17) — floater 분배자처럼 들고 있던 사탕을
# 그 자리에 드롭한 뒤 정지한다(apply). 드롭 즉시 candy_piece_lost로 in_transit→lost 정산되므로,
# 운반자 Blocker화 시 in_transit이 영구 잔존하던 데드락(구 has_candy 거부 사유)이 해소된다. 떨어진
# 사탕은 DroppedCandy로 남아 다른 개미가 회수(candy_piece_recovered)할 수 있다.
func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	if not ant.is_on_floor():
		return false
	var s: AntState = ant.state_machine.current_state
	return s is WalkerState or s is CarryingState

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	# 운반 중이면 사탕 드롭 — 즉시 lost 회계 + 재획득 가능한 DroppedCandy 생성(Skill 공용 헬퍼,
	# floater 분배자와 동일). 비운반이면 no-op.
	_drop_carried_candy(ant)
	# 시각 전용 — Blocker는 걷던 방향 반대를 바라보고 정지. _update_sprite()가 다음 frame
	# 에 flip_h 자동 갱신. bumped_blocker 발화는 blocker direction 무관(walker direction
	# 만 반전)이므로 시뮬레이션 로직에 영향 없음.
	ant.flip()
	ant.state_machine.change_state(WorkerState.new("blocker"))
