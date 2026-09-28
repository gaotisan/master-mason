shader_type canvas_item;
// Cielo del capitulo 1. luz = 0 es el negro del vacio; con luz y sin sol es un
// resplandor palido y uniforme (primero la luz, luego el sol: Genesis 1); con
// sol es un atardecer (o un amanecer) con el calor pegado al horizonte.

uniform float luz : hint_range(0.0, 1.0) = 0.0;
uniform float sol : hint_range(0.0, 1.0) = 0.0;
uniform float horizonte_uv = 0.7047;
uniform vec2 sol_uv = vec2(0.817, 0.7047);
uniform float aspecto = 1.784;
uniform float baston_u = 0.429;

void fragment() {
	float y = clamp(UV.y / horizonte_uv, 0.0, 1.0);
	vec3 arriba = vec3(0.070, 0.060, 0.110);
	vec3 medio = vec3(0.280, 0.190, 0.230);
	vec3 bajo = vec3(0.860, 0.580, 0.340);
	vec3 c = mix(arriba, medio, smoothstep(0.0, 0.75, y));
	c = mix(c, bajo, smoothstep(0.5, 1.0, y) * 0.85);
	// Luz sin sol: nace del rayo del baston y se abre hacia los lados.
	vec3 sin_sol = vec3(0.62, 0.60, 0.57) * (0.70 + 0.30 * y);
	float rayo = exp(-pow((UV.x - baston_u) * aspecto * 2.5, 2.0));
	sin_sol += vec3(0.20, 0.18, 0.15) * rayo;
	c = mix(sin_sol, c, sol);
	vec2 d = (UV - sol_uv) * vec2(aspecto, 1.0);
	c += vec3(0.95, 0.62, 0.34) * exp(-dot(d, d) * 7.0) * 0.32 * sol;
	COLOR = vec4(c * luz, 1.0);
}
