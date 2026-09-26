shader_type canvas_item;
render_mode blend_add;
// Fuego de la chimenea (y las lenguas bajas del brasero) sin hojas de
// fotogramas: dos capas de ruido que suben a distinto ritmo deforman una gota.
// Va en modo aditivo sobre el hogar negro, asi que no necesita recorte: donde
// no hay fuego suma cero.
//
// El sprite que lo lleva usa ruido_fuego.png como textura solo para tener
// tamano; el ruido que cuenta es el uniform (que se repite en x e y, generado
// en tools/mundo/casa_interior.py).

uniform sampler2D ruido : repeat_enable, filter_linear;
uniform float velocidad = 0.45;
uniform float intensidad = 1.0;
// 0 = una sola gota (chimenea); 1 = franja plana de lenguas bajas (brasero)
uniform float plano : hint_range(0.0, 1.0) = 0.0;
uniform float altura : hint_range(0.2, 1.5) = 0.62;
uniform vec4 color_borde : source_color = vec4(0.62, 0.16, 0.03, 1.0);
uniform vec4 color_medio : source_color = vec4(0.98, 0.5, 0.14, 1.0);
uniform vec4 color_nucleo : source_color = vec4(1.0, 0.8, 0.5, 1.0);
// Desfase para que dos fuegos con el mismo material no vayan a la par
uniform float semilla = 0.0;

void fragment() {
	float t = TIME * velocidad + semilla;
	float y = 1.0 - UV.y;                       // 0 abajo, 1 arriba
	float x = (UV.x - 0.5) * 2.0;               // -1 .. 1
	float n1 = texture(ruido, vec2(UV.x * 0.8 + semilla, UV.y * 0.6 + t)).r;
	float n2 = texture(ruido, vec2(UV.x * 1.9 + 0.31, UV.y * 1.3 + t * 1.7)).r;
	float n = n1 * 0.62 + n2 * 0.38;
	// La gota se estrecha hacia arriba; en modo plano el perfil es casi recto
	float ancho = mix((1.0 - y) * 0.85 + 0.15, 1.0, plano);
	float perfil = mix(1.0 - abs(x) / ancho, 1.0 - pow(abs(x), 5.0), plano);
	// Lenguas: franjas que suben mas que sus vecinas y se desplazan despacio,
	// para que no sea una sola gota que late.
	float lenguas = sin(x * 7.5 + n1 * 3.0 + t * 1.3) * 0.5 + 0.5;
	float campo = perfil - y / (altura * (0.72 + 0.45 * lenguas)) + (n - 0.5) * (1.0 + 0.7 * y);
	float a = smoothstep(0.0, 0.32, campo);
	float nucleo = smoothstep(0.38, 0.85, campo);
	vec3 col = mix(color_borde.rgb, color_medio.rgb, smoothstep(0.0, 0.5, a));
	col = mix(col, color_nucleo.rgb, nucleo);
	// asentado en los lenos: sin corte duro abajo
	a *= smoothstep(0.0, 0.1, y);
	COLOR = vec4(col * intensidad, a);
}
