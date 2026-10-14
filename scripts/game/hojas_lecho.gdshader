shader_type canvas_item;
// Las hojas posadas del lecho (hojas_voladoras.gd), todas en un MultiMesh por
// capa: cada instancia es una hoja (su transformada, su color con la luz y la
// sombra ya puestas) y en su dato propio lleva la celda del atlas (x) y lo que
// queda de su luz sin el haz (y, fraccion: 0,28 / su luz). luz_viva lleva de
// la luz entera (1) a la del claro a oscuras (0), sin repintar ninguna hoja.

uniform float luz_viva : hint_range(0.0, 1.0) = 1.0;

varying vec4 color_hoja;
varying float oscura;

void vertex() {
	float celda = INSTANCE_CUSTOM.x;
	vec2 cr = vec2(mod(celda, 8.0), floor(celda / 8.0 + 0.001));
	UV = (cr + UV) / vec2(8.0, 4.0);
	color_hoja = COLOR;
	oscura = INSTANCE_CUSTOM.y;
}

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(t.rgb * color_hoja.rgb * mix(oscura, 1.0, luz_viva), t.a * color_hoja.a);
}
