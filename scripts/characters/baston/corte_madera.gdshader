shader_type canvas_item;
// Madera del baston: solo se dibuja entre `desde` y `corte` (fracciones del
// alto, 0 arriba). Con la funda de cuero (2026-10-08), de perfil el baston va
// detras del cuerpo y una copia (MaderaDelante) pone delante solo el tramo del
// hombro a la funda; por debajo de la funda no se dibuja (va hacia la cadera
// contraria, tapado). 0 y 1 = entero.
uniform float desde : hint_range(0.0, 1.0) = 0.0;
uniform float corte : hint_range(0.0, 1.0) = 1.0;
// Engordar el trazo (texeles; 0 = tal cual): el baston a la espalda del de
// frente (PeregrinoFrontal) se engorda para casar con el que pinta la IA en los
// videos de sacar y guardar. Alfa, el mayor de alrededor; color, la media.
uniform float engordar = 0.0;

const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.7071, 0.7071), vec2(-0.7071, -0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, 0.7071));

varying vec4 modula;

void vertex() {
	modula = COLOR;
}

void fragment() {
	if (engordar > 0.0) {
		vec4 c = texture(TEXTURE, UV);
		vec4 suma = vec4(c.rgb * c.a, c.a);
		float maximo = c.a;
		for (int i = 0; i < 8; i++) {
			vec4 s = texture(TEXTURE, UV + DIRS[i] * TEXTURE_PIXEL_SIZE * engordar);
			suma += vec4(s.rgb * s.a, s.a);
			maximo = max(maximo, s.a);
		}
		COLOR = vec4(suma.rgb / max(suma.a, 1e-4), maximo) * modula;
	}
	// COLOR ya trae la textura por modulate / self_modulate (en la mano la
	// madera se esconde asi). Antes se volvia a multiplicar por la textura y la
	// madera salia al cuadrado: mucho mas oscura y saturada que baston.png, y
	// al guardar el baston no casaba con el ultimo fotograma de la animacion.
	COLOR.a *= 1.0 - smoothstep(corte - 0.008, corte, UV.y);
	if (desde > 0.0) {
		COLOR.a *= smoothstep(desde, desde + 0.008, UV.y);
	}
}
