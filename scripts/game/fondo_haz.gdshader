shader_type canvas_item;
render_mode blend_disabled;
// Fondo de la caida en la hojarasca: oscuridad calida con un haz de luz que baja
// sobre el sitio donde cae el peregrino, niebla que se arrastra despacio y el resplandor
// del suelo, como la luz de la imagen de titulo. Todo bajo: el negro manda.
// Se calcula a 1/4 de resolucion y se estira (caida_hojarasca.gd): es todo
// degradado blando y a resolucion completa costaba la mitad de los FPS.
//
// LA LUZ DEL BOSQUE (bosque_fondo.gdshader, que lee esta imagen y le suma el
// bosque) se calcula tambien aqui y va en el alfa: lo que le da el haz, entre
// LUZ_BOSQUE (sin blend, el alfa se escribe tal cual). Es un degradado blando
// y a 1/4 sale igual; en el bosque, a resolucion completa, eran 1,4 ms
// (2026-10-14). Sin el bosque el alfa no se usa (no hay nada debajo).

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
// Cuanta luz da el haz al bosque: de mas dentro del cono y de mas junto a
// donde pega en el suelo (caida_hojarasca.gd las baja al apagarse el haz).
uniform float bosque_en_el_haz = 1.4;
uniform float bosque_resplandor = 1.6;
uniform vec2 bosque_resplandor_tam = vec2(900.0, 420.0);
const float LUZ_BOSQUE = 4.0;  // la misma en bosque_fondo.gdshader
// EL HAZ SE RETIRA (2026-10-14, al coger el baculo): de 0 a 1 la luz se recoge
// de abajo arriba hacia el cielo; por debajo del corte, el claro a oscuras (el
// haz, su niebla, el resplandor del suelo y lo que le da al bosque).
uniform float retiro : hint_range(0.0, 1.0) = 0.0;

// Ruido de valor: un valor al azar en cada punto de la reticula, fundido con
// suavidad entre los cuatro de alrededor. Los valores se leen de una imagen
// (ruido_valor.png, raw/master_mason/hojarasca_bosque/ruido_valor.py): con el
// filtro lineal, leyendo en i + u, la grafica funde los cuatro en una lectura
// (2026-10-14; antes eran cuatro hashes de seno por octava, 60 senos por pixel,
// y el fondo costaba 5 ms aun a 1/4).
uniform sampler2D azar : filter_linear, repeat_enable;
float ruido(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return textureLod(azar, (i + u + 0.5) / 256.0, 0.0).r;
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
	// EL HAZ SE RETIRA: por debajo del corte (que sube con retiro) no queda.
	float corte = mix(pantalla.y + 300.0, haz_origen.y - 300.0, retiro);
	float queda = 1.0 - smoothstep(corte - 280.0, corte, px.y);
	float luz = haz * rayos * (0.35 + 0.65 * bajada) * haz_fuerza * queda;
	// el filo de abajo, al recogerse, brilla: la luz se va tirando de ella
	float filo = smoothstep(corte - 520.0, corte - 300.0, px.y) * (1.0 - smoothstep(corte - 300.0, corte - 120.0, px.y));
	luz += haz * rayos * haz_fuerza * filo * 1.3 * smoothstep(0.0, 0.08, retiro) * (1.0 - smoothstep(0.75, 1.0, retiro));
	// Niebla: capas de ruido que se arrastran, mas densa abajo y en el haz.
	vec2 q = px / 520.0;
	float n = fbm(q + vec2(t * 0.012, t * 0.004)) * fbm(q * 1.7 - vec2(t * 0.02, 0.0));
	float abajo = smoothstep(500.0, y_suelo, px.y);
	// (la niebla y el resplandor del suelo, al retirarse, se quedan en algo)
	float poso = mix(0.35, 1.0, queda);
	luz += n * niebla_fuerza * (0.25 + 0.75 * abajo) * (0.3 + 0.7 * haz) * poso;
	// Resplandor del suelo donde pega el haz.
	vec2 e = (px - haz_destino) / vec2(950.0, 210.0);
	luz += exp(-dot(e, e) * 1.4) * 0.11 * poso;
	// Vineta.
	vec2 c = UV - vec2(0.5, 0.55);
	float vin = 1.0 - 0.6 * dot(c, c) * 2.2;
	vec3 col = color_fondo * vin + color_luz * luz;
	// El grano lo pone el pase final (aqui, a 1/4 de resolucion, saldria a bloques).
	float cono = 1.0 - smoothstep(haz_apertura * 0.5, haz_apertura * 1.8, a);
	vec2 e2 = (px - haz_destino) / bosque_resplandor_tam;
	float luz_bosque = (bosque_en_el_haz * cono + bosque_resplandor * exp(-dot(e2, e2) * 1.2)) * queda;
	COLOR = vec4(col, clamp(luz_bosque / LUZ_BOSQUE, 0.0, 1.0));
}
