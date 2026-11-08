// Full-screen PS2-style post: speed radial blur, chromatic split, vignette,
// interlace lines, ordered dither + colour quantise, hit/boost flash.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float blur = 0.0;
uniform float aberration = 0.0;
uniform float vignette = 0.6;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash = 0.0;
uniform float levels = 40.0;
uniform float scan = 0.05;
uniform vec2 focus = vec2(0.5, 0.47);
uniform vec3 grade = vec3(0.98, 0.95, 0.88);   // dull warm-grey colour grade
uniform float lift = 0.015;
uniform float wet = 0.0;      // water splashed over the lens by gushers

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	float m[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};
	return m[x + y * 4] / 16.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (wet > 0.0) {
		uv += wet * 0.014 * vec2(sin(uv.y * 47.0 + TIME * 6.0) + sin(uv.y * 13.0 - TIME * 3.0), cos(uv.x * 39.0 + TIME * 5.0));
	}
	vec2 d = uv - focus;
	float r = length(d);
	float edge = smoothstep(0.05, 0.55, r);
	vec3 col = vec3(0.0);
	float tot = 0.0;
	for (int i = 0; i < 12; i++) {
		float t = float(i) / 11.0;
		float sc = 1.0 - blur * t * edge;
		float w = 1.0 - t * 0.55;
		col += texture(screen_tex, focus + d * sc).rgb * w;
		tot += w;
	}
	col /= tot;
	if (aberration > 0.0) {
		float rr = texture(screen_tex, focus + d * (1.0 + aberration * edge)).r;
		float bb = texture(screen_tex, focus + d * (1.0 - aberration * edge)).b;
		col.r = mix(col.r, rr, 0.7);
		col.b = mix(col.b, bb, 0.7);
	}
	col = col * grade + vec3(lift);
	col = mix(col, vec3(0.72, 0.78, 0.78) * (0.55 + 0.45 * col), wet * 0.6);
	float vg = smoothstep(0.95, 0.2, length(d * vec2(1.25, 1.0)));
	col *= mix(1.0, vg, vignette);
	col *= 1.0 - scan * mod(floor(FRAGCOORD.y), 2.0);
	col = mix(col, flash_color.rgb, flash);
	float b = bayer4(FRAGCOORD.xy) - 0.5;
	col = floor(col * levels + b + 0.5) / levels;
	COLOR = vec4(col, 1.0);
}
