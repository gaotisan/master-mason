shader_type canvas_item;
// EL CLARO SE CIERRA (caida_hojarasca.gd, _cerrar_claro): el suelo de hojas se va
// a una oscuridad de niebla. Llega hasta la linea de los arboles (borde_lejos) en
// todo el ancho, menos en la boca del camino (camino_x), donde baja hasta los pies
// del peregrino (borde): solo queda el bosque con la entrada del camino. El borde
// ondula despacio, como bruma. `subida` (0..1) la trae desde abajo.

uniform float borde = 1194.0;
uniform float borde_lejos = 1150.0;
uniform float camino_x = 2440.0;
uniform float camino_ancho = 190.0;
uniform float ancho_mundo = 2912.0;
uniform float suave = 80.0;
uniform float subida : hint_range(0.0, 1.0) = 1.0;
uniform float alfa : hint_range(0.0, 1.0) = 1.0;
uniform vec3 color : source_color = vec3(0.03, 0.024, 0.02);

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
	float ondula = 7.0 * sin(x * 0.0041 + TIME * 0.31) + 4.0 * sin(x * 0.0113 - TIME * 0.23)
		+ 2.0 * sin(x * 0.027 + TIME * 0.5);
	float a = smoothstep(b + ondula - suave * 0.25, b + ondula + suave, mundo.y);
	COLOR = vec4(color, a * alfa);
}
