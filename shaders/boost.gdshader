// Glowing boost pad with chevrons streaming forward.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 col : source_color = vec4(0.1, 0.9, 1.0, 1.0);

void fragment() {
	float ph = fract(UV.y * 2.5 + abs(UV.x - 0.5) * 1.8 - TIME * 3.0);
	float m = step(0.55, ph);
	float edge = step(0.9, abs(UV.x - 0.5) * 2.0);
	ALBEDO = col.rgb * (0.25 + 2.2 * max(m, edge));
}
