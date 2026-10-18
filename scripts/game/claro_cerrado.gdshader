shader_type canvas_item;
// EL CLARO SE CIERRA (caida_hojarasca.gd, _cerrar_claro): el suelo de hojas se va
// a una oscuridad de niebla. Llega hasta la linea de los arboles (borde_lejos) en
// todo el ancho, menos en la boca del camino (camino_x), donde baja hasta los pies
// del peregrino (borde): solo queda el bosque con la entrada del camino. `subida`
// (0..1) la trae desde abajo.
// No es un negro liso: el borde se deshilacha con bruma (ruido que deriva), lleva
// un labio de niebla que coge algo de la luz del camino, y por dentro la oscuridad
// tiene niebla que se mueve despacio.

uniform float borde = 1194.0;
uniform float borde_lejos = 1150.0;
uniform float camino_x = 2440.0;
uniform float camino_ancho = 190.0;
uniform float ancho_mundo = 2912.0;
uniform float suave = 80.0;
uniform float subida : hint_range(0.0, 1.0) = 1.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform vec3 color : source_color = vec3(0.03, 0.024, 0.02);
uniform vec3 niebla : source_color = vec3(0.33, 0.25, 0.2);
uniform float labio = 0.35;
// el labio a lo ancho (1) o solo en la boca (0): ya cerrado, una banda clara a lo
// ancho parecia un suelo por el que andar
uniform float labio_lados = 1.0;
uniform sampler2D ruido : filter_linear, repeat_enable;

varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float x = mundo.x;
	// el mundo da la vuelta: la boca mas cercana
	float dx = mod(x - camino_x + ancho_mundo * 0.5, ancho_mundo) - ancho_mundo * 0.5;
	float boca = exp(-(dx * dx) / (camino_ancho * camino_ancho));
	float b = mix(borde_lejos, borde, boca);
	b = mix(1632.0 + suave + 60.0, b, subida);
	// la bruma: dos capas de ruido que derivan a distinto ritmo (en coordenadas
	// del mundo, estiradas en horizontal como niebla tendida)
	float n1 = texture(ruido, mundo * vec2(0.0011, 0.0034) + vec2(TIME * 0.012, 0.0)).r;
	float n2 = texture(ruido, mundo * vec2(0.0027, 0.0075) + vec2(-TIME * 0.024, TIME * 0.006)).r;
	float ondula = 7.0 * sin(x * 0.0041 + TIME * 0.31) + 4.0 * sin(x * 0.0113 - TIME * 0.23)
		+ (n1 - 0.5) * 46.0;
	float e = b + ondula;
	float a = smoothstep(e - suave * 0.25, e + suave, mundo.y);
	// el labio: una banda de niebla justo en el borde, rota por el ruido fino
	float d = (mundo.y - (e + suave * 0.05)) / (suave * 0.5);
	float l = exp(-d * d) * smoothstep(0.25, 0.75, n2) * labio * mix(boca, 1.0, labio_lados);
	// dentro, la oscuridad con niebla que se mueve (sin llegar al negro liso)
	vec3 c = color * (0.75 + 0.6 * n2);
	c = mix(c, niebla, l / max(a + l, 0.001));
	COLOR = vec4(c, max(a, l) * alfa);
}
