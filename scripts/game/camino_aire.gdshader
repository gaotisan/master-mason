shader_type canvas_item;
// Aire del camino del bosque. No se ve directamente: se pinta en una
// SubViewport a 1/4 de resolucion (es todo blando) y el shader del fondo
// (camino_fondo.gdshader) lo aplica sobre la imagen. Un campo por canal:
//   R  niebla: cuanto tapa (0..1); el color lo pone el fondo segun la luz
//   G  rayos: haces de luz y de sombra con signo (0,5 = nada)
//   B  luz: el resplandor sube o baja, con signo (0,5 = nada)
//
// La niebla no difumina la imagen (eso se leia como un blur): es luz dispersa
// con forma propia. Jirones con huecos entre ellos (ruido "billow" deformado,
// mas ancho que alto, como los bancos de niebla) en capas a distinta distancia;
// cada capa solo tapa lo que esta detras de ella (el mapa de profundidad), asi
// pasa entre los troncos cercanos y no por delante. Cada capa con su viento (lo
// integra camino_bosque.gd: las rachas la aceleran sin saltos) y su paralaje
// con la camara.
//   - Fondo: bancos en el pasillo de luz, lentos.
//   - Media: entre los troncos.
//   - Cerca: jirones finos por delante de todo, mas rapidos.
//   - Rasante: tumbada sobre el camino, en el plano del suelo (fuga al fondo),
//     viene despacio hacia la camara.
// Rayos: los de verdad de la imagen (mascaras.py los saca de los huecos de la
// copa); giran un pelin con la copa, la bruma corre por dentro y se ven mas
// donde hay niebla. Luz: respira, tiembla entre las ramas con el viento y, a
// ratos, el sol se abre paso (claro).

uniform sampler2D ruido : filter_linear, repeat_enable;
// R troncos, G rayos con signo, B luz.
uniform sampler2D mascara : filter_linear;
// G ramas de la copa, B profundidad: 0 cerca .. 1 lejos.
uniform sampler2D profundidad : filter_linear;
uniform vec2 pantalla = vec2(2912.0, 1632.0);
uniform float tiempo = 0.0;
uniform vec2 camara = vec2(0.0);

// Niebla por capas: viento acumulado (px) y cuanto tapa como mucho.
uniform vec2 viento_fondo = vec2(0.0);
uniform vec2 viento_medio = vec2(0.0);
uniform vec2 viento_cerca = vec2(0.0);
uniform float fondo_fuerza = 0.4;
uniform float medio_fuerza = 0.32;
uniform float cerca_fuerza = 0.16;
// Rasante: horizonte (donde el camino se pierde), viento en el plano del suelo.
uniform vec2 fuga = vec2(1430.0, 1000.0);
uniform vec2 viento_suelo = vec2(0.0);
uniform float suelo_fuerza = 0.42;
// Cuanto hueco deja: mas alto, jirones mas sueltos.
uniform float huecos = 0.8;

// Rayos y luz.
uniform vec2 fuente = vec2(1440.0, 380.0);
uniform float rayos_giro = 0.0;
uniform float rayos_fuerza = 1.0;
uniform float luz_global = 0.0;    // -1..1, respiracion lenta
uniform vec2 luz_deriva = vec2(0.0);
uniform float parpadeo = 0.0;      // 0..1, lo que sopla en la copa
uniform float claro = 0.0;         // 0..1, el sol se abre paso

// Jirones: dos escalas grandes, deformadas por otro ruido mas lento (asi las
// formas se estiran y se enroscan en vez de solo trasladarse), con umbral
// blando para que haya niebla y huecos. Nada fino: con una tercera escala
// pequena salia un moteado de camuflaje.
float jirones(vec2 q, float t, float semilla) {
	vec2 w = texture(ruido, q * 0.45 + vec2(semilla, t * 0.004)).gb - 0.5;
	q += w * 0.55;
	float f = texture(ruido, q).r * 0.72
		+ texture(ruido, q * 2.1 + vec2(0.31, 0.17 + t * 0.003)).g * 0.28;
	return smoothstep(0.5 - 0.05 * (1.0 - huecos), 0.5 + 0.19, f);
}

void fragment() {
	vec2 p = UV * pantalla;
	vec3 m = texture(mascara, UV).rgb;
	float luz = m.b;
	vec3 pv = texture(profundidad, UV).rgb;
	float prof = pv.b;
	// Las ramas de la copa estan delante de la niebla del fondo: no las tapa
	// (si no, la copa perdia su dibujo fino).
	float ramas = pv.g;
	float t = tiempo;

	// --- Capas por distancia: cada una tapa solo lo que esta mas lejos.
	vec2 qf = (p + camara * 0.15 - viento_fondo) / vec2(1150.0, 520.0);
	float af = jirones(qf, t, 0.13) * smoothstep(0.5, 0.8, prof) * (1.0 - 0.75 * ramas) * fondo_fuerza;
	vec2 qm = (p + camara * 0.5 - viento_medio) / vec2(950.0, 480.0);
	float am = jirones(qm, t, 0.57) * smoothstep(0.2, 0.45, prof) * medio_fuerza;
	vec2 qc = (p + camara * 1.3 - viento_cerca) / vec2(1700.0, 900.0);
	float ac = jirones(qc, t, 0.91) * cerca_fuerza;

	// --- Rasante, en el plano del suelo.
	vec2 ps = p + camara * 0.9;
	float dy = ps.y - fuga.y;
	float z = 1.0 / max(dy + 60.0, 8.0);
	vec2 g = vec2((ps.x - fuga.x) * 0.22 * z, 520.0 * z);
	g += vec2(-viento_suelo.x, viento_suelo.y);
	float banda = smoothstep(-50.0, 60.0, dy) * mix(1.0, 0.55, smoothstep(100.0, 640.0, dy));
	float as_ = jirones(g * vec2(0.9, 0.7), t, 0.37) * banda * suelo_fuerza;

	float niebla = 1.0 - (1.0 - af) * (1.0 - am) * (1.0 - ac) * (1.0 - as_);

	// --- Rayos: los de la imagen, girados con la copa alrededor de la fuente.
	vec2 d = p - fuente;
	float cg = cos(rayos_giro);
	float sg = sin(rayos_giro);
	vec2 dr = vec2(cg * d.x - sg * d.y, sg * d.x + cg * d.y);
	// Suavizado un pelin (cuatro tomas): a 1/4 de resolucion el haz crudo
	// salia a manchas.
	vec2 uh = (fuente + dr) / pantalla;
	vec2 e = 1.5 / vec2(textureSize(mascara, 0));
	float haz = (texture(mascara, uh + vec2(e.x, 0.0)).g + texture(mascara, uh - vec2(e.x, 0.0)).g
		+ texture(mascara, uh + vec2(0.0, e.y)).g + texture(mascara, uh - vec2(0.0, e.y)).g) * 0.5 - 1.0;
	// La bruma que corre por dentro, alejandose de la luz (polares). Solo a
	// escala grande: a escala fina en vez de haces salian manchas.
	float ang = atan(d.x, d.y);
	float dist = length(d);
	float bruma = texture(ruido, vec2(ang * 1.1, dist / 1100.0 - t * 0.025)).b;
	bruma = mix(bruma, texture(ruido, vec2(ang * 1.9 + 0.4, dist / 650.0 - t * 0.04)).g, 0.35);
	float rayo = haz * (0.3 + 1.4 * bruma) * (0.6 + 1.6 * niebla);
	rayo *= smoothstep(60.0, 220.0, dist) * (1.0 + 0.4 * luz_global + 1.0 * claro) * rayos_fuerza;

	// --- Luz: respira, se abre paso a ratos y tiembla entre las ramas.
	float nl = texture(ruido, p / 1500.0 + luz_deriva).g - 0.5;
	float tb = texture(ruido, p / 850.0 + vec2(t * 0.35, -t * 0.25)).r - 0.5;
	float l = nl * 0.8 + luz_global * 0.35 + claro * 0.55 + tb * 1.6 * parpadeo * luz;

	COLOR = vec4(clamp(niebla, 0.0, 1.0), 0.5 + 0.5 * clamp(rayo, -1.0, 1.0),
		0.5 + 0.5 * clamp(l, -1.0, 1.0), 1.0);
}
