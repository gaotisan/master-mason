shader_type canvas_item;
// Vista sin enfocar al despertar en el ataud (ataud_camara.gd): desenfoca la
// pantalla entera, marco y piezas sueltas incluidas. Solo esta visible
// mientras dura; leer la pantalla cuesta una copia.

uniform sampler2D pantalla : hint_screen_texture, filter_linear_mipmap;
// Nivel de mipmap de la pantalla.
uniform float nivel = 0.0;

void fragment() {
	vec2 r = SCREEN_PIXEL_SIZE * exp2(nivel) * 0.45;
	vec3 c = (textureLod(pantalla, SCREEN_UV + vec2(r.x, r.y * 0.4), nivel).rgb
		+ textureLod(pantalla, SCREEN_UV + vec2(-r.x * 0.4, r.y), nivel).rgb
		+ textureLod(pantalla, SCREEN_UV + vec2(-r.x, -r.y * 0.4), nivel).rgb
		+ textureLod(pantalla, SCREEN_UV + vec2(r.x * 0.4, -r.y), nivel).rgb) * 0.25;
	COLOR = vec4(c, 1.0);
}
