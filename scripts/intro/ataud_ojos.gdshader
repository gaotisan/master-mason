shader_type canvas_item;
// Lo que va delante de todo en el ataud (prueba 2026-10-22), en una pasada:
//  - los parpados, que se abren al despertar (apertura 0 = cerrados);
//  - grano de pelicula por encima de todo, para que las piezas sueltas
//    (cucaracha, mano, moscas) casen con el fondo pintado.
// No lee la pantalla: el grano aclara u oscurece mezclando hacia blanco o negro.

uniform float apertura : hint_range(0.0, 1.0) = 1.0;
uniform float grano : hint_range(0.0, 0.2) = 0.045;
uniform vec2 tam = vec2(2912.0, 1632.0);
// Golpe de dolor: los bordes se oscurecen un momento.
uniform float dolor = 0.0;

float azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	// Parpados: cerrados, la linea queda por debajo del centro; el de arriba
	// sube y hace casi todo el recorrido, el de abajo apenas baja. Borde curvo
	// (mas abiertos en el centro), blando, con una franja de sombra de
	// pestanas. Abiertos del todo no tapan ni las esquinas.
	float x = (uv.x - 0.5) * 2.0;
	float ab = apertura;
	float ai = clamp(apertura * 2.2, 0.0, 1.0);
	float arriba = 0.63 - ab * 0.9 * (1.0 - 0.28 * x * x) - pow(ab, 4.0) * 0.3;
	float abajo = 0.63 + ai * 0.22 * (1.0 - 0.3 * x * x) + pow(ai, 4.0) * 0.3;
	float cerrado = 1.0 - smoothstep(arriba - 0.02, arriba + 0.07, uv.y);
	cerrado = max(cerrado, smoothstep(abajo - 0.05, abajo + 0.015, uv.y));
	// Sombra de pestanas, solo con los ojos a medio abrir.
	float pestanas = (1.0 - smoothstep(arriba + 0.05, arriba + 0.14, uv.y)) * (1.0 - ab) * 0.55;
	cerrado = max(cerrado, pestanas);
	cerrado = max(cerrado, 1.0 - smoothstep(0.0, 0.05, apertura));
	if (dolor > 0.0) {
		float borde = length((uv - 0.5) * vec2(1.0, 1.25));
		cerrado = max(cerrado, smoothstep(0.32, 0.75, borde) * dolor * 0.6);
	}

	// Grano: cambia 24 veces por segundo, a grano de 2 px de la pantalla.
	float f = floor(TIME * 24.0);
	vec2 celda = floor(uv * tam * 0.5);
	float n = azar(celda + vec2(f * 17.0, f * 31.0)) - 0.5;
	float g = abs(n) * 2.0 * grano;
	vec3 tono = n > 0.0 ? vec3(1.0, 0.96, 0.9) : vec3(0.0);

	float a = cerrado + g * (1.0 - cerrado);
	vec3 c = (tono * g * (1.0 - cerrado)) / max(a, 0.0001);
	COLOR = vec4(c, a);
}
