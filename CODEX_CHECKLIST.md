# Codex 검증 체크리스트

Codex 검증 프롬프트에 아래 항목을 반드시 포함할 것.

## 1. 이름 충돌 (Name Collision)
- 새 `class_name`이 기존 스크립트의 `class_name`, `enum`, 변수명과 충돌하지 않는지 확인
- Godot `class_name`은 전역 스코프 — 프로젝트 전체를 검색해야 함

## 2. 타입 호환성 (Type Compatibility)
- 새 클래스/enum이 기존 타입 힌트(`var x: Type`)와 충돌하지 않는지 확인
- `:=` 타입 추론이 삼항식 등에서 실패할 수 있음 → 명시적 타입 선언 필요
- untyped `Array`/`Dictionary`에서 값을 꺼낼 때 `:=`는 타입 추론 불가 → `var x: Type = arr[i]` 형식으로 명시적 타입 선언 필수
- untyped 변수(예: `var parent`)의 메서드 반환값도 `:=`로 추론 불가 → `var result: Type = parent.method()` 형식 필수
- Autoload 싱글톤의 프로퍼티 접근도 Variant 반환 가능 → `var x: Type = Singleton.prop` 형식 필수
- `Dictionary.get()`은 항상 Variant 반환 → `:=` 사용 금지
- `$NodePath`는 Variant 반환 → `var node: NodeType = $Path` 형식 필수

## 3. 경로 참조 무결성 (Path Integrity)
- `.tscn`의 `ext_resource` 경로가 모두 업데이트되었는지 확인
- `preload()` / `load()` 호출의 경로가 유효한지 확인

## 4. 시간 효과 (Time Effects) ⚠️ 프리즈 위험
- `Engine.time_scale`을 변경하는 코드가 있으면 **반드시 복구 경로가 보장되는지 검증**할 것
- `Engine.time_scale = 0.0` 설정 시 `_process(delta)`의 delta도 0이 됨 → 타이머 복구 불가로 영구 프리즈
- hitstop/slow-mo 타이머는 반드시 실시간 delta(`1.0 / Engine.get_frames_per_second()`) 사용
- 검증 체크: time_scale을 0으로 만드는 코드 → 0에서 복귀시키는 코드가 delta=0 상황에서도 동작하는지 확인

## 5. 좌표계 (Coordinate System)
- 캐릭터 facing 각도: 모델이 -Z forward이므로 `atan2(-x, -z)` 사용 필수 (`atan2(x, z)`는 +Z forward 기준 → 뒤통수를 보게 됨)
- tscn 시작 위치: CharacterBase가 스켈레톤을 `Root.position.y = LEG_H`로 자체 배치하므로, CharacterBody3D의 transform.y를 추가로 올리면 공중에 뜸

## 5. Godot 예약어 충돌
- 내장 클래스명(Node, Resource, Signal 등)과 충돌하지 않는지 확인
- GDScript 키워드(class, signal, enum 등)와 충돌하지 않는지 확인
