shader_type canvas_item;
render_mode unshaded;

// 재사용 외곽선 글로우 (STAGE_GUIDE_PLAN §0.8.3-2).
// 개미 스프라이트·surface 타일에 적용. 외곽선 폭·색·펄스 알파를 uniform으로 노출.
// 펄스 알파는 Glow.pulse() tween이 0.35↔1.0 으로 구동.

uniform vec4 outline_color : source_color = vec4(0.94, 0.84, 0.48, 1.0); // Tokens.LEMON_500 근사
uniform float outline_width : hint_range(0.0, 8.0) = 2.0;
uniform float pulse_alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec2 ts = TEXTURE_PIXEL_SIZE * outline_width;

	// 8방향 이웃 텍셀의 최대 알파 → 스프라이트 외곽 경계 검출.
	float a = 0.0;
	a = max(a, texture(TEXTURE, UV + vec2( ts.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ts.x, 0.0)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0,  ts.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(0.0, -ts.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2( ts.x,  ts.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ts.x,  ts.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2( ts.x, -ts.y)).a);
	a = max(a, texture(TEXTURE, UV + vec2(-ts.x, -ts.y)).a);

	float outline = clamp(a - col.a, 0.0, 1.0);
	vec4 oc = outline_color;
	oc.a *= outline * pulse_alpha;

	// 외곽선은 스프라이트 뒤로, 스프라이트 픽셀은 그대로.
	COLOR = mix(oc, col, col.a);
}
