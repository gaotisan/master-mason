shader_type canvas_item;
// Agua del abismo: el vacio no era nada, era agua a oscuras. Refleja en espejo
// lo que hay encima del horizonte (el sol, el arco, el peregrino, sus losas),
// con un temblor leve y oscureciendose con la profundidad. Sin luz no hay nada
// que reflejar y es negro puro: el vacio del principio.
//
// Va en un ColorRect desde el horizonte hasta abajo, dibujado despues de todo
// lo que tiene que reflejarse (z_index alto).

uniform sampler2D pantalla : hint_screen_texture, filter_linear;
uniform float horizonte_uv = 0.7047;
uniform float presencia : hint_range(0.0, 1.0) = 0.0;
uniform vec3 fondo : source_color = vec3(0.020, 0.024, 0.034);
uniform vec3 tinte : source_color = vec3(0.80, 0.74, 0.68);

void fragment() {
	float d = max(SCREEN_UV.y - horizonte_uv, 0.0);
	float ry = horizonte_uv - d;
	// Temblor horizontal: casi nada junto al horizonte, algo mas al fondo.
	float onda = sin(SCREEN_UV.y * 320.0 - TIME * 1.2) * 0.00045 * (0.15 + d * 6.0)
		+ sin(SCREEN_UV.y * 95.0 + TIME * 0.5) * 0.0003 * (0.3 + d * 3.0);
	vec3 refl = texture(pantalla, vec2(SCREEN_UV.x + onda, ry)).rgb;
	float cerca = clamp(1.0 - d * 2.2, 0.18, 1.0);
	vec3 c = mix(fondo, refl * tinte, cerca * 0.82);
	// Lo muy claro (el sol) brilla algo mas en el agua.
	c += refl * smoothstep(0.80, 0.95, max(refl.r, refl.g)) * 0.25 * cerca;
	// Bandas de agua muy suaves, mas juntas cerca del horizonte (perspectiva) y
	// rotas a lo ancho para que no parezcan lineas de pantalla.
	float banda = sin(7.0 / (d + 0.015) - TIME * 0.8 + sin(SCREEN_UV.x * 9.0 + TIME * 0.3) * 1.5);
	c *= 1.0 + 0.022 * banda * smoothstep(0.0, 0.01, d);
	// Una linea de superficie muy fina en el horizonte.
	c += vec3(0.10, 0.08, 0.06) * smoothstep(0.004, 0.0, d);
	COLOR = vec4(c * presencia, 1.0);
}
