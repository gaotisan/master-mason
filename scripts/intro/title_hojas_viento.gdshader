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
// velocidad del muelle por el tiempo que tarda en llegar.
// Encima: ramitas a su aire (a escala de rama) y aleteo de hojas (a escala de
// hoja), con un titileo de brillo de hoja que gira y coge la luz.
//
// La mascara (title_hojas_mascara.png) la genera componer.py junto al fondo.

const int N = 6;

uniform sampler2D leaf_mask : filter_linear;
// Por arbusto (px de la imagen): raiz, centro y radio de su zona, largo de rama,
// y el estado del muelle (desplazamiento de la punta y su velocidad, px y px/s).
uniform vec2 raiz[N];
uniform vec2 centro[N];
uniform float radio[N];
uniform float largo[N];
uniform vec2 empuje[N];
uniform vec2 empuje_vel[N];
// Viento local 0..1 de cada arbusto (la racha cuando le llega a el).
uniform float agitacion[N];
// 0..1: viento de fondo.
uniform float brisa : hint_range(0.0, 1.0) = 0.5;

// Velocidad a la que sube la onda por la rama (px/s). El retraso en la punta
// tiene que quedar en 0,1-0,3 s: con 900 px/s pasaba de un segundo y la
// aproximacion (restar la velocidad) llegaba a mover la rama al reves.
uniform float onda_px_s = 4500.0;
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
	} else {
		vec2 size = 1.0 / TEXTURE_PIXEL_SIZE;
		vec2 p = UV * size;
		float t = TIME;

		// Rama: cada arbusto pesa segun lo cerca que este de su zona.
		vec2 d = vec2(0.0);
		float wsum = 0.0;
		float ag = 0.0;
		for (int i = 0; i < N; i++) {
			vec2 q = (p - centro[i]) / radio[i];
			float w = exp(-dot(q, q));
			float l = length(p - raiz[i]);
			float flex = pow(clamp(l / largo[i], 0.0, 1.0), 1.4);
			// La punta va con retraso: lo que tenia el muelle hace l / onda segundos.
			vec2 o = empuje[i] - empuje_vel[i] * (l / onda_px_s);
			d += w * o * flex;
			ag += w * agitacion[i];
			wsum += w;
		}
		d /= max(wsum, 1e-4);
		ag /= max(wsum, 1e-4);

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
