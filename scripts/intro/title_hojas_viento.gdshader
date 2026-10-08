shader_type canvas_item;
// Viento en los arbustos del fondo del titulo. No hay hojas recortadas: se
// desplaza la propia imagen, solo donde la mascara dice que hay follaje (la
// pared, las vigas y el cristal se quedan quietos).
//
// Cada arbusto es una rama elastica anclada en su raiz (la esquina o el borde
// del que sale): la base no se mueve y la punta se mueve mas (flex). Su
// desplazamiento lo lleva un muelle en viento_titulo.gd: la racha lo empuja a
// favor del viento, rebota y vuelve. Lo de la punta va un pelin retrasado
// respecto a la base (la onda sube por la rama): se aproxima restando la
// velocidad del muelle por un retraso fijo de cada arbusto.
// Cuanto pertenece cada pixel a cada arbusto, por lo que se dobla ahi la rama,
// es fijo: va horneado en dos texturas (pesos_viento.py), y aqui solo se leen.
// Encima: ramitas a su aire (a escala de rama) y aleteo de hojas (a escala de
// hoja), con un titileo de brillo de hoja que gira y coge la luz.
//
// La mascara (title_hojas_mascara.png) la genera componer.py junto al fondo.

uniform sampler2D leaf_mask : filter_linear;
// Peso de cada arbusto en el pixel (ya con lo que se dobla la rama ahi):
// pesos_a RGB = arbustos 0..2, pesos_b RGB = 3..5.
uniform sampler2D pesos_a : filter_linear;
uniform sampler2D pesos_b : filter_linear;
// Por arbusto, desplazamiento de la punta del muelle ya con su retraso (px).
uniform vec2 empuje[6];
// Viento local 0..1 de cada arbusto (la racha cuando le llega a el).
uniform float agitacion[6];
// 0..1: viento de fondo.
uniform float brisa : hint_range(0.0, 1.0) = 0.5;

// Salida: las letras del titulo se funden con una placa del mismo panel sin
// letras (placa_sin_letras.py), 0 = letras, 1 = panel liso. La placa cubre
// PLACA_RECT (px de la imagen) y ya trae su propio fundido en el borde.
uniform sampler2D placa : filter_linear;
uniform float placa_fundido : hint_range(0.0, 1.0) = 0.0;
const vec4 PLACA_RECT = vec4(1000.0, 540.0, 1740.0, 1060.0);

// Ramitas: amplitud (px) en calma y con la racha.
uniform float ramita_px = 1.6;
uniform float ramita_racha_px = 4.5;
// Aleteo de hoja (px).
uniform float aleteo_px = 0.6;
uniform float aleteo_racha_px = 1.6;
uniform float titileo = 0.04;
uniform float titileo_racha = 0.08;

const vec3 LUMW = vec3(0.3, 0.59, 0.11);

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float m = texture(leaf_mask, UV).r;
	// Casi toda la pantalla (cristal, pared, vigas) no tiene hojas: ni se calcula.
	if (m < 0.004) {
		COLOR = texture(TEXTURE, UV);
		if (placa_fundido > 0.0) {
			vec2 p = UV / TEXTURE_PIXEL_SIZE;
			vec2 q = (p - PLACA_RECT.xy) / (PLACA_RECT.zw - PLACA_RECT.xy);
			if (q.x >= 0.0 && q.y >= 0.0 && q.x <= 1.0 && q.y <= 1.0) {
				COLOR.rgb = mix(COLOR.rgb, texture(placa, q).rgb, placa_fundido);
			}
		}
	} else {
		vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 p = UV * size;
		float t = TIME;

		// Rama: la suma de los arbustos con su peso horneado. La agitacion se
		// reparte con los mismos pesos sin la flexion; con estos basta.
		vec3 wa = texture(pesos_a, UV).rgb;
		vec3 wb = texture(pesos_b, UV).rgb;
		vec2 d = empuje[0] * wa.r + empuje[1] * wa.g + empuje[2] * wa.b
			+ empuje[3] * wb.r + empuje[4] * wb.g + empuje[5] * wb.b;
		float wt = wa.r + wa.g + wa.b + wb.r + wb.g + wb.b;
		float ag = (agitacion[0] * wa.r + agitacion[1] * wa.g + agitacion[2] * wa.b
			+ agitacion[3] * wb.r + agitacion[4] * wb.g + agitacion[5] * wb.b) / max(wt, 1e-3);

		// Ramitas: trozos del tamano de una rama que van cada uno a su aire.
		vec2 r1 = p / 150.0 + vec2(-t * 0.35, t * 0.12);
		vec2 rn = vec2(noise(r1), noise(r1 + vec2(13.7, 5.1))) - 0.5;
		d += rn * 2.0 * (ramita_px * brisa + ramita_racha_px * ag);

		// Aleteo: hojas sueltas, mucho mas rapido y pequeno.
		vec2 r2 = p / 40.0;
		vec2 fl = vec2(noise(r2 + vec2(t * 2.3, -t * 1.5)), noise(r2 + vec2(-t * 1.9, t * 2.6) + 11.0)) - 0.5;
		d += fl * 2.0 * (aleteo_px * brisa + aleteo_racha_px * ag);

		vec4 c = texture(TEXTURE, UV - d * m * TEXTURE_PIXEL_SIZE);

		// Titileo: la hoja que gira coge o pierde un poco de luz. Solo en lo que
		// tiene luz, para no levantar las sombras.
		float lum = dot(c.rgb, LUMW);
		float s = noise(p / 30.0 + vec2(t * 2.8, t * 1.9)) - 0.5;
		c.rgb *= 1.0 + s * 2.0 * m * (titileo * brisa + titileo_racha * ag) * smoothstep(0.12, 0.5, lum);
		COLOR = c;
	}
}
