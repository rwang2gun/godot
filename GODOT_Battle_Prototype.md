# FreeFlow → Godot 4.6 이관 계획

## 개요

현재 프로토타입: `FreeFlow_Test_split.html` (Three.js 단일 파일, ~5700줄)  
이관 대상: Godot 4.6 (GDScript)

---

## 좌표계

⚠️ **Three.js 원본은 +Z 전방**, Godot은 -Z 전방 — 좌표 변환 필요!

| 항목 | Three.js (원본) | Godot 4 | 비고 |
|------|----------------|---------|------|
| 전방 | **`+Z`** | **`-Z`** | 180° 반대 |
| 오른쪽 | `-X` | `+X` | 좌우 반전 |
| 위 | `+Y` | `+Y` | 동일 |
| 회전 | 오른손 법칙 | 오른손 법칙 | 동일 |
| Euler Order (관절) | `XYZ` (기본) | `YXZ` (기본) | 관절에 XYZ 지정 필요 |
| 캐릭터 전방 벡터 | `Vector3(0,0,1)` | `Vector3(0,0,-1)` | |

> 원본 HTML에서 확인: `const forward = new THREE.Vector3(0, 0, 1).applyQuaternion(this.mesh.quaternion)`  
> nose 마커도 `z = +headD/2` 에 배치 → 얼굴이 +Z를 향함.

### 좌표 변환 규칙 (R_Y(π) 켤레변환)

+Z → -Z 전방 전환 시, Y축 180° 회전의 켤레변환을 적용:

```
R_Y(π) · R_x(θ) · R_Y(-π) = R_x(-θ)   → X축 회전: 부호 반전
R_Y(π) · R_y(θ) · R_Y(-π) = R_y(θ)    → Y축 회전: 유지
R_Y(π) · R_z(θ) · R_Y(-π) = R_z(-θ)   → Z축 회전: 부호 반전
```

**요약: X축·Z축 회전 → 부호 반전, Y축 회전 → 그대로**

### 포즈 데이터 변환표

| 필드 | 대응 축 | 변환 |
|------|---------|------|
| `root.y` | position.y | 유지 |
| `root.rx`, `waist.rx`, `chest.rx` | rotation.x | **부호 반전** |
| `root.ry`, `waist.ry`, `chest.ry` | rotation.y | 유지 |
| `rArm/lArm.sx` | shoulder.rotation.x | **부호 반전** |
| `rArm/lArm.sy` | shoulder.rotation.y | 유지 |
| `rArm/lArm.sz` | shoulder.rotation.z | **부호 반전** |
| `rArm/lArm.ex` | elbow.rotation.x | **부호 반전** |
| `rArm/lArm.wx` | wrist.rotation.x | **부호 반전** |
| `rArm/lArm.wy` | wrist.rotation.y | 유지 |
| `rHip/lHip.rx` | hip.rotation.x | **부호 반전** |
| `rHip/lHip.ry` | hip.rotation.y | 유지 |
| `rHip/lHip.rz` | hip.rotation.z | **부호 반전** |
| `rHip/lHip.knee` | knee.rotation.x | **부호 반전** |

### 스켈레톤 위치 변환

좌우도 반전되므로 X 오프셋 부호 반전, Z 오프셋 부호 반전:

| 부위 | Three.js | Godot |
|------|----------|-------|
| 오른팔 shoulder.x | `-0.23` | `+0.23` |
| 왼팔 shoulder.x | `+0.23` | `-0.23` |
| 오른다리 hip.x | `-0.11` | `+0.11` |
| 왼다리 hip.x | `+0.11` | `-0.11` |
| nose.z | `+headD/2` | `-headD/2` |
| sword.z | `+0.6` | `-0.6` |

### Euler Order 설정

Three.js 캐릭터 관절은 XYZ order. Godot 기본은 YXZ이므로 **관절 Node3D에 명시적 설정 필요**:

```gdscript
# 각 관절 Node3D 생성 시
joint.rotation_order = EULER_ORDER_XYZ
```

> Goblin만 `mesh.rotation.order = 'YXZ'` 사용 — Goblin의 mesh(최상위)는 Godot 기본 YXZ와 일치.

---

## 프로젝트 폴더 구조

```
freeflow_godot/
├── project.godot
├── autoloads/
│   ├── GameManager.gd        # Game 클래스 (싱글톤) — 씬·루프·AI·스코어
│   └── InputManager.gd       # 입력 처리 싱글톤
├── scenes/
│   ├── Main.tscn             # 루트 씬 (카메라, 조명, 적 배치)
│   ├── characters/
│   │   ├── CharacterFS.tscn
│   │   ├── CharacterEF.tscn
│   │   └── CharacterWM.tscn
│   ├── enemies/
│   │   ├── Goblin.tscn
│   │   └── GoblinSpearman.tscn
│   └── vfx/
│       ├── ShockwaveRing.tscn
│       ├── FloatingIndicator.tscn
│       ├── FireBlade.tscn
│       └── MagicBolt.tscn
├── scripts/
│   ├── core/
│   │   ├── StateMachine.gd
│   │   ├── State.gd
│   │   └── PoseSystem.gd
│   ├── characters/
│   │   ├── CharacterBase.gd  # CharacterFS 대응
│   │   ├── CharacterEF.gd
│   │   └── CharacterWM.gd
│   ├── states/
│   │   ├── IdleState.gd
│   │   ├── WalkState.gd
│   │   ├── DashState.gd
│   │   ├── AttackState.gd
│   │   ├── HurtState.gd
│   │   ├── SkillState.gd
│   │   ├── UltimateState.gd
│   │   ├── ChargeAttackState.gd
│   │   ├── SwapOutState.gd
│   │   └── SwapInState.gd
│   ├── enemies/
│   │   ├── Goblin.gd
│   │   └── GoblinSpearman.gd
│   └── camera/
│       └── CameraRig.gd
├── data/
│   └── poses.gd              # POSES 딕셔너리 (const)
└── ui/
    ├── HUD.tscn
    └── HUD.gd
```

---

## 시스템별 이관 방법

### 1. 스켈레톤 (buildGeometry)

**현재**: `THREE.Group` + `BoxGeometry` 계층 구조  
**Godot**: `Node3D` 계층 + `MeshInstance3D(BoxMesh)` — 구조 이식 + 좌표 변환 적용

> `Skeleton3D` / `BoneAttachment3D`는 사용하지 않음.  
> 포즈 시스템이 `Node3D.rotation`을 직접 조작하므로 계층 Node3D가 더 적합.

⚠️ **좌표 변환 적용**: +Z forward → -Z forward 전환에 따라 X 오프셋 부호 반전.  
⚠️ **Euler Order**: 모든 관절 Node3D에 `rotation_order = EULER_ORDER_XYZ` 설정 필요 (Godot 기본 YXZ와 다름).

```
CharacterBase (CharacterBody3D)
  └─ Root (Node3D, EULER_ORDER_XYZ) ← parts["root"],  position.y = legH
       ├─ PelvisMesh (MeshInstance3D)
       ├─ Waist (Node3D, EULER_ORDER_XYZ) ← parts["waist"]
       │    ├─ WaistMesh
       │    └─ Chest (Node3D, EULER_ORDER_XYZ) ← parts["chest"]
       │         ├─ ChestMesh
       │         ├─ Neck (Node3D, EULER_ORDER_XYZ)
       │         │    └─ Head (MeshInstance3D)
       │         │         └─ Nose (position.z = -headD/2)  ← Z 반전!
       │         ├─ RightArm/
       │         │    ├─ Shoulder (Node3D, EULER_ORDER_XYZ, x=+0.23)  ← X 반전!
       │         │    ├─ Elbow   (Node3D, EULER_ORDER_XYZ)
       │         │    └─ Wrist   (Node3D, EULER_ORDER_XYZ)
       │         │         └─ Sword (position.z = -0.6)  ← Z 반전!
       │         └─ LeftArm/
       │              ├─ Shoulder (Node3D, EULER_ORDER_XYZ, x=-0.23)  ← X 반전!
       │              ├─ Elbow   (Node3D, EULER_ORDER_XYZ)
       │              └─ Wrist   (Node3D, EULER_ORDER_XYZ)
       ├─ RightLeg/
       │    ├─ Hip  (Node3D, EULER_ORDER_XYZ, x=+0.11)  ← X 반전!
       │    └─ Knee (Node3D, EULER_ORDER_XYZ)
       └─ LeftLeg/
            ├─ Hip  (Node3D, EULER_ORDER_XYZ, x=-0.11)  ← X 반전!
            └─ Knee (Node3D, EULER_ORDER_XYZ)
```

**위치 오프셋 변환 요약** (Three.js → Godot):

| 부위 | Three.js X | Godot X | Three.js Z | Godot Z |
|------|-----------|---------|-----------|---------|
| RightArm shoulder | -0.23 | **+0.23** | 0 | 0 |
| LeftArm shoulder | +0.23 | **-0.23** | 0 | 0 |
| RightLeg hip | -0.11 | **+0.11** | 0 | 0 |
| LeftLeg hip | +0.11 | **-0.11** | 0 | 0 |
| Nose | 0 | 0 | +headD/2 | **-headD/2** |
| Sword | 0 | 0 | +0.6 | **-0.6** |

---

### 2. 포즈 시스템

**현재**: JS `POSES` 딕셔너리 + `applyPose(pose, speed, dt)` + `lerpJoint()`  
**변환**: 좌표계 섹션의 변환 규칙에 따라 X축·Z축 회전 부호 반전 적용

> ⚠️ HTML의 POSES를 **그대로 복사하면 안 됨**. 아래 변환이 적용된 값을 사용할 것.

**변환 예시 — idle 포즈 (HTML 원본 → Godot 변환)**:

```
HTML 원본:
  root:  { y:0.8, rx:0,     ry:-0.37 }
  waist: { rx:-0.09, ry:0 }
  chest: { rx:0.06,  ry:0.22 }
  rArm:  { sx:0.13,  sy:-0.01, sz:-0.09, ex:-0.49, wx:-0.26, wy:0 }
  lArm:  { sx:0.3,   sy:-0.68, sz:0.32,  ex:-0.51 }
  rHip:  { rx:-0.22, ry:-0.14, rz:-0.18, knee:0.21 }
  lHip:  { rx:0.07,  ry:0.38,  rz:0.1,   knee:0.05 }

Godot 변환 (rx,rz,sx,sz,ex,wx,knee → 부호 반전 / ry,sy,wy → 유지):
  root:  { y:0.8, rx:0,     ry:-0.37 }      ← rx=0 반전해도 0
  waist: { rx:0.09,  ry:0 }                  ← rx 반전
  chest: { rx:-0.06, ry:0.22 }               ← rx 반전
  rArm:  { sx:-0.13, sy:-0.01, sz:0.09, ex:0.49, wx:0.26, wy:0 }
  lArm:  { sx:-0.3,  sy:-0.68, sz:-0.32, ex:0.51 }
  rHip:  { rx:0.22,  ry:-0.14, rz:0.18, knee:-0.21 }
  lHip:  { rx:-0.07, ry:0.38,  rz:-0.1, knee:-0.05 }
```

```gdscript
# data/poses.gd
# ⚠️ 모든 값은 HTML 원본에서 좌표 변환(X축·Z축 부호 반전) 적용 완료된 상태
const POSES: Dictionary = {
    "idle": {
        "root":  {"y": 0.8, "rx": 0.0, "ry": -0.37},
        "waist": {"rx": 0.09, "ry": 0.0},
        "chest": {"rx": -0.06, "ry": 0.22},
        "rArm":  {"sx": -0.13, "sy": -0.01, "sz": 0.09, "ex": 0.49, "wx": 0.26, "wy": 0.0},
        "lArm":  {"sx": -0.3, "sy": -0.68, "sz": -0.32, "ex": 0.51},
        "rHip":  {"rx": 0.22, "ry": -0.14, "rz": 0.18, "knee": -0.21},
        "lHip":  {"rx": -0.07, "ry": 0.38, "rz": -0.1, "knee": -0.05},
    },
    # ... 나머지 24개 포즈도 동일한 변환 규칙 적용
    # 변환 자동화: poses.gd 생성 시 스크립트로 일괄 변환 권장
}
```

```gdscript
# scripts/core/PoseSystem.gd
# apply_pose 코드 자체는 변환 전후 동일 — 데이터만 변환됨
func apply_pose(parts: Dictionary, pose: Dictionary, speed: float, delta: float) -> void:
    var a := minf(1.0, speed * delta)

    # root
    parts["root"].position.y = lerpf(parts["root"].position.y, pose["root"].get("y", 0.0), a)
    parts["root"].rotation.x = lerpf(parts["root"].rotation.x, pose["root"].get("rx", 0.0), a)
    parts["root"].rotation.y = lerpf(parts["root"].rotation.y, pose["root"].get("ry", 0.0), a)

    # waist / chest
    parts["waist"].rotation.x = lerpf(parts["waist"].rotation.x, pose["waist"].get("rx", 0.0), a)
    parts["waist"].rotation.y = lerpf(parts["waist"].rotation.y, pose["waist"].get("ry", 0.0), a)
    parts["chest"].rotation.x = lerpf(parts["chest"].rotation.x, pose["chest"].get("rx", 0.0), a)
    parts["chest"].rotation.y = lerpf(parts["chest"].rotation.y, pose["chest"].get("ry", 0.0), a)

    # 오른팔
    var ra := pose["rArm"]
    lerp_joint(parts["right_arm"]["shoulder"], Vector3(ra.get("sx",0), ra.get("sy",0), ra.get("sz",0)), a)
    parts["right_arm"]["elbow"].rotation.x = lerpf(parts["right_arm"]["elbow"].rotation.x, ra.get("ex", 0.0), a)
    lerp_joint(parts["right_arm"]["wrist"],   Vector3(ra.get("wx",0), ra.get("wy",0), 0.0), a)

    # 왼팔
    var la := pose["lArm"]
    lerp_joint(parts["left_arm"]["shoulder"], Vector3(la.get("sx",0), la.get("sy",0), la.get("sz",0)), a)
    parts["left_arm"]["elbow"].rotation.x = lerpf(parts["left_arm"]["elbow"].rotation.x, la.get("ex", 0.0), a)

    # 오른다리
    var rh := pose["rHip"]
    lerp_joint(parts["right_leg"]["hip"], Vector3(rh.get("rx",0), rh.get("ry",0), rh.get("rz",0)), a)
    parts["right_leg"]["knee"].rotation.x = lerpf(parts["right_leg"]["knee"].rotation.x, rh.get("knee", 0.05), a)

    # 왼다리
    var lh := pose["lHip"]
    lerp_joint(parts["left_leg"]["hip"], Vector3(lh.get("rx",0), lh.get("ry",0), lh.get("rz",0)), a)
    parts["left_leg"]["knee"].rotation.x = lerpf(parts["left_leg"]["knee"].rotation.x, lh.get("knee", 0.05), a)

func lerp_joint(joint: Node3D, target: Vector3, alpha: float) -> void:
    joint.rotation.x = lerpf(joint.rotation.x, target.x, alpha)
    joint.rotation.y = lerpf(joint.rotation.y, target.y, alpha)
    joint.rotation.z = lerpf(joint.rotation.z, target.z, alpha)
```

> `THREE.MathUtils.lerp(a, b, t)` → `lerpf(a, b, t)` 1:1 대응.  
> `speed` 기준: 6~12=느린 전환, 20~28=콤보, 30~40=빠른 복귀 (HTML과 동일)

---

### 3. 스테이트 머신

```gdscript
# scripts/core/StateMachine.gd
class_name StateMachine

var states: Dictionary = {}
var current_state: State = null

func add_state(name: String, state: State) -> void:
    states[name] = state

func change_state(name: String) -> void:
    if current_state:
        current_state.exit()
    current_state = states[name]
    current_state.enter()

func update(delta: float) -> void:
    if current_state:
        current_state.update(delta)
```

```gdscript
# scripts/core/State.gd
class_name State

var parent  # CharacterBase 참조

func _init(p) -> void:
    parent = p

func enter() -> void: pass
func update(_delta: float) -> void: pass
func exit() -> void: pass
```

State 서브클래스 10종 (HTML과 1:1 대응):

| GDScript 클래스 | name | 역할 |
|----------------|------|------|
| `HurtState` | "hurt" | 피격·넉백 (0.6s) |
| `IdleState` | "idle" | 대기, 트리거 감지 |
| `WalkState` | "walk" | 이동 |
| `DashState` | "dash" | 회피 (0.25s, 8m/s) |
| `AttackState` | "attack" | 콤보 |
| `SkillState` | "skill" | 스킬 (쿨다운 8s) |
| `UltimateState` | "ultimate" | 궁극기 (MP 풀) |
| `ChargeAttackState` | "chargeAttack" | 강공격 (홀드 0.3s) |
| `SwapOutState` | "swapOut" | 교체 퇴장 |
| `SwapInState` | "swapIn" | 교체 등장 |

---

### 4. 입력 시스템

**Project Settings → Input Map** 등록:

| 액션명 | 키 |
|--------|-----|
| `move_forward` | W |
| `move_back` | S |
| `move_left` | A |
| `move_right` | D |
| `dash` | Shift |
| `skill` | E |
| `ultimate` | Q |
| `attack` | 마우스 좌클릭 / `,` |
| `dash_kb` | `.` (키보드 대시) |
| `swap_next` | Tab |
| `swap_1` / `swap_2` / `swap_3` | 1 / 2 / 3 |
| `pause` | Escape |

```gdscript
# autoloads/InputManager.gd
extends Node

var attack_triggered    := false
var skill_triggered     := false
var ultimate_triggered  := false
var shift_triggered     := false
var charge_attack_released := false

var is_charging         := false
var attack_hold_time    := 0.0
const CHARGE_THRESHOLD  := 0.3

func _process(delta: float) -> void:
    if Input.is_action_pressed("attack"):
        attack_hold_time += delta
        is_charging = attack_hold_time >= CHARGE_THRESHOLD
    elif Input.is_action_just_released("attack"):
        if is_charging:
            charge_attack_released = true
        else:
            attack_triggered = true
        attack_hold_time = 0.0
        is_charging = false

    if Input.is_action_just_pressed("skill"):     skill_triggered    = true
    if Input.is_action_just_pressed("ultimate"):  ultimate_triggered = true
    if Input.is_action_just_pressed("dash"):      shift_triggered    = true

func reset_triggers() -> void:
    attack_triggered       = false
    skill_triggered        = false
    ultimate_triggered     = false
    shift_triggered        = false
    charge_attack_released = false
```

> 매 프레임 끝 `InputManager.reset_triggers()` 호출 — HTML의 트리거 리셋 패턴과 동일.

---

### 5. 카메라

**현재**: 구면좌표 (theta/phi) 기반 수동 궤도 카메라  
**Godot**: `SpringArm3D` 활용 (벽 충돌 자동 처리)

```
CameraRig (Node3D)          ← 수평 회전 (yaw)
  └─ Pitch (Node3D)         ← 수직 회전 (pitch)
       └─ SpringArm3D       ← 거리 5m, 충돌 회피
            └─ Camera3D
```

```gdscript
# scripts/camera/CameraRig.gd
var yaw   := PI        # theta 대응
var pitch := PI / 3.2  # phi 대응
var follow_speed := 6.0

func _process(delta: float) -> void:
    # 타겟 추적
    global_position = global_position.lerp(target.global_position + Vector3(0, 0.9, 0), follow_speed * delta)
    # 회전 적용
    rotation.y = yaw
    pitch_node.rotation.x = -pitch

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and is_rotating:
        yaw   -= event.relative.x * sensitivity
        pitch  = clampf(pitch - event.relative.y * sensitivity, 0.2, PI / 2.2)
```

---

### 6. 캐릭터 이동

**현재**: `calculateMovement()` → 카메라 기준 벡터 계산 후 수동 위치 이동  
**Godot**: `CharacterBody3D.move_and_slide()`

> ⚠️ HTML은 `forward = Vector3(0,0,1)` (+Z) 이지만, Godot은 `-basis.z` (-Z) 가 전방.  
> Yaw 공식은 `atan2(-dir.x, -dir.z)` — -Z 전방 기준 모델이 dir 방향을 향하도록 보정.  
> (HTML 원본 `atan2(dir.x, dir.z)` 그대로 옮기면 모델이 등을 보임 — 부호 반전 필수)

```gdscript
func calculate_movement() -> Vector3:
    var cam_forward := -camera.global_transform.basis.z  # Godot -Z = 전방
    cam_forward.y = 0.0
    cam_forward = cam_forward.normalized()
    var cam_left := Vector3.UP.cross(cam_forward).normalized()

    var input_dir := Vector3.ZERO
    if Input.is_action_pressed("move_forward"): input_dir += cam_forward
    if Input.is_action_pressed("move_back"):    input_dir -= cam_forward
    if Input.is_action_pressed("move_left"):    input_dir += cam_left
    if Input.is_action_pressed("move_right"):   input_dir -= cam_left

    if input_dir.length_squared() > 0.0001:
        input_dir = input_dir.normalized()
        # -Z 전방 보정: HTML의 atan2(x, z)에서 부호 반전
        var target_angle: float = atan2(-input_dir.x, -input_dir.z)
        mesh.rotation.y = target_angle   # 즉시 회전 (HTML과 동일)
    return input_dir
```

---

### 7. 슬로우모션

`Engine.time_scale` 대신 **delta 직접 조작** (캐릭터/적 독립 시간 흐름 유지):

```gdscript
# autoloads/GameManager.gd
var char_time_scale  := 1.0
var enemy_time_scale := 1.0
var char_slow_timer  := 0.0
var enemy_slow_timer := 0.0

func _physics_process(delta: float) -> void:
    # 슬로우모션 타이머
    if char_slow_timer > 0:
        char_slow_timer -= delta
        char_time_scale = 0.5
    else:
        char_time_scale = 1.0

    if enemy_slow_timer > 0:
        enemy_slow_timer -= delta
        enemy_time_scale = 0.1
    else:
        enemy_time_scale = 1.0

    var char_dt  := delta * char_time_scale
    var enemy_dt := delta * enemy_time_scale

    active_character.update(char_dt)
    for enemy in enemies:
        enemy.update(enemy_dt)

    InputManager.reset_triggers()
```

---

### 8. AI 시스템

```gdscript
# autoloads/GameManager.gd 내 AI 코디네이터
var attacker_idx         := -1
var ai_coordinator_timer := 0.0
const AI_COOLDOWN        := 0.5

func update_ai(delta: float) -> void:
    ai_coordinator_timer -= delta

    # 역할 재배정
    if ai_coordinator_timer <= 0:
        ai_coordinator_timer = AI_COOLDOWN
        _reassign_roles()

    for enemy in enemies:
        enemy.ai_active = (enemy.role == "attacker" and enemy == get_current_attacker())

func _reassign_roles() -> void:
    # 살아있는 적 중 1명만 attacker
    for i in enemies.size():
        enemies[i].role = "watcher"
    if enemies.size() > 0:
        attacker_idx = attacker_idx % enemies.size()
        enemies[attacker_idx].role = "attacker"
        attacker_idx += 1
```

---

### 9. VFX 대응표

| Three.js 클래스 | Godot 구현 방법 |
|----------------|----------------|
| `FloatingIndicator` | `Label3D` + `Tween` (위로 이동 → fade out) |
| `ExplosionRing` | `MeshInstance3D`(TorusMesh) + `Tween` 스케일 확장 |
| `FireBladeProjectile` | `Area3D` + `move_and_collide` + `GPUParticles3D` |
| `MagicBolt` | `Area3D` + 직선 이동 + `on_body_entered` 충돌 |
| `spawnShockwaveRing` | `ShockwaveRing.tscn` 인스턴스화 |
| `triggerImpact` (화면 흔들) | `Camera3D` + CameraShake 스크립트 / `ShakeCamera` 애드온 |

---

### 10. UI 대응표

| HTML ID | Godot 노드 타입 |
|---------|---------------|
| `stance-badge` | `Label` |
| `hp-badge` | `Label` |
| `score-badge` | `Label` |
| `skill-badge` | `Label` + `TextureProgressBar` |
| `mp-fill-FS/EF/WM` | `ProgressBar` × 3 |
| `ult-ready-badge` | `Label` (visible 토글) |
| `countdown-overlay` | `CanvasLayer` > `ColorRect` + `Label` |
| `gameover-overlay` | `CanvasLayer` > `Control` |
| `slowmo-overlay` | `CanvasLayer` > `ColorRect` (modulate.a 조절) |

---

## 단계별 이관 순서

### Phase 1 — 기반 구조
- [x] Godot 4.6 프로젝트 생성, 폴더 구조 세팅
- [x] `StateMachine.gd` / `State.gd` 구현 및 테스트
- [x] `data/poses.gd` — HTML POSES 딕셔너리 복사
- [x] `PoseSystem.gd` — `apply_pose` / `lerp_joint` 구현
- [x] `CharacterBase.gd` 스켈레톤 씬 수작업 배치, 포즈 적용 확인

### Phase 2 — 플레이어
- [x] `InputManager.gd` Autoload, InputMap 등록
- [x] `CameraRig.gd` (SpringArm3D)
- [x] State 10종 이식 (Idle → Walk → Dash → Hurt 순)
- [x] AttackState 콤보 로직, ChargeAttackState
- [x] `CharacterEF.gd`, `CharacterWM.gd` 오버라이드
- [x] 캐릭터 교체 SwapOut/SwapIn

### Phase 3 — 적·AI·전투 분기
- [ ] 거리 기반 공격 분기 (근거리 콤보 / 중거리 접근기 / 원거리 돌진기)
- [ ] `Goblin.gd` + 기본 AI
- [ ] `GoblinSpearman.gd` + MagicBolt
- [ ] GameManager AI 코디네이터

### Phase 4 — VFX·UI
- [ ] ShockwaveRing, FloatingIndicator, FireBlade
- [ ] HUD 전체, 카운트다운, 게임오버
- [ ] 슬로우모션 시스템

### Phase 5 — 완성도
- [ ] 스코어, 피격 횟수, MP 시스템
- [ ] 스킬·궁극기 VFX 연결
- [ ] 플레이테스트 및 수치 조정

---

## 캐릭터 스탯 참조

| 항목 | 값 |
|------|-----|
| `maxSpeed` | 6.0 m/s |
| `acceleration` | 14.0 |
| `damping` | 18.0 |
| `attackRange` | 2.0 m |
| `radius` (충돌) | 0.45 m |
| `aggroRadius` | 10.5 m |
| `dashDuration` | 0.25 s |
| `dashSpeed` | 8.0 m/s |
| `skillCooldown` | 8.0 s |
| `maxMp` | 50 |
| `maxHits` | 10 |
| `chargeThreshold` | 0.3 s |
| `hurtDuration` | 0.6 s |

---

## 원본 참조

HTML 원본에서 섹션별 위치 (`grep` 기준):

| 시스템 | grep 패턴 |
|--------|----------|
| 포즈 데이터 | `const POSES` |
| 포즈 적용 로직 | `applyPose(pose` |
| 캐릭터 기본 | `class CharacterFS` |
| 격투가 | `class CharacterEF` |
| 마법사 | `class CharacterWM` |
| 스테이트 머신 | `class StateMachine` |
| 카메라 | `class CameraRig` |
| 입력 | `class InputManager` |
| 게임 루프 | `class Game` |
| 적 | `class Goblin` |
