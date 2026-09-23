shader_type canvas_item;
// Letras de los creditos, contadas con luz como todo lo demas de la pantalla:
// el texto esta ahi en la oscuridad y una luz lo recorre de izquierda a derecha,
// como una vela que alguien lleva por delante. La cabeza del charco (head)
// enciende las letras al pasar y la cola (tail) las vuelve a dejar a oscuras.
// Justo en el frente hay un poco de brillo de mas, el mismo destello que luego
// recorre las letras del titulo.
render_mode unshaded;

// Posicion 0..1 a lo ancho del Label. Fuera de [0,1] la luz aun no ha llegado
// o ya se ha ido del todo.
uniform float head = -0.6;
uniform float tail = -0.9;
uniform float softness : hint_range(0.01, 1.0) = 0.3;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float width = 1000.0;
uniform vec3 glint_color = vec3(1.0, 0.92, 0.7);
uniform float glint_strength : hint_range(0.0, 1.0) = 0.3;

varying float xn;

void vertex() {
	xn = VERTEX.x / max(width, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lit = smoothstep(tail - softness, tail + softness, xn)
		* (1.0 - smoothstep(head - softness, head + softness, xn));
	// Brillo en el frente de la luz, sobre la letra ya encendida.
	float band = exp(-pow((xn - head + softness * 0.5) / (softness * 0.6), 2.0));
	vec3 rgb = c.rgb + glint_color * band * glint_strength * lit;
	COLOR = vec4(rgb, c.a * lit * fade);
}
