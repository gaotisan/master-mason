shader_type canvas_item;
// Cielo del bosque: degradado de acuarela, resplandor del sol (o de la luna),
// estrellas y el "camino de estrellas" del cuento. Va en un ColorRect que
// ocupa la pantalla entera en un CanvasLayer por detras de todo; bosque.gd le
// pasa los colores de la hora del dia segun por donde va Magnus.
//
// Coste: una muestra de textura y unas cuentas por pixel; las estrellas son un
// hash por celda, sin bucles.

uniform vec4 color_arriba : source_color = vec4(0.357, 0.435, 0.584, 1.0);
uniform vec4 color_horizonte : source_color = vec4(0.914, 0.722, 0.604, 1.0);
uniform vec4 color_brillo : source_color = vec4(1.0, 0.698, 0.478, 1.0);
// Centro del resplandor en UV de pantalla y su fuerza (0 = nada).
uniform vec2 pos_brillo = vec2(0.6, 0.72);
uniform float fuerza_brillo : hint_range(0.0, 1.0) = 0.4;
// Donde el degradado llega al color del horizonte (fraccion del alto).
uniform float altura_horizonte : hint_range(0.3, 1.0) = 0.78;
uniform float estrellas : hint_range(0.0, 1.0) = 0.0;
uniform float via_lactea : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D manchas : repeat_enable, filter_linear_mipmap;
// Desplazamiento horizontal de las manchas y las estrellas (la camara por un
// factor pequeno): el cielo esta lejisimos, pero no clavado.
uniform float desplaza = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = pow(clamp(uv.y / altura_horizonte, 0.0, 1.0), 1.6);
	vec3 c = mix(color_arriba.rgb, color_horizonte.rgb, t);

	// Acuarela: dos escalas de la misma textura de manchas.
	float m1 = texture(manchas, uv * vec2(1.6, 0.9) + vec2(desplaza * 0.6, 0.0)).r;
	float m2 = texture(manchas, uv * vec2(4.1, 2.3) + vec2(desplaza, 0.37)).r;
	c *= 0.9 + 0.14 * m1 + 0.06 * m2;

	// Resplandor: elipse ancha, sin borde.
	vec2 d = (uv - pos_brillo) * vec2(1.784 / 0.62, 1.0 / 0.34);
	float g = exp(-dot(d, d) * 0.9) * fuerza_brillo;
	c = mix(c, color_brillo.rgb, clamp(g, 0.0, 1.0));

	// Estrellas: una por celda como mucho, parpadeo lento, se apagan hacia el
	// horizonte y bajo el resplandor.
	if (estrellas > 0.001) {
		vec2 px = uv * vec2(2912.0, 1632.0) + vec2(desplaza * 900.0, 0.0);
		vec2 celda = floor(px / 9.0);
		float h = hash(celda);
		if (h > 0.978) {
			vec2 centro = (celda + vec2(hash(celda + 7.1), hash(celda + 3.7))) * 9.0;
			float r = length(px - centro);
			// 2,6 px del lienzo: en una pantalla de 1536 son algo mas de un pixel.
			float brillo = smoothstep(2.6, 0.0, r) * (0.55 + 0.45 * sin(TIME * (0.6 + h * 1.7) + h * 40.0));
			brillo *= 0.35 + 0.65 * (h - 0.978) / 0.022;
			float cielo_libre = 1.0 - smoothstep(0.45, 0.72, uv.y);
			c += vec3(0.85, 0.9, 1.0) * brillo * 1.25 * estrellas * cielo_libre * (1.0 - g);
		}
	}

	// Camino de estrellas: banda diagonal de polvo luminoso.
	if (via_lactea > 0.001) {
		vec2 q = uv - vec2(0.5, 0.2);
		float dist = abs(dot(q, normalize(vec2(0.42, 1.0))));
		float banda = exp(-dist * dist / 0.018);
		float polvo = texture(manchas, uv * vec2(3.0, 1.8) + vec2(desplaza * 0.8, 0.11)).r;
		float fino = hash(floor(uv * vec2(2912.0, 1632.0) / 2.0) + floor(desplaza * 400.0));
		banda *= smoothstep(0.35, 0.8, polvo) * 0.55 + step(0.965, fino) * 0.45;
		banda *= 1.0 - smoothstep(0.4, 0.68, uv.y);
		c += vec3(0.62, 0.7, 0.88) * banda * via_lactea * 0.55;
	}

	// Grano de papel.
	c *= 0.985 + 0.03 * hash(floor(uv * vec2(1456.0, 816.0)));
	COLOR = vec4(c, 1.0);
}
