// Flowing sewer water: two scrolling normal layers, fresnel tint, wet specular.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D nmap : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 deep : source_color = vec4(0.03, 0.09, 0.07, 1.0);
uniform vec4 shallow : source_color = vec4(0.16, 0.32, 0.22, 1.0);
uniform float glow = 0.0;
uniform float flow = 1.2;

void fragment() {
	vec2 uv1 = UV * vec2(1.0, 0.6) + vec2(0.0, -TIME * flow);
	vec2 uv2 = UV * vec2(1.6, 1.1) + vec2(0.37, -TIME * flow * 1.7);
	vec3 n1 = texture(nmap, uv1).rgb;
	vec3 n2 = texture(nmap, uv2).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.4;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float foam = smoothstep(0.82, 0.95, abs(UV.x - 0.5) * 2.0) * (0.5 + 0.5 * sin(UV.y * 40.0 - TIME * 12.0));
	ALBEDO = mix(deep.rgb, shallow.rgb, fres) + vec3(foam * 0.12);
	ROUGHNESS = 0.06;
	METALLIC = 0.25;
	SPECULAR = 0.9;
	EMISSION = shallow.rgb * glow * (0.6 + 0.4 * n1.g);
}
