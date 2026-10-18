shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Llamita de vela para la interfaz: las dos que flanquean la opcion elegida de
// los menus (como las velas del titulo). vida 0..1: apagada .. encendida.
// Hecha como una vela de verdad (2026-10-18; la de antes "no terminaba de
// molar"): gota redonda abajo y afilada arriba, mecida por una turbulencia que
// sube por ella y no por un seno; capas de color de vela (azulada junto a la
// mecha, el cono de dentro algo mas apagado, nucleo blanco-amarillo y la
// envolvente naranja que se enrojece hacia la punta), un resplandor suave, y la
// mecha oscura con su brasa. Premultiplicado: la luz suma y solo la mecha tapa.
uniform float vida = 0.0;
uniform float semilla = 0.0;
// Ancho / alto del rectangulo (el de menu_base: 46 x 76).
uniform float aspecto = 0.605;

// Ondas que no casan entre si: parecen azar y son suaves (un ruido de rejilla
// daba saltos en la llama en cada celda).
float ondas(float x, float s) {
	return sin(x + s) * 0.5 + sin(x * 1.83 + s * 2.1 + 1.3) * 0.3 + sin(x * 3.27 + s * 0.7 + 4.1) * 0.2;
}

void fragment() {
	float t = TIME + semilla;
	// En alturas del rectangulo: x centrada, y hacia arriba desde la mecha.
	float x = (UV.x - 0.5) * aspecto;
	float y = 0.86 - UV.y;

	// Alto de la llama: crece con vida; respira despacio y a veces se estira.
	float respira = ondas(t * 2.3, semilla);
	float estira = smoothstep(0.55, 0.95, ondas(t * 1.1, semilla + 7.0)) * 0.1;
	float h = mix(0.15, 0.5, vida) * (1.0 + respira * 0.07 + estira);
	float v = y / h;

	// Se mece: turbulencia que sube por la llama (mas arriba, mas), y un
	// vaiven lento de toda ella.
	float alto = clamp(v, 0.0, 1.0);
	float turb = ondas(v * 4.0 - t * 3.2, semilla + t * 0.4) * 0.045 * alto * alto;
	float vaiven = sin(t * 1.3 + semilla) * 0.012 * alto;
	float xs = x - turb - vaiven;

	// Gota: redonda abajo, afilada arriba (el ancho mayor hacia un tercio).
	float vv = clamp(v, 0.0, 1.0);
	float ancho = 0.17 * pow(vv, 0.42) * pow(1.0 - vv, 0.75) * mix(0.7, 1.0, vida) + 0.002;
	float d = abs(xs) / ancho;
	float abajo = smoothstep(-0.04, 0.05, v);
	float punta = 1.0 - smoothstep(0.82, 1.0, v);

	float envolvente = (1.0 - smoothstep(0.5, 1.05, d)) * abajo * punta;
	float nucleo = (1.0 - smoothstep(0.0, 0.6, d)) * smoothstep(0.1, 0.28, v) * (1.0 - smoothstep(0.3, 0.72, v));
	float azul = (1.0 - smoothstep(0.35, 1.0, d)) * smoothstep(-0.03, 0.02, v) * (1.0 - smoothstep(0.02, 0.17, v));
	// El cono de dentro, sobre la mecha, luce menos.
	float cono = (1.0 - smoothstep(0.0, 0.55, d)) * (1.0 - smoothstep(0.04, 0.24, v)) * smoothstep(-0.02, 0.03, v);

	vec3 naranja = mix(vec3(1.0, 0.5, 0.12), vec3(0.85, 0.22, 0.05), smoothstep(0.45, 1.0, v));
	vec3 luz = naranja * envolvente * 0.95
		+ vec3(1.0, 0.9, 0.68) * nucleo * 1.05
		+ vec3(0.22, 0.4, 1.0) * azul * 0.45;
	luz *= 1.0 - cono * 0.45;
	// el borde de la envolvente, un punto mas encendido (la llama se lee nitida)
	luz += naranja * exp(-pow((d - 0.82) / 0.12, 2.0)) * abajo * punta * smoothstep(0.15, 0.5, v) * 0.18;

	// Resplandor alrededor, que no llega al borde del rectangulo.
	vec2 c = vec2(x / 0.7, (y - h * 0.38) / 1.0);
	float resplandor = exp(-dot(c, c) / (0.012 + 0.03 * vida));
	float borde = (1.0 - smoothstep(0.62, 0.98, abs(UV.x - 0.5) * 2.0))
		* (1.0 - smoothstep(0.75, 1.0, abs(UV.y - 0.5) * 2.0));
	luz += vec3(1.0, 0.55, 0.2) * resplandor * 0.16 * borde;

	// La mecha: un palito oscuro, con la brasa en la punta.
	float mecha = (1.0 - smoothstep(0.006, 0.011, abs(x - vaiven * 0.3)))
		* smoothstep(-0.07, -0.055, y) * (1.0 - smoothstep(0.0, 0.012, y));
	float brasa = exp(-(x * x + pow(y - 0.004, 2.0)) / 0.00005);
	float va = mecha * 0.85 * clamp(vida * 3.0, 0.0, 1.0);

	// A medio prender es mas pequena, no mas parda: el brillo apenas baja.
	float encendida = smoothstep(0.0, 0.25, vida) * mix(0.75, 1.0, vida);
	vec3 rgb = luz * encendida + vec3(1.0, 0.35, 0.1) * brasa * 0.6 * encendida;
	COLOR = vec4(vec3(0.05, 0.03, 0.02) * va + rgb * (1.0 - va), va);
}
