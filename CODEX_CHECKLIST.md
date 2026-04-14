# Codex 검증 체크리스트

검증 유형에 따라 참고 섹션을 골라 프롬프트에 포함할 것.
범용 항목(A)은 모든 검증에 항상 포함, B/C/D/E는 작업 성격에 맞게 추가.

| 검증 유형 | 적용 섹션 |
|---|---|
| 새 스크립트/클래스 추가 (단순 구조 작업) | A |
| 전투/공격 로직 이식 | A + B |
| 캐릭터/포즈/State 이식 | A + C |
| 토대/구조 코드(스켈레톤·PoseSystem 등) | A + D |
| 입력/상태머신 흐름 변경 | A + E |

---

## A. 범용 (모든 검증) — 코드 위생

### A.1 이름 충돌 (Name Collision)
- 새 `class_name`이 기존 스크립트의 `class_name`, `enum`, 변수명과 충돌하지 않는지 확인
- Godot `class_name`은 전역 스코프 — 프로젝트 전체를 검색해야 함

### A.2 타입 호환성 (Type Compatibility)
- 새 클래스/enum이 기존 타입 힌트(`var x: Type`)와 충돌하지 않는지 확인
- `:=` 타입 추론이 삼항식 등에서 실패할 수 있음 → 명시적 타입 선언 필요
- untyped `Array`/`Dictionary`에서 값을 꺼낼 때 `:=`는 타입 추론 불가 → `var x: Type = arr[i]` 형식으로 명시적 타입 선언 필수
- untyped 변수(예: `var parent`)의 메서드 반환값도 `:=`로 추론 불가 → `var result: Type = parent.method()` 형식 필수
- Autoload 싱글톤의 프로퍼티 접근도 Variant 반환 가능 → `var x: Type = Singleton.prop` 형식 필수
- `Dictionary.get()`은 항상 Variant 반환 → `:=` 사용 금지
- `$NodePath`는 Variant 반환 → `var node: NodeType = $Path` 형식 필수

### A.3 경로 참조 무결성 (Path Integrity)
- `.tscn`의 `ext_resource` 경로가 모두 업데이트되었는지 확인
- `preload()` / `load()` 호출의 경로가 유효한지 확인

### A.4 Godot 예약어 충돌
- 내장 클래스명(Node, Resource, Signal 등)과 충돌하지 않는지 확인
- GDScript 키워드(class, signal, enum 등)와 충돌하지 않는지 확인
- 매개변수명에 `visible`, `position`, `rotation` 등 노드 프로퍼티명 사용 시 그림자 변수 발생 — 접미사로 회피 (`visible_now`)

---

## B. 전투/공격 로직 이식 시

### B.1 시간 효과 (Time Effects) ⚠️ 프리즈 위험
- `Engine.time_scale`을 변경하는 코드가 있으면 **반드시 복구 경로가 보장되는지 검증**할 것
- `Engine.time_scale = 0.0` 설정 시 `_process(delta)`의 delta도 0이 됨 → 타이머 복구 불가로 영구 프리즈
- hitstop/slow-mo 타이머는 반드시 실시간 delta(`1.0 / Engine.get_frames_per_second()`) 사용
- 검증 체크: time_scale을 0으로 만드는 코드 → 0에서 복귀시키는 코드가 delta=0 상황에서도 동작하는지 확인

### B.2 프리된 인스턴스 참조 (Freed Instance Access)
- `queue_free()` 대상 노드를 배열/딕셔너리에 보관 중이라면 **타입 있는 변수에 할당하기 전에** `is_instance_valid()` 검증 필수
- 패턴: `var g: Node = arr[i]`처럼 타입이 있는 변수에 프리된 인스턴스를 할당하면 `"Trying to assign invalid previously freed instance."` 에러 발생
- 올바른 패턴: `var g = arr[i]` (untyped) → `if not is_instance_valid(g): continue` → 이후 사용
- 배열에서 프리된 엔트리는 주기적으로 정리 (`_cleanup_freed_goblins` 같은 헬퍼) 또는 `tree_exited` 시그널로 제거

### B.3 HTML 원본 동작 일치성
- HTML에서 직접 대입(`velocity.copy(...).multiplyScalar(v)`)하는 값을 GDScript에서 lerp로 바꾸지 말 것 — 시각적 표현이 달라짐
- 반경/각도 판정에 적의 `radius`가 포함되는지 확인 (HTML: `dist < 5.0 + d.radius`)
- 데미지/넉다운/AOE 타이밍(blastAt 등) 값을 그대로 옮겼는지

### B.4 State 종료 정리
- `state_machine.change_state()`는 항상 `exit()`을 호출함을 신뢰할 수 있음 (`StateMachine.gd`)
- 단, 공격 상태에서 켠 시각 효과(blast ring, 충격파)는 `exit()`에서 명시적으로 끄거나 자동 만료 보장 필수

---

## C. 캐릭터/포즈/State 이식 시

### C.1 좌표계 (-Z forward 변환)
- 캐릭터 facing 각도: 모델이 -Z forward이므로 `atan2(-x, -z)` 사용 필수 (`atan2(x, z)`는 +Z forward 기준 → 뒤통수를 보게 됨)
- HTML 포즈 데이터 변환 규칙(`GODOT_Battle_Prototype.md` 라인 38~58):
  - X축 회전(rx, sx, ex, wx, knee) → **부호 반전**
  - Z축 회전(rz, sz) → **부호 반전**
  - Y축 회전(ry, sy, wy) → **그대로**
  - 위치 X/Z 오프셋 → **부호 반전**, Y → 그대로
- tscn 시작 위치: CharacterBase가 스켈레톤을 `Root.position.y = LEG_H`로 자체 배치하므로, CharacterBody3D의 transform.y를 추가로 올리면 공중에 뜸
- HTML 슬러프(`quaternion.slerp(q, 18*dt)`)와 GDScript `lerp_angle(..., 18*dt)`은 Yaw-only 회전에서만 동등 — 다축 회전은 별도 검증 필요

### C.2 절차적 애니메이션 (Procedural Animation)
- `parts[]` Dictionary에서 꺼낸 Node3D를 로컬 변수에 담을 때 `:=` 금지 → `var joint: Node3D = parts["right_arm"]["shoulder"]` 형식 필수
- `skip_pose_update = true` 설정 시 반드시 `exit()`에서 `false`로 복구하는지 확인
- 절차적 애니메이션과 PoseSystem.apply_pose가 같은 프레임에 동시 실행되지 않는지 확인 (skip 플래그로 분리)

### C.3 포즈 매핑(pose_map)
- 캐릭터별 `pose_map` Dictionary가 모든 State에서 호출되는 키를 커버하는지
- 누락 시 `set_pose()`가 조용히 폴백 — 시각적으로 잘못된 포즈가 나올 수 있음

---

## D. 토대/구조 코드 검증 시 (스켈레톤·PoseSystem 등)

### D.1 회전 누적 순서
- Three.js 기본 Euler order는 `XYZ`. Godot Node3D 기본도 `EULER_ORDER_YXZ` — `_make_joint`에서 `rotation_order = EULER_ORDER_XYZ`로 명시 설정해야 동작 일치
- 부모-자식 회전 누적 순서가 HTML 원본과 동일한지 (Pivot → Root → Waist → Chest → Neck/Arms/Legs)
- 같은 조인트에 절차적 회전 + PoseSystem 회전이 중첩되지 않도록 분리 필요

### D.2 PoseSystem lerp 수학적 동등성
- HTML `applyPose`의 lerp factor(`Math.min(1, speed * dt)`)와 GDScript 구현이 동등한지
- 회전 lerp가 angle wrap(`-π/π` 경계)을 처리하는지 — 단순 `lerpf`는 큰 각도 변화에서 잘못된 경로로 보간 가능 → `lerp_angle` 사용 필수
- 빈 키(예: "rArm" 없음)에 대한 폴백이 안전한지

### D.3 HTML buildGeometry 1:1 대응
- 모든 박스 크기/오프셋이 HTML 원본 값과 일치하는지 (좌표 변환 후 X/Z 부호 반전 적용)
- 머티리얼 색상이 HTML과 일치하는지 (캐릭터별 override)
- 자식 노드 추가 위치가 HTML 원본의 mesh.add 순서/parent와 일치하는지

### D.4 Skeleton harness 확장 안전성
- 서브클래스가 `_build_wand`/`_build_sword` 등으로 wrist에 자식을 추가할 때 — PoseSystem lerp가 wrist 회전을 변경할 때 무기가 함께 회전되는지 (의도)
- 추가된 자식이 PoseSystem lerp 대상에서 제외되는지 (parts에 등록되지 않으면 자동 제외)
- `parts` 등록 키 충돌 — 같은 키 두 번 쓰면 마지막이 덮어씀 (silent)

### D.5 회귀 영향 범위
- 토대 코드 변경은 모든 캐릭터/State에 영향 — 변경 전후 동작 차이를 캐릭터별로 점검
- HTML 원본 영상/스크린샷과 자세 비교(가능하면)

---

## E. 입력/상태머신 흐름 변경 시

### E.1 트리거 라이프사이클
- InputManager 트리거(`attack_triggered` 등)는 `_process` 시작 시 자동 리셋 → `_physics_process`까지 1프레임만 유지
- Press 기반 vs Release 기반 분리 (홀드/탭 분기 시 release 시점에서만 트리거 발사)
- 같은 입력에 여러 액션 매핑 시 `_action_has_event` 중복 체크가 InputEvent 타입별로 비교하는지 확인

### E.2 상태 전환 우선순위
- 같은 State.update에서 여러 전환 조건이 있을 때 우선순위 명확한지
- 캔슬 가능 윈도우(공격 → 대시 등)가 의도한 시점에 열리는지

### E.3 InputMap 액션 등록
- `_setup_input_map`에서 액션이 이미 존재하는 경우 중복 등록 회피
- 같은 액션에 여러 이벤트(Shift + RMB + .) 추가 시 각각 따로 체크
