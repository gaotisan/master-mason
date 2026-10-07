shader_type canvas_item;
// Bruma baja sobre el borde de atras de la hojarasca: sin ella el lecho acaba
// en una raya dura contra el negro. Va delante del lecho y detras de Magnus,
// se arrastra muy despacio y solo se enciende donde llega el haz.

uniform vec2 tam = vec2(2912.0, 260.0);
uniform float x_luz = 1456.0;
uniform vec3 color : source_color = vec3(0.62, 0.43, 0.24);
uniform float fuerza = 0.32;
uniform float centro = 0.5;    // fila (0..1) mas densa: el borde del lecho

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) { s += a * ruido(p); p *= 2.07; a *= 0.5; }
	return s;
}

void fragment() {
	vec2 px = UV * tam;
	float banda = exp(-pow((UV.y - centro) / 0.22, 2.0));
	float n = fbm(px / vec2(380.0, 70.0) + vec2(TIME * 0.018, TIME * 0.004));
	n *= fbm(px / vec2(900.0, 120.0) - vec2(TIME * 0.009, 0.0)) * 1.6;
	float luz = 0.45 + 0.55 * exp(-pow((px.x - x_luz) / 950.0, 2.0));
	COLOR = vec4(color * luz, clamp(banda * fuerza * (0.35 + n) * luz, 0.0, 1.0));
}
