shader_type canvas_item;
render_mode unshaded;
// La mano del golpe en el ataud (ataud_camara.gd). La unica luz entra por la
// ventana, delante y arriba a la izquierda de la mano: va a contraluz, con los
// nudillos (hacia la luz) algo iluminados y el antebrazo en sombra, un borde de
// luz fino solo en los cantos que miran a la ventana (por dentro de la
// silueta: si rodea todo parece una pegatina), y estela al lanzarse.
// El sprite lleva relleno transparente alrededor (region mas grande que la
// textura) para que la estela no se corte en el borde.

// Estela: lo que se ha movido la mano en este fotograma, en px de la textura.
uniform vec2 estela = vec2(0.0);
// Cuanto se oscurece (1 = como esta pintada).
uniform float luz = 0.55;
uniform vec3 tinte = vec3(0.9, 0.82, 0.8);
uniform vec3 color_borde = vec3(1.0, 0.74, 0.52);
uniform float borde = 0.55;
// Hacia donde esta la luz (la ventana), en la pantalla.
uniform vec2 hacia_luz = vec2(-0.4, -1.0);

varying vec4 vcolor;

void vertex() {
	vcolor = COLOR;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	// Estela: media a lo largo del movimiento (en premultiplicado).
	vec4 c;
	if (dot(estela, estela) > 4.0) {
		c = vec4(0.0);
		for (int i = 0; i < 9; i++) {
			float k = float(i) / 8.0 - 0.5;
			vec4 m = texture(TEXTURE, UV - estela * px * k);
			c += vec4(m.rgb * m.a, m.a);
		}
		c /= 9.0;
	} else {
		c = texture(TEXTURE, UV);
		c.rgb *= c.a;
	}
	vec3 rgb = c.a > 0.001 ? c.rgb / c.a : vec3(0.0);

	// Contraluz: oscura, algo desaturada y con mas contraste; los nudillos
	// (arriba) reciben algo de luz y el antebrazo (abajo) se hunde en sombra.
	float gris = dot(rgb, vec3(0.3, 0.55, 0.15));
	rgb = pow(mix(vec3(gris), rgb, 0.75), vec3(1.15)) * tinte * luz;
	rgb *= mix(1.25, 0.5, smoothstep(0.1, 1.0, UV.y));

	// Borde de luz: donde el alfa cae hacia fuera, solo del lado de la luz.
	float r = 5.0;
	float ax = texture(TEXTURE, UV + vec2(px.x * r, 0.0)).a - texture(TEXTURE, UV - vec2(px.x * r, 0.0)).a;
	float ay = texture(TEXTURE, UV + vec2(0.0, px.y * r)).a - texture(TEXTURE, UV - vec2(0.0, px.y * r)).a;
	vec2 g = vec2(ax, ay);
	float canto = clamp(length(g), 0.0, 1.0);
	vec2 fuera = canto > 0.01 ? -normalize(g) : vec2(0.0);
	float cara = smoothstep(0.1, 0.9, dot(fuera, normalize(hacia_luz)));
	rgb += color_borde * canto * cara * cara * borde * smoothstep(0.55, 1.0, c.a);

	COLOR = vec4(rgb, c.a) * vcolor;
}
