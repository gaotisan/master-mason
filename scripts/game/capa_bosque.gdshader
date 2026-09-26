shader_type canvas_item;
// Capa de arboles del bosque (mascara blanca que se tinta con modulate).
//
// El bosque tiene bordes: empieza pasado el claro del principio y se abre
// alrededor de la casa. Como las capas se repiten (Parallax2D), el borde no se
// puede pintar en la hoja: se calcula aqui. Para cada pixel se mira en que
// posicion de camara quedaria centrado ese punto de la capa,
//     aparente = camara_x + (x_pantalla - mitad) / escala
// y se compara con el tramo del mundo donde hay bosque. Sale un borde con su
// paralaje correcto: en las capas lejanas asoma antes y se mueve despacio.

uniform float escala = 1.0;          // scroll_scale.x de la capa
uniform float camara_x = 0.0;        // centro de la camara en el mundo (bosque.gd, cada fotograma)
uniform float inicio = -100000.0;    // x del mundo donde empieza el bosque de esta capa
uniform float fin = 100000.0;        // x del mundo donde se abre (el claro de la casa)
uniform float difuminado = 450.0;
uniform float ancho_pantalla = 2912.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float sx = SCREEN_UV.x * ancho_pantalla;
	float aparente = camara_x + (sx - ancho_pantalla * 0.5) / max(escala, 0.001);
	float m = smoothstep(inicio - difuminado, inicio + difuminado, aparente)
			* (1.0 - smoothstep(fin - difuminado, fin + difuminado, aparente));
	c.a *= m;
	COLOR = c;
}
