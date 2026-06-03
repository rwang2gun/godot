class_name SettlementMarker extends Area2D

# Phase 15 — 분배자 정착 + 능력 전이 트리거 Area2D.
# v2 F2: await get_tree().physics_frame로 동일 frame race 결정성 보장 (Candy.body_entered가 먼저
#   처리되어 has_candy=true 갱신됐을 가능성을 한 frame 지연 후 재검사로 흡수).
# v2 F3: TRANSFER_WHITELIST는 SettledState.TRANSFER_WHITELIST를 직접 참조 (single SoT).
#   자체 @export 미보유 — scene-level override는 phase 16+에서 별도 결정으로 재도입 가능.

var _distributor: Ant = null

func _ready() -> void:
	# monitoring=true 강제 제거 (Round 5 F-impl-R5-1) — scene .tscn에 monitoring=true가 default이므로
	# 코드측 set 불필요. driver test가 pre-add monitoring=false setup 가능하도록 _ready에서 덮어쓰지 않음.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func bind_distributor(a: Ant) -> void:
	# in-place 정착(낙하산 분배자, 2026-06-03)용 — 분배자를 직접 주입해 settle 트리거 분기를 건너뛰고
	# 곧장 transfer 모드로. 마커가 분배자 위치에 동적 생성되므로, 이미 area에 겹쳐 있는 개미에겐
	# 한 physics frame 뒤 즉시 전이(body_entered 재발화 없이도 결정성 보장).
	_distributor = a
	await get_tree().physics_frame
	if is_instance_valid(self) and is_instance_valid(a):
		_drain_pending_receivers()

func _on_body_entered(body: Node2D) -> void:
	var ant: Ant = body as Ant
	if ant == null or not is_instance_valid(ant):
		return
	# v2 F2: 한 frame 지연 후 has_candy 재검사. Candy.body_entered가 같은 frame에 먼저
	# 처리되어 has_candy=true 갱신됐다면 정착 무시.
	await get_tree().physics_frame
	if not is_instance_valid(ant):
		return
	if ant.state_machine == null:
		return
	var s: AntState = ant.state_machine.current_state
	# Round 4 F-impl-R4-1 대응 — D8(운반 > 정착)은 분배자 본인 정착 트리거에만 적용.
	# carrying receiver는 transfer 허용. has_candy 검사 위치를 분배자 분기 안으로 이동.
	# 분배자 본인의 정착 트리거 (첫 도달자).
	if _distributor == null and ant.has_trait(&"distributor"):
		# D8: 분배자 본인이 has_candy=true면 정착 무시 (in_transit 데드락 회피).
		if ant.has_candy:
			return
		if not (s is WalkerState):
			return
		_distributor = ant
		ant.state_machine.change_state(SettledState.new())
		# Round 3 F-impl-R3-1 MEDIUM 대응 — 정착 시점에 이미 marker 안에 들어와 있는
		# follower들은 body_entered가 다시 발화하지 않으므로 transfer 영구 누락 위험.
		# get_overlapping_bodies()로 현재 overlap 중인 ant들에게 즉시 transfer.
		_drain_pending_receivers()
		return
	# 분배자 정착 후 후속 ant 진입 → 능력 전이.
	if _distributor != null and is_instance_valid(_distributor):
		if ant == _distributor:
			return
		# Walker 또는 Carrying만 — Faller/Worker/Settled/Saved/Dead 거부.
		if not (s is WalkerState or s is CarryingState):
			return
		_transfer_traits(ant)

func _drain_pending_receivers() -> void:
	# 분배자 정착 직후 호출. marker collision area에 이미 들어와 있는 walker/carrying ant들에게
	# 즉시 trait 전이 (body_entered 재발화 없이도 transfer 결정성 보장).
	# Round 4 F-impl-R4-1 대응 — has_candy 검사 제거. carrying receiver도 transfer 대상.
	# (D8 has_candy 검사는 분배자 본인 정착 트리거에만 적용, receiver와 무관.)
	if _distributor == null or not is_instance_valid(_distributor):
		return
	for body in get_overlapping_bodies():
		var ant: Ant = body as Ant
		if ant == null or not is_instance_valid(ant):
			continue
		if ant == _distributor:
			continue
		if ant.state_machine == null:
			continue
		var s: AntState = ant.state_machine.current_state
		if not (s is WalkerState or s is CarryingState):
			continue
		_transfer_traits(ant)

func _transfer_traits(receiver: Ant) -> void:
	# v2 F3: single SoT — SettledState.TRANSFER_WHITELIST 직접 참조.
	for t in SettledState.TRANSFER_WHITELIST:
		if _distributor.has_trait(t):
			receiver.set_trait(t)   # D6/D9: idempotent no-op if already set
