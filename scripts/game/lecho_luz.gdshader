shader_type canvas_item;
// El suelo pintado del lecho (lecho.png, con la luz del haz ya cocida en la
// imagen, como la de las hojas: luz_en de hojas_voladoras.gd). Con luz_viva
// por debajo de 1 se le quita lo que le daba el haz, hasta la luz del claro a
// oscuras (2026-10-14: al coger el baculo el haz se apaga).

uniform float luz_viva : hint_range(0.0, 1.0) = 1.0;
uniform vec2 haz_origen = vec2(1620.0, -700.0);
uniform vec2 haz_destino = vec2(1456.0, 1200.0);
uniform float haz_apertura = 0.17;

const float OSCURA = 0.28;

varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float luz_en(vec2 p) {
	vec2 d = (p - haz_destino) / vec2(1050.0, 520.0);
	float suelo = OSCURA + 0.87 * exp(-(d.x * d.x + 0.6 * d.y * d.y) * 1.6);
	vec2 eje = normalize(haz_destino - haz_origen);
	float a = acos(clamp(dot(eje, normalize(p - haz_origen)), -1.0, 1.0));
	float haz = OSCURA + 0.8 * (1.0 - smoothstep(haz_apertura * 0.35, haz_apertura, a));
	return max(suelo, haz);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = luz_en(mundo);
	COLOR = vec4(c.rgb * mix(OSCURA / l, 1.0, luz_viva), c.a);
}
