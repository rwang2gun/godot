class_name Glow
extends RefCounted

# 외곽선 셰이더 글로우 헬퍼 (STAGE_GUIDE_PLAN §0.8.3-2, 결정 2026-06-07).
# 노드(개미 스프라이트·타일 rect)에 outline ShaderMaterial을 붙였다 떼고, 펄스 알파 tween을 돌린다.
# modulate-only가 아니라 외곽선 셰이더 기반 — 라이트 유저 가독성 우선(형태 경계가 또렷).
# 색 토큰은 Tokens 팔레트 사용.

const _OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")

# 노드에 부착된 글로우 머티리얼을 추적하는 meta 키 (중복 부착 방지 + clear 식별).
const META_KEY := "_glow_material"
# 글로우 부착 직전의 node.material 백업 (clear 시 복원 — 외부 머티리얼 보존).
const META_PRIOR := "_glow_prior_material"

# 적격(can_apply) 강조색 — Tokens 팔레트. 부적격 대상은 글로우 미부착(§0.8.3-1).
const ELIGIBLE_COLOR: Color = Tokens.LEMON_500

# 노드에 outline 머티리얼을 부착(있으면 uniform 갱신만). pulse_alpha=1.0 정적.
# 첫 부착 시 기존 material을 백업해 clear가 원복할 수 있게 한다.
static func apply(node: CanvasItem, color: Color = ELIGIBLE_COLOR, width: float = 2.0) -> void:
	if node == null:
		return
	var mat: ShaderMaterial = node.get_meta(META_KEY) if node.has_meta(META_KEY) else null
	if mat == null:
		node.set_meta(META_PRIOR, node.material)
		mat = ShaderMaterial.new()
		mat.shader = _OUTLINE_SHADER
		node.material = mat
		node.set_meta(META_KEY, mat)
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("outline_width", width)
	mat.set_shader_parameter("pulse_alpha", 1.0)

# 글로우 머티리얼 제거.
# 소유권 계약(고정): Glow.apply() 이후 clear()까지 material 슬롯은 Glow 소유.
#   - 여전히 소유 중(node.material == 우리가 붙인 glow mat)이면 → 부착 직전 material로 복원.
#   - 그 사이 외부가 material을 교체해 소유권이 넘어갔으면(node.material != glow mat)
#     → 외부 교체를 **존중**(덮어쓰지 않음). 외부가 새 소유자이므로 prior 백업은 폐기.
#   어느 경우든 Glow 메타데이터는 정리한다(재부착 시 그 시점 material을 새 baseline으로 백업).
static func clear(node: CanvasItem) -> void:
	if node == null or not node.has_meta(META_KEY):
		return
	var mat: ShaderMaterial = node.get_meta(META_KEY)
	if node.material == mat:
		node.material = node.get_meta(META_PRIOR) if node.has_meta(META_PRIOR) else null
	node.remove_meta(META_KEY)
	if node.has_meta(META_PRIOR):
		node.remove_meta(META_PRIOR)

# 글로우 부착 + 펄스 알파 무한 loop tween 시작. tween 반환(호출자가 kill 가능).
# 노드는 tree 안에 있어야 함(create_tween 요건).
static func pulse(node: CanvasItem, color: Color = ELIGIBLE_COLOR, period: float = 1.0) -> Tween:
	apply(node, color)
	var mat: ShaderMaterial = node.get_meta(META_KEY) if node.has_meta(META_KEY) else null
	if mat == null:
		return null
	var t := node.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var set_alpha := func(v: float) -> void: mat.set_shader_parameter("pulse_alpha", v)
	t.tween_method(set_alpha, 0.35, 1.0, period * 0.5)
	t.tween_method(set_alpha, 1.0, 0.35, period * 0.5)
	return t
