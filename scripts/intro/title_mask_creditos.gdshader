shader_type canvas_item;
// Mascara del titulo mientras salen los creditos. Con todo apagado (sin velas,
// ni foco, ni vaho, ni destello), title_reveal.gdshader da el mismo negro en
// cada pixel; este da ese mismo valor, con las mismas operaciones, sin pagar el
// shader entero por pixel. El controlador lo pone al arrancar con creditos y
// vuelve a title_reveal en _start_lights, cuando aun esta todo a 0.
render_mode unshaded, blend_premul_alpha;

uniform float darkness : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// title_reveal con light = 0, fog = 0 y add = 0.
	float dark = clamp(1.0 - (1.0 - clamp(1.0, 0.0, 1.0) * darkness), 0.0, 1.0);
	COLOR = vec4(vec3(0.0), 1.0 - (1.0 - dark));
}
