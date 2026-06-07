extends Node

# Phase 1 (new-user-onboarding) — outline 셰이더 + Glow 헬퍼 헤드리스 스모크.
# Sprite2D(개미 대용) + ColorRect(타일 rect 대용)에 Glow 적용/펄스/해제 무오류 확인.
# 셰이더 컴파일·머티리얼 부착·uniform 세팅·clear 시 외부 머티리얼 보존 검증.

func _ready() -> void:
	var failures: Array[String] = []

	# --- Sprite2D 대상: apply → uniform 세팅 확인 ---
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	add_child(spr)
	await get_tree().process_frame

	Glow.apply(spr, Tokens.LEMON_500, 3.0)
	await get_tree().process_frame
	var mat: ShaderMaterial = spr.material as ShaderMaterial
	if mat == null:
		failures.append("Sprite2D Glow.apply did not attach ShaderMaterial")
	elif mat.shader == null:
		failures.append("Glow material has no shader (compile/load fail)")
	else:
		if not mat.get_shader_parameter("outline_width") == 3.0:
			failures.append("outline_width uniform not set to 3.0 (got %s)" % str(mat.get_shader_parameter("outline_width")))
		var oc: Color = mat.get_shader_parameter("outline_color")
		if oc == null or not oc.is_equal_approx(Tokens.LEMON_500):
			failures.append("outline_color uniform not set to LEMON_500 (got %s)" % str(oc))

	# --- 재적용 멱등: 머티리얼 재생성 안 함 ---
	Glow.apply(spr)
	await get_tree().process_frame
	if spr.material != mat:
		failures.append("Glow.apply re-created material on second call (should reuse)")

	# --- pulse: 유효 loop tween 반환 ---
	var t: Tween = Glow.pulse(spr, Tokens.LEMON_500, 1.0)
	await get_tree().process_frame
	if t == null or not t.is_valid():
		failures.append("Glow.pulse did not return a valid tween")

	# --- clear: Glow가 붙인 것만 제거 ---
	if t != null and t.is_valid():
		t.kill()
	Glow.clear(spr)
	await get_tree().process_frame
	if spr.material != null:
		failures.append("Glow.clear did not detach material")
	if spr.has_meta(Glow.META_KEY):
		failures.append("Glow.clear did not remove meta key")

	# --- 외부 머티리얼 보존(no-glow): Glow.clear는 외부 material을 건드리지 않음 ---
	var foreign := ShaderMaterial.new()
	spr.material = foreign
	Glow.clear(spr)  # meta 없음 → no-op 이어야 함
	await get_tree().process_frame
	if spr.material != foreign:
		failures.append("Glow.clear removed a foreign (non-Glow) material")

	# --- 기존 material 원복: 글로우 부착 직전 material을 clear가 복원 ---
	# spr.material 은 지금 foreign. apply → glow material 로 교체, clear → foreign 복원.
	Glow.apply(spr)
	await get_tree().process_frame
	if spr.material == foreign:
		failures.append("Glow.apply did not replace prior material with glow material")
	Glow.clear(spr)
	await get_tree().process_frame
	if spr.material != foreign:
		failures.append("Glow.clear did not restore prior (foreign) material (got %s)" % str(spr.material))
	spr.material = null

	# --- interleaving 소유권 핸드오프: apply 후 외부가 material 교체 → clear는 존중 ---
	# 계약: 글로우 활성 중 외부가 material을 바꾸면 소유권이 외부로 넘어감.
	#       clear()는 그 외부 material을 덮어쓰지 않고(존중) 메타만 정리한다.
	Glow.apply(spr)
	await get_tree().process_frame
	var foreign2 := ShaderMaterial.new()
	spr.material = foreign2  # 외부가 소유권 가져감
	Glow.clear(spr)
	await get_tree().process_frame
	if spr.material != foreign2:
		failures.append("Glow.clear clobbered an external material set after apply (handoff 위반)")
	if spr.has_meta(Glow.META_KEY) or spr.has_meta(Glow.META_PRIOR):
		failures.append("Glow.clear did not clean metadata after external handoff")
	# 재부착 시 그 시점 material(foreign2)을 새 baseline 으로 → clear 시 foreign2 복원
	Glow.apply(spr)
	await get_tree().process_frame
	Glow.clear(spr)
	await get_tree().process_frame
	if spr.material != foreign2:
		failures.append("Glow re-apply/clear did not restore foreign2 as new baseline")
	spr.material = null

	# --- ColorRect(타일 rect 대용)에도 부착/해제 동작 ---
	var rect := ColorRect.new()
	rect.size = Vector2(48, 48)
	add_child(rect)
	await get_tree().process_frame
	Glow.apply(rect)
	await get_tree().process_frame
	if not (rect.material is ShaderMaterial):
		failures.append("ColorRect Glow.apply did not attach ShaderMaterial")
	Glow.clear(rect)
	await get_tree().process_frame
	if rect.material != null:
		failures.append("ColorRect Glow.clear did not detach material")

	# --- 결과 ---
	if failures.size() > 0:
		push_error("OutlineGlowSmokeTest FAIL: " + str(failures))
		print("[OutlineGlowSmokeTest] FAIL")
		for f in failures:
			print("  - ", f)
		get_tree().quit(1)
	else:
		print("[OutlineGlowSmokeTest] PASS — shader compiled, Glow apply/pulse/clear OK on Sprite2D + ColorRect")
		get_tree().quit(0)
