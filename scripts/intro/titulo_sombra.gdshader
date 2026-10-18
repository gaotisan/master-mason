shader_type canvas_item;
// Sombra de las letras del titulo (titulo_letras.gd): la de las letras que iban
// pintadas, que caia de los pies, hacia abajo y difuminada. El nodo va bajado
// lo que cae la sombra; aqui la letra se difumina con la distancia del MSDF (el
// difuminado gaussiano de un borde recto, con una logistica) y solo cuenta su
// parte de abajo (los pies). Sobre el fondo oscurece: negro con esa opacidad.
render_mode blend_mix;

uniform float px_range = 63.0;
// Base y alto de mayusculas de la letra que hace la sombra (ya bajada).
uniform float base_y = 0.0;
uniform float cap = 93.0;
uniform float sigma = 10.0;
uniform float fuerza = 0.944;
// Desde que altura de la letra (0 arriba, 1 la base) cuenta como pies.
uniform float pies = 0.6;
uniform float fundido : hint_range(0.0, 1.0) = 1.0;

varying vec2 pos;

void vertex() {
	pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float mediana(vec3 c) {
	return max(min(c.r, c.g), min(max(c.r, c.g), c.b));
}

float cubre(float sd) {
	return 1.0 / (1.0 + exp(-1.702 * sd / sigma));
}

void fragment() {
	float sd = (mediana(texture(TEXTURE, UV).rgb) - 0.5) * px_range;
	// Lo que queda en el borde del cuadro del glifo se resta, para que no se
	// vea su rectangulo.
	float borde = cubre(-0.5 * px_range + 1.0);
	float c = max(cubre(sd) - borde, 0.0) / (1.0 - borde);
	float v = (pos.y - (base_y - cap)) / cap;
	float s = sigma / cap;
	float de_pies = smoothstep(pies - s, pies + s, v);
	COLOR = vec4(0.0, 0.0, 0.0, clamp(fuerza * c * de_pies, 0.0, 0.85) * fundido);
}
