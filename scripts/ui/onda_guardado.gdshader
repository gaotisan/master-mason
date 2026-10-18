shader_type canvas_item;
render_mode blend_add, unshaded;
// Onda de luz de la marca de guardado: un anillo que sale de la bola del
// baculo cuando acaba de llenarse, se abre y se apaga. Suma (es luz).
//   avance  0 recien salida (pegada a la bola) .. 1 abierta y apagada

uniform float avance : hint_range(0.0, 1.0) = 0.0;
uniform vec3 color : source_color = vec3(1.0, 0.62, 0.18);
// Radio de la bola en este cuadrado (fraccion del medio lado), donde nace.
uniform float radio_bola = 0.22;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float radio = mix(radio_bola, 0.92, avance);
	float ancho = mix(0.025, 0.09, avance);
	float anillo = exp(-pow((r - radio) / ancho, 2.0));
	// por dentro deja un poco de estela
	anillo += exp(-max(radio - r, 0.0) * 9.0) * step(r, radio) * 0.18;
	float vida = pow(1.0 - avance, 1.6) * smoothstep(0.0, 0.06, avance);
	// que no llegue al borde del cuadrado
	float borde = 1.0 - smoothstep(0.88, 1.0, r);
	vec3 c = mix(color, vec3(1.0, 0.93, 0.8), 0.35);
	COLOR = vec4(c * anillo * vida * borde * 0.55, 1.0);
}
