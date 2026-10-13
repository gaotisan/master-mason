shader_type canvas_item;
render_mode blend_add;
// El bosque de fondo de la hojarasca (bosque_hojarasca.png, de Midjourney con
// el estilo de camino_bosque; antes probadas bosque_fondo.jpg de Gemini y
// bosque_fondo_mj.png facetada), sumado a la oscuridad del fondo. Va en dos
// planos (raw/master_mason/hojarasca_bosque/capas.py): la textura del sprite
// es el de detras (bosque_lejos.png: niebla, troncos lejanos y el camino, con
// la niebla rellenada debajo de los troncos de delante) y capa_cerca el de
// delante (bosque_cerca.png: los troncos oscuros, con alfa).
//
// LUZ. La luz del haz tiene entidad propia (relato): el bosque va en sombra,
// con tinte frio, casi sin luz del haz, y el haz es lo que brilla. El camino
// de la derecha (mascara bosque_hojarasca_camino.png) no se ve hasta `camino`
// (0 tapado: apagado al nivel de la niebla; 1 a la vista: su dorado, que es la
// luz de camino_bosque, adonde lleva). Por debajo de `horizonte` se funde a
// negro: detras del borde del lecho tiene que haber oscuridad (sus hojas
// doradas se recortan a contraluz; con la bruma detras el lecho se leia como
// una franja plana pegada a los arboles).
//
// VIDA (como camino_fondo.gdshader, del que sale esto; mascaras de
// raw/master_mason/hojarasca_bosque/mascaras.py). No se recorta nada: se
// desplaza la propia imagen.
// - Copa: las ramas finas se mecen. Cinco muelles a lo ancho
//   (caida_hojarasca.gd) llevan lo que se inclina la copa en cada franja: la
//   racha se ve cruzar el bosque. Encima, ramas y ramitas a su aire. Los
//   troncos gruesos no se mueven.
// - Paralaje: la camara se mueve (caida_hojarasca.gd: se adelanta hacia donde
//   va el peregrino, sube con el y respira) y el suelo y el peregrino se mueven
//   con ella; los troncos de delante algo menos y lo de detras casi nada. Los
//   troncos se deslizan sobre la niebla sin deformarse (antes habia un mapa de
//   profundidad desenfocado que dejaba casi todo como "cerca": se movia de
//   una pieza, como un carton).

uniform vec2 pantalla = vec2(2912.0, 1632.0);
uniform vec2 haz_origen = vec2(1620.0, -700.0);
uniform vec2 haz_destino = vec2(1456.0, 1200.0);
uniform float haz_apertura = 0.17;
uniform float exposicion = 2.2;
uniform float ambiente = 0.25;        // fuera de la luz
uniform float en_el_haz = 1.4;        // de mas dentro del cono
uniform float resplandor = 1.6;       // de mas junto a donde pega en el suelo
uniform vec2 resplandor_tam = vec2(900.0, 420.0);
uniform vec3 tinte : source_color = vec3(1.0, 0.86, 0.68);
// v desde la que el bosque se funde a negro (y en cuanto).
uniform float horizonte = 0.677;
uniform float suelo_luz = 0.0;
uniform float suelo_fundido = 0.024;
uniform sampler2D mascara_camino : filter_linear;
uniform float camino : hint_range(0.0, 1.0) = 0.0;
uniform float camino_tapado = 0.0;
uniform float camino_brillo = 1.0;

group_uniforms vida;
// R copa (G troncos y B profundidad ya no se usan: ver paralaje).
uniform sampler2D viento_m : filter_linear;
uniform sampler2D capa_cerca : filter_linear;
uniform sampler2D ruido : filter_linear, repeat_enable;
uniform float tiempo = 0.0;
// Desplazamiento de la camara (px del mundo) y cuanto lo sigue cada plano
// (1 = como el suelo, 0 = quieto en pantalla).
uniform vec2 camara = vec2(0.0);
uniform float paralaje_cerca = 0.55;
uniform float paralaje_lejos = 0.08;
uniform float brisa = 0.4;
// Punta de la copa (px) en x = 0, 1/4, 1/2, 3/4 y 1 del ancho, de los muelles.
uniform vec2 empuje[5];
// Racha 0..1 tal como le llega a cada franja.
uniform float agitacion[5];
uniform float rama_px = 3.0;
uniform float rama_racha_px = 6.0;
uniform float ramita_px = 2.0;
uniform float ramita_racha_px = 3.5;
uniform vec2 rama_vel = vec2(-0.05, 0.017);
uniform vec2 ramita_vel = vec2(0.3, -0.22);

// Donde se lee la imagen para el punto q (px de la imagen): la copa se mece.
vec2 mecer(vec2 q) {
	float copa = texture(viento_m, q / pantalla).r;
	if (copa > 0.002) {
		float f = clamp(q.x / pantalla.x, 0.0, 1.0) * 4.0;
		int i = min(int(f), 3);
		float k = smoothstep(0.0, 1.0, f - float(i));
		vec2 e = mix(empuje[i], empuje[i + 1], k);
		float ag = mix(agitacion[i], agitacion[i + 1], k);
		vec2 nr = texture(ruido, q / 700.0 + rama_vel * tiempo).rg - 0.5;
		vec2 nt = texture(ruido, q / 150.0 + ramita_vel * tiempo).ba - 0.5;
		q -= copa * (e
			+ nr * 2.0 * (rama_px * brisa + rama_racha_px * ag)
			+ nt * 2.0 * (ramita_px * brisa + ramita_racha_px * ag));
	}
	return q;
}

// La luz de un plano: c leido en uv (el camino se mira donde esta en ese plano).
vec3 alumbrar(vec3 c, vec2 uv, float luz, float suelo_v) {
	float m = texture(mascara_camino, uv).r;
	float suelo = suelo_v * (1.0 - m);
	float kk = exposicion * mix(luz, suelo_luz, suelo);
	kk *= mix(1.0, mix(camino_tapado, camino_brillo, camino), m);
	return c * mix(tinte, vec3(1.0), m * camino) * kk;
}

void fragment() {
	vec2 px = UV * pantalla;
	// Paralaje: el sprite se mueve con el mundo; cada plano vuelve atras lo que
	// no le toca por estar mas lejos.
	vec2 uv_l = mecer(px - camara * (1.0 - paralaje_lejos)) / pantalla;
	vec2 uv_c = mecer(px - camara * (1.0 - paralaje_cerca)) / pantalla;
	vec3 lejos = texture(TEXTURE, uv_l).rgb;
	vec4 cerca = texture(capa_cerca, uv_c);

	vec2 eje = normalize(haz_destino - haz_origen);
	float a = acos(clamp(dot(normalize(px - haz_origen), eje), -1.0, 1.0));
	float cono = 1.0 - smoothstep(haz_apertura * 0.5, haz_apertura * 1.8, a);
	vec2 e2 = (px - haz_destino) / resplandor_tam;
	float glow = exp(-dot(e2, e2) * 1.2);
	float luz = ambiente + en_el_haz * cono + resplandor * glow;
	float suelo_v = smoothstep(horizonte - 0.02, horizonte + suelo_fundido, UV.y);
	vec3 c = mix(alumbrar(lejos, uv_l, luz, suelo_v), alumbrar(cerca.rgb, uv_c, luz, suelo_v), cerca.a);
	COLOR = vec4(c, 1.0);
}
