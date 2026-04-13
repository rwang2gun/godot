# Codex 검증 체크리스트

Codex 검증 프롬프트에 아래 항목을 반드시 포함할 것.

## 1. 이름 충돌 (Name Collision)
- 새 `class_name`이 기존 스크립트의 `class_name`, `enum`, 변수명과 충돌하지 않는지 확인
- Godot `class_name`은 전역 스코프 — 프로젝트 전체를 검색해야 함

## 2. 타입 호환성 (Type Compatibility)
- 새 클래스/enum이 기존 타입 힌트(`var x: Type`)와 충돌하지 않는지 확인
- `:=` 타입 추론이 삼항식 등에서 실패할 수 있음 → 명시적 타입 선언 필요

## 3. 경로 참조 무결성 (Path Integrity)
- `.tscn`의 `ext_resource` 경로가 모두 업데이트되었는지 확인
- `preload()` / `load()` 호출의 경로가 유효한지 확인

## 4. Godot 예약어 충돌
- 내장 클래스명(Node, Resource, Signal 등)과 충돌하지 않는지 확인
- GDScript 키워드(class, signal, enum 등)와 충돌하지 않는지 확인
