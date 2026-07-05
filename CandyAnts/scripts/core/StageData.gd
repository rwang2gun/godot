class_name StageData extends Resource

@export var id: int = 0
@export var display_name: String = ""
@export var scene: PackedScene = null
@export var layout: Resource = null
@export var total_ants: int = 10
@export var candy_hp: int = 10
@export var time_limit_seconds: float = 120.0
@export var available_skills: Array[String] = []
@export var skill_inventory: Dictionary = {}
# auto-solver Phase 2 (D11) — 선택적 도구별 용도 비고(스킬 id → 설명 문자열). 솔버 탐색 시드 힌트 +
# 관리자/설계 문서용. **비구속**: 비어 있어도(대부분 스테이지) 게임·솔버 동작 불변 — 솔버는 비고 없는
# (생성된) 레벨도 풀어야 하므로 정답을 여기에 의존하지 않는다. 게임 런타임은 이 필드를 읽지 않는다.
@export var skill_notes: Dictionary = {}
@export var release_rate_initial: int = 50
@export var release_rate_min: int = 1
