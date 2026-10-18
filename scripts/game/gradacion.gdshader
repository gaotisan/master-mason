shader_type canvas_item;
render_mode blend_premul_alpha;
// Pase final de la escena de la hojarasca, encima de todo. Sin leer la pantalla
// (copiarla entera cada fotograma a 2912x1632 bajaba el portatil de 25 a 15
// FPS): con alfa premultiplicado, en una sola pasada,
//   pantalla * (1 - vineta) + (tono de sombras + grano)
// - Vineta: oscurece bordes y abajo, menos arriba, donde esta el haz.
// - Tono: un pardo calido sumado muy bajo; en los negros se nota (no hay negro
//   puro) y en las luces no.
// - Grano fino, que ademas evita bandas en los degradados oscuros.
// Todo flojo: si se nota el efecto, sobra.
// - Tunel (EL CLARO SE CIERRA, caida_hojarasca.gd): con el claro cerrado, los lados
//   del bosque se van a oscuro y solo queda vivo el pasillo del camino (tunel_x, en
//   UV de pantalla): asi no queda un horizonte que parezca jugable.

uniform vec3 sombras : source_color = vec3(0.022, 0.013, 0.006);
uniform float vineta = 0.4;
uniform float grano = 0.02;
uniform float tunel : hint_range(0.0, 1.0) = 0.0;
uniform float tunel_x = 0.84;
uniform float tunel_ancho = 0.13;
uniform float tunel_fuerza = 0.88;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 c = UV - vec2(0.5, 0.46);
	c.x *= 1.25;
	float v = vineta * smoothstep(0.18, 0.75, dot(c, c) * 2.0);
	float t = (UV.x - tunel_x) / tunel_ancho;
	v = max(v, tunel * tunel_fuerza * (1.0 - exp(-t * t)));
	float g = (hash(UV * 1000.0 + fract(TIME * 7.0)) - 0.5) * grano;
	COLOR = vec4(max(sombras + vec3(g), vec3(0.0)), v);
}
