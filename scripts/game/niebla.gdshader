shader_type canvas_item;
// Banda de niebla entre capas: una franja horizontal pegada al suelo, con
// manchas que derivan despacio. El color y la densidad los pone bosque.gd
// segun la hora.
//
// Todo se calcula en coordenadas de PANTALLA (SCREEN_UV), no del rectangulo:
// asi el ColorRect puede ocupar solo la franja que pinta en vez de la pantalla
// entera. Cada niebla de pantalla completa costaba un relleno entero por
// fotograma para dejar transparente mas de la mitad.

uniform vec4 color_niebla : source_color = vec4(0.94, 0.79, 0.68, 1.0);
uniform float densidad : hint_range(0.0, 1.0) = 0.25;
// Centro y medio alto de la franja, en UV de pantalla.
uniform float centro_y = 0.7;
uniform float medio_alto = 0.3;
uniform sampler2D manchas : repeat_enable, filter_linear_mipmap;
// Desplazamiento por la camara (su x por el factor de la capa, en UV).
uniform float desplaza = 0.0;
uniform float deriva = 0.004;   // UV por segundo que se mueve sola

void fragment() {
	vec2 uv = SCREEN_UV;
	float banda = clamp(1.0 - abs(uv.y - centro_y) / medio_alto, 0.0, 1.0);
	banda = banda * banda * (3.0 - 2.0 * banda);
	float n = texture(manchas, uv * vec2(1.3, 0.6) + vec2(desplaza + TIME * deriva, 0.0)).r;
	float n2 = texture(manchas, uv * vec2(2.7, 1.1) + vec2(desplaza * 1.3 - TIME * deriva * 0.7, 0.5)).r;
	float a = banda * densidad * (0.45 + 0.4 * n + 0.3 * n2);
	COLOR = vec4(color_niebla.rgb, clamp(a, 0.0, 1.0));
}
