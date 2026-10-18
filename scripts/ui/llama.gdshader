shader_type canvas_item;
render_mode blend_add;
// Una llamita de vela pintada por cuentas, para la interfaz: la marca de
// guardado y las que flanquean la opcion elegida de los menus (como las dos
// velas del titulo). vida 0..1: apagada .. encendida del todo.
uniform float vida = 0.0;
uniform float semilla = 0.0;

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * 2.0, 1.0 - UV.y);
	float t = TIME + semilla;
	// La llama crece al prender y se encoge al apagarse; respira siempre un poco.
	float h = mix(0.25, 0.86, vida) * (0.93 + 0.05 * sin(t * 7.3) + 0.03 * sin(t * 13.1));
	// Se cimbrea mas cuanto mas arriba.
	float x = p.x - (sin(t * 5.3 + p.y * 4.0) * 0.6 + sin(t * 9.1 + p.y * 7.0) * 0.4) * 0.11 * p.y;
	float y = p.y - 0.12;
	float sube = smoothstep(0.0, 0.16, y) * (1.0 - smoothstep(h * 0.45, h, y));
	float ancho = 0.34 * smoothstep(-0.02, 0.2, y) * (1.0 - smoothstep(0.08, h, y)) + 0.015;
	float llama = exp(-(x * x) / (ancho * ancho) * 1.6) * sube;
	float nucleo = exp(-(x * x) / (ancho * ancho) * 6.0) * smoothstep(0.02, 0.12, y) * (1.0 - smoothstep(h * 0.2, h * 0.6, y));
	vec2 c = vec2(x, (y - h * 0.32) * 0.9);
	// El halo se apaga antes de los bordes del rectangulo, que si no se ve.
	float borde = (1.0 - smoothstep(0.55, 0.95, abs(p.x))) * smoothstep(0.0, 0.12, p.y) * (1.0 - smoothstep(0.75, 0.98, p.y));
	float halo = exp(-dot(c, c) * 14.0) * 0.2 * borde;
	vec3 col = vec3(1.0, 0.5, 0.13) * llama + vec3(1.0, 0.86, 0.6) * nucleo * 0.9 + vec3(1.0, 0.6, 0.25) * halo;
	COLOR = vec4(col * vida, 1.0);
}
