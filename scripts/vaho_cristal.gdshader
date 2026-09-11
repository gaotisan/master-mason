shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform float scale : hint_range(0.3, 2.5) = 1.2;
uniform float residue : hint_range(0.0, 1.0) = 0.0;
uniform float seed = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p + 33.33);
	return fract((p.x + p.y) * p.x);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

// Dos octavas bastan para el vaho; la tercera no se aprecia y cuesta un 50% mas.
float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.0) * 0.25;
}

void fragment() {
	vec2 uv = UV;

	// --- MASCARA DE BORDES (TELARANAS) ---
	float dist_edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	float edge_mask = 1.0 - smoothstep(0.0, 0.2, dist_edge);

	// --- SHAKE DE REFRACCION en los bordes (una sola octava de ruido) ---
	float noise_shake = noise(uv * 10.0 + TIME * 3.0);
	vec2 shake = vec2(noise_shake - 0.5) * 0.003 * edge_mask;

	// --- VAHO ATMOSFERICO ---
	vec2 center = vec2(0.5);
	vec2 d = (uv - center);
	d.x *= 1.35;
	float dist = length(d) * (2.0 / scale);
	float mask = smoothstep(0.7, 0.2, dist);

	float n = fbm(uv * 3.0 + vec2(TIME * 0.01) + seed);
	float hot = mask * (0.3 + n * 0.7) * intensity;
	float cold = smoothstep(0.8, 0.2, dist + n * 0.1) * residue;

	float final_alpha = clamp(hot + cold * 0.8, 0.0, 0.6);
	vec3 fog_color = vec3(0.95, 0.98, 1.0);

	vec4 screen_col = texture(SCREEN_TEXTURE, SCREEN_UV + shake);

	COLOR.rgb = mix(screen_col.rgb, fog_color, final_alpha * 0.4);
	COLOR.a = 1.0;
}
