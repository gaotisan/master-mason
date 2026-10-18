shader_type canvas_item;
// Las letras del titulo (titulo_letras.gd) con el material de las que iban
// pintadas en el fondo. La fuente va en MSDF: de TEXTURE sale la distancia al
// borde, y de ella todo (lo midio raw/master_builder/titulo_hojas/titulo_sin_letras.py
// sobre las letras pintadas):
//  - el color por distancia al borde y por la orientacion del borde, que es la
//    luz del bisel (titulo_material.png: fila 0 el color, filas 1-4 lo que suma
//    cada termino de la orientacion, fila 5 la altura en la letra y la posicion
//    en la linea);
//  - el grano de la cara (titulo_grano.png, en espejo para que no se vean
//    costuras), hasta el filo;
//  - por fuera, el canto se funde con el fondo entre -1,5 y -0,5 px.
// Va por debajo de la mascara de oscuridad: la luz de la sala es la del fondo.
render_mode blend_mix;

uniform sampler2D material_tex : filter_linear;
uniform sampler2D grano : filter_linear;
// px de la imagen por unidad de la distancia del MSDF (rango * tamano / em).
uniform float px_range = 63.0;
// Linea: base y alto de mayusculas (para la altura en la letra), centro y medio
// ancho (para la posicion en la linea). En px de la imagen.
uniform float base_y = 0.0;
uniform float cap = 93.0;
uniform float centro_x = 0.0;
uniform float medio_ancho = 270.0;
uniform float fundido : hint_range(0.0, 1.0) = 1.0;
// El destello que cruza el titulo (el mismo de title_reveal: banda diagonal).
uniform float glint = -1.0;
uniform float glint_strength = 0.75;
uniform vec4 title_rect = vec4(0.34, 0.33, 0.66, 0.62);
uniform vec2 image_size = vec2(2912.0, 1632.0);

const vec3 GLINT_COLOR = vec3(1.0, 0.92, 0.7);
const float LADO_GRANO = 256.0;

varying vec2 pos;

void vertex() {
	pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float mediana(vec3 c) {
	return max(min(c.r, c.g), min(max(c.r, c.g), c.b));
}

vec3 curva(float x, float fila) {
	return texture(material_tex, vec2(x, (fila + 0.5) / 6.0)).rgb * 255.0;
}

vec3 termino(int i) {
	return (texelFetch(material_tex, ivec2(i, 5), 0).rgb * 255.0 - 128.0) * 2.0;
}

void fragment() {
	float sd = (mediana(texture(TEXTURE, UV).rgb) - 0.5) * px_range;
	vec2 g = vec2(dFdx(sd), dFdy(sd));
	vec2 n = g / max(length(g), 1e-5);
	float x = (clamp(sd, -4.0, 12.0) + 4.0) / 16.0 * (63.0 / 64.0) + 0.5 / 64.0;
	vec3 c = curva(x, 0.0)
		+ (curva(x, 1.0) - 128.0) * n.x
		+ (curva(x, 2.0) - 128.0) * n.y
		+ (curva(x, 3.0) - 128.0) * n.x * n.y
		+ (curva(x, 4.0) - 128.0) * (n.x * n.x - n.y * n.y);
	float v = (pos.y - (base_y - cap)) / cap;
	float u = (pos.x - centro_x) / medio_ancho;
	float dentro = clamp(sd, 0.0, 2.0) / 2.0;
	c += (termino(0) * v + termino(1) * v * v + termino(2) * u + termino(3) * u * u) * dentro;
	// Grano: tesela de 256 px de la imagen leida en espejo.
	vec2 q = 1.0 - abs(mod(pos / LADO_GRANO, 2.0) - 1.0);
	vec3 gr = (texture(grano, q).rgb * 255.0 - 128.0) * 0.5;
	c += gr * clamp((sd - 0.3) / 0.7, 0.0, 1.0);
	vec3 col = clamp(c / 255.0, 0.0, 1.0);

	vec2 uv = pos / image_size;
	float gl = (uv.x - title_rect.x) / (title_rect.z - title_rect.x) + (uv.y - 0.5) * 0.45;
	float gx = (gl - glint) / 0.085;
	col += GLINT_COLOR * exp(-gx * gx) * glint_strength * clamp(sd, 0.0, 1.0);

	COLOR = vec4(col, clamp(sd + 1.5, 0.0, 1.0) * fundido);
}
