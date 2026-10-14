shader_type canvas_item;
render_mode blend_add, unshaded;
// Resplandor amplio de la bola sobre lo que tiene alrededor (la capucha, el
// hombro). Va por encima del cuerpo y suma: parece luz. Sutil a proposito.

uniform float carga : hint_range(0.0, 1.0) = 1.0;
uniform vec3 color : source_color = vec3(1.0, 0.62, 0.18);
uniform float fuerza : hint_range(0.0, 1.0) = 0.16;
uniform float destello : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float f = pow(max(0.0, 1.0 - r), 2.2);
	float latido = 1.0 + 0.15 * sin(TIME * 3.2) * smoothstep(0.97, 1.0, carga);
	COLOR = vec4(color * f * (fuerza * carga * carga * latido + destello * 0.35), 1.0);
}
