class_name ChargeAttackState
extends BaseState

## 2-phase charge attack — HTML executeChargeAttack 이식
##  charging — LMB 홀드 중 windup (정지 + 가장 가까운 적 조준)
##  attack   — 릴리스 후 lockedTarget로 빠르게 회전 + 6 m/s 전진 +
##             t=0.12s 시점 5m AOE 블래스트("폭발참")

var phase: String = "charging"
var timer: float = 0.0

const DURATION  := 0.7
const BLAST_AT  := 0.12
const BLAST_RADIUS := 5.0
const ATTACK_SPEED := 6.0
const MIN_DIST_FOR_RUSH := 1.5
const DEFAULT_ENEMY_RADIUS := 0.4   # goblin이 radius 프로퍼티 없을 때 폴백

var locked_target: Node3D = null
var blast_done: bool = false


func enter() -> void:
	phase = "charging"
	timer = 0.0
	blast_done = false
	locked_target = null
	parent.has_hit = false
	# Windup 포즈 (느린 lerp — 준비 자세)
	parent.set_pose("charge_windup", 14.0)
	# 가장 가까운 적 방향 즉시 스냅
	_face_nearest_enemy(true, 0.0)


func update(delta: float) -> void:
	timer += delta

	# ── Phase 1: Windup (홀드 중) ──
	if phase == "charging":
		# 정지 (HTML: this.velocity.set(0,0,0))
		parent.velocity.x = 0.0
		parent.velocity.z = 0.0

		# 홀드 중 부드럽게 타겟 추종 (HTML slerp 10*dt)
		_face_nearest_enemy(false, delta)

		# 대시/스킬 캔슬
		if InputManager.shift_triggered:
			parent.start_dash()
			return
		if InputManager.skill_triggered and parent.skill_cooldown <= 0:
			parent.state_machine.change_state("skill")
			return

		# 릴리스 → 공격 페이즈 진입
		if InputManager.charge_attack_released:
			_on_charge_release()
		return

	# ── Phase 2: Attack (돌진 + 블래스트) ──
	_execute_charge_attack(delta)

	if timer >= DURATION:
		parent.combo_step = 0
		parent.combo_cooldown = 0.3
		parent.state_machine.change_state("idle")


func exit() -> void:
	# 블래스트 링 정리는 GameManager가 알아서 처리
	parent.show_blast_radius(false)


# ─────────────────────────────────────────────────────────────────
#  HTML onChargeRelease 이식 — 타겟 잠금 + 페이즈 전환
# ─────────────────────────────────────────────────────────────────
func _on_charge_release() -> void:
	phase = "attack"
	timer = 0.0
	blast_done = false
	parent.has_hit = false
	locked_target = parent.get_nearest_enemy()
	parent.set_pose("charge_slam", 35.0)
	parent.show_blast_radius(true, BLAST_RADIUS)


# ─────────────────────────────────────────────────────────────────
#  HTML executeChargeAttack 이식
# ─────────────────────────────────────────────────────────────────
func _execute_charge_attack(delta: float) -> void:
	# 잠긴 타겟 방향으로 고속 회전 + 직접 속도 세팅
	if locked_target != null and is_instance_valid(locked_target) and not locked_target.get("is_dead"):
		var to_t: Vector3 = locked_target.global_position - parent.global_position
		to_t.y = 0
		var dist: float = to_t.length()
		if dist > 0.001:
			var ang: float = atan2(-to_t.x, -to_t.z)
			# slerp 18*dt 대신 lerp_angle (Godot)
			parent.target_facing = ang
			parent.facing_angle  = lerp_angle(parent.facing_angle, ang, minf(1.0, 18.0 * delta))
			parent.pivot.rotation.y = parent.facing_angle

			if dist > MIN_DIST_FOR_RUSH:
				var dir: Vector3 = to_t / dist
				parent.velocity.x = dir.x * ATTACK_SPEED
				parent.velocity.z = dir.z * ATTACK_SPEED
			else:
				parent.velocity.x = 0.0
				parent.velocity.z = 0.0
	else:
		parent.velocity.x = 0.0
		parent.velocity.z = 0.0

	# 슬램 포즈 유지 (HTML: applyPose POSES.fs_charge_slam, 35)
	parent.set_pose("charge_slam", 35.0)

	# t=0.12s 시점: AOE 블래스트
	if not blast_done and timer >= BLAST_AT:
		blast_done = true
		_trigger_blast()


func _trigger_blast() -> void:
	var pos: Vector3 = parent.global_position
	# VFX (있으면)
	if parent.game_manager and parent.game_manager.has_method("spawn_shockwave_ring"):
		parent.game_manager.spawn_shockwave_ring(pos, 3.0, Color(1.0, 0.53, 0.0))
		parent.game_manager.spawn_shockwave_ring(pos, BLAST_RADIUS, Color(1.0, 0.27, 0.0))
	if parent.game_manager and parent.game_manager.has_method("trigger_hitstop"):
		parent.game_manager.trigger_hitstop(0.13)

	# 5m 반경 모든 적 피격 (HTML: 5.0 + d.radius — 적 반경 포함 판정)
	for g in parent.goblins:
		if not is_instance_valid(g) or g.get("is_dead"):
			continue
		var gn: Node3D = g
		var to_d: Vector3 = gn.global_position - pos
		to_d.y = 0
		var enemy_r_var: Variant = gn.get("radius")
		var enemy_r: float = enemy_r_var if enemy_r_var != null else DEFAULT_ENEMY_RADIUS
		if to_d.length() > BLAST_RADIUS + enemy_r:
			continue
		var out_dir: Vector3 = to_d.normalized() if to_d.length() > 0.001 else Vector3(0, 0, 1)
		if gn.has_method("take_hit"):
			gn.take_hit(out_dir, true)   # knockdown = true
		if parent.game_manager:
			parent.game_manager.add_score(25)


func _face_nearest_enemy(snap: bool, delta: float) -> void:
	var nearest: Node3D = parent.get_nearest_enemy()
	if nearest == null:
		return
	var to_t: Vector3 = nearest.global_position - parent.global_position
	to_t.y = 0
	if to_t.length() <= 0.1:
		return
	var ang: float = atan2(-to_t.x, -to_t.z)
	parent.target_facing = ang
	if snap:
		parent.facing_angle = ang
		parent.pivot.rotation.y = ang
	else:
		# windup 동안엔 부드러운 추종 (HTML slerp 10*dt)
		parent.facing_angle = lerp_angle(parent.facing_angle, ang, minf(1.0, 10.0 * delta))
		parent.pivot.rotation.y = parent.facing_angle
