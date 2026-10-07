shader_type canvas_item;
// Fondo de la caida en la hojarasca: oscuridad calida con un haz de luz que baja
// sobre el sitio donde cae Magnus, niebla que se arrastra despacio y el resplandor
// del suelo, como la luz de la imagen de titulo. Todo bajo: el negro manda.
// Se calcula a 1/4 de resolucion y se estira (caida_hojarasca.gd): es todo
// degradado blando y a resolucion completa costaba la mitad de los FPS.

uniform vec2 pantalla = vec2(2912.0, 1632.0);
// Vertice del haz (por encima de la pantalla) y punto del suelo al que apunta.
uniform vec2 haz_origen = vec2(1620.0, -700.0);
uniform vec2 haz_destino = vec2(1456.0, 1200.0);
uniform float haz_apertura = 0.17;      // semiangulo (rad)
uniform float haz_fuerza = 0.16;
uniform float y_suelo = 1200.0;
uniform vec3 color_fondo : source_color = vec3(0.035, 0.022, 0.012);
uniform vec3 color_luz : source_color = vec3(1.0, 0.70, 0.36);
uniform float niebla_fuerza = 0.07;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) { s += a * ruido(p); p *= 2.03; a *= 0.5; }
	return s;
}

void fragment() {
	vec2 px = UV * pantalla;
	float t = TIME;
	// Haz: angulo respecto al eje origen->destino, borde blando.
	vec2 eje = normalize(haz_destino - haz_origen);
	vec2 d = px - haz_origen;
	float a = acos(clamp(dot(normalize(d), eje), -1.0, 1.0));
	float haz = 1.0 - smoothstep(haz_apertura * 0.35, haz_apertura, a);
	// Rayos: franjas por angulo que se mueven muy despacio.
	float lado = dot(normalize(d), vec2(eje.y, -eje.x));
	float rayos = 0.65 + 0.35 * fbm(vec2(lado * 26.0, t * 0.05));
	// Se va encendiendo hacia abajo y se apaga justo al llegar al suelo.
	float bajada = smoothstep(-200.0, y_suelo, px.y) * (1.0 - smoothstep(y_suelo - 40.0, y_suelo + 160.0, px.y));
	float luz = haz * rayos * (0.35 + 0.65 * bajada) * haz_fuerza;
	// Niebla: capas de ruido que se arrastran, mas densa abajo y en el haz.
	vec2 q = px / 520.0;
	float n = fbm(q + vec2(t * 0.012, t * 0.004)) * fbm(q * 1.7 - vec2(t * 0.02, 0.0));
	float abajo = smoothstep(500.0, y_suelo, px.y);
	luz += n * niebla_fuerza * (0.25 + 0.75 * abajo) * (0.3 + 0.7 * haz);
	// Resplandor del suelo donde pega el haz.
	vec2 e = (px - haz_destino) / vec2(950.0, 210.0);
	luz += exp(-dot(e, e) * 1.4) * 0.11;
	// Vineta.
	vec2 c = UV - vec2(0.5, 0.55);
	float vin = 1.0 - 0.6 * dot(c, c) * 2.2;
	vec3 col = color_fondo * vin + color_luz * luz;
	// El grano lo pone el pase final (aqui, a 1/4 de resolucion, saldria a bloques).
	COLOR = vec4(col, 1.0);
}
