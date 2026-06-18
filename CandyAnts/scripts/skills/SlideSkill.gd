class_name SlideSkill extends Skill

# 계단(구 builder) 스킬의 방향 분리 공통 베이스 (2026-06-18). slideR(우향)·slideL(좌향)이
# 이 클래스를 상속해 _build_direction()만 다르게 정의한다. 부여 시 개미를 그 방향으로 돌려세운 뒤
# 기존 계단 건설 로직(WorkerState work_type="builder", 방향 무관 _place_one_tile)을 재사용한다.
# (베이스엔 const ID 없음 — Skill.gd 규칙: GDScript const 상속 shadowing 금지. 서브클래스가 ID 정의.)

# 서브클래스가 계단 방향을 반환: +1=오른쪽 위, -1=왼쪽 위. (베이스 기본값은 방어적 우향.)
func _build_direction() -> int:
	return 1

func can_apply(ant: Ant) -> bool:
	if ant == null or ant.state_machine == null:
		return false
	# 이미 무장(계단/다리/굴착/절단) 중이면 중복 부여 차단 — 무장 스킬 상호 배타(구 BuilderSkill 답습).
	if ant.builder_armed or ant.bridge_armed or ant.basher_armed or ant.cutter_armed:
		return false
	var s: AntState = ant.state_machine.current_state
	# Walker 또는 Carrying만 허용. Faller/Worker/Saved/Dead 거부.
	if not (s is WalkerState or s is CarryingState):
		return false
	if not ant.is_on_floor():
		return false
	return true

func apply(ant: Ant) -> void:
	if ant == null or ant.state_machine == null:
		return
	var dir: int = _build_direction()
	# 지정 방향으로 돌려세운다(slideR=우향 / slideL=좌향). 시각 flip_h도 direction을 따라간다.
	ant.direction = dir
	# 무장→지연 건설 (구 BuilderSkill 패턴). 지정 방향 낭떠러지가 아니면 즉시 건설하지 않고 무장만 + 방향 저장.
	# Walker/Carrying.update가 매 frame try_build_armed_builder로 그 방향 낭떠러지 도달을 검사해 자동 건설.
	# 이미 그 방향 낭떠러지면 즉시 그 자리에서 건설(한 frame도 지체 없음). cliff_ahead()는 위에서 set한 direction 사용.
	if ant.cliff_ahead():
		ant.state_machine.change_state(WorkerState.new("builder"))
	else:
		ant.builder_armed = true
		ant.builder_armed_dir = dir
