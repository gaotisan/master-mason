shader_type canvas_item;
// Lente del giro de cabeza en el ataud (ataud_camara.gd). Girar es deslizar
// una imagen plana; esto le da la sensacion de cabeza que gira:
//  - proyeccion cilindrica aproximada: los bordes se agrandan un poco y las
//    horizontales se curvan, mas cuanto mas girada esta la cabeza;
//  - el lado hacia el que se gira crece (como un plano que se ve de lado);
//  - estela horizontal mientras gira deprisa.
// Solo amplia (lee hacia el centro), asi que nunca necesita nada de fuera de
// la pantalla. Solo esta visible mientras la cabeza no esta en la ventana:
// leer la pantalla cuesta una copia.

uniform sampler2D pantalla : hint_screen_texture, filter_linear, repeat_disable;
// Seno del angulo de giro (con signo: + derecha).
uniform float giro = 0.0;
// Velocidad del giro, en fraccion de pantalla por fotograma.
uniform float estela = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float u = uv.x * 2.0 - 1.0;
	float v = uv.y * 2.0 - 1.0;
	float g = abs(giro);
	// Cilindro: bordes mas grandes (en vertical, un pelo en horizontal).
	float sy = 1.0 + 0.11 * g * u * u;
	// El lado hacia el que se gira, mas grande.
	sy += 0.16 * g * max(0.0, sign(giro) * u);
	float sx = 1.0 + 0.04 * g * u * u;
	vec2 fuente = vec2(u / sx, v / sy) * 0.5 + 0.5;

	vec3 c;
	if (abs(estela) > 0.0005) {
		c = vec3(0.0);
		for (int i = 0; i < 7; i++) {
			float k = float(i) / 6.0 - 0.5;
			c += texture(pantalla, fuente + vec2(estela * k, 0.0)).rgb;
		}
		c /= 7.0;
	} else {
		c = texture(pantalla, fuente).rgb;
	}
	COLOR = vec4(c, 1.0);
}
