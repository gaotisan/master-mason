shader_type canvas_item;
// El bosque de fondo de la hojarasca (la imagen de Midjourney con el estilo de
// camino_bosque, raw/master_builder/hojarasca_bosque/bosque_hojarasca.png; antes
// se probaron una de Gemini y una facetada, ya borradas), sumado a la oscuridad
// del fondo. Va en dos
// planos (raw/master_builder/hojarasca_bosque/capas.py): la textura del sprite
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
// FONDO. El bosque va sumado a la oscuridad del fondo (fondo_haz.gdshader, que
// se pinta a 1/4 en una SubViewport): se lee aqui su imagen (`fondo`) y se suma
// en la misma pasada (2026-10-14: antes el fondo se estiraba a pantalla
// completa y el bosque se sumaba encima con blend_add; cada pasada a pantalla
// completa son ~4 ms en la grafica del portatil).
//
// VIDA (como camino_fondo.gdshader, del que sale esto; mascaras de
// raw/master_builder/hojarasca_bosque/mascaras.py). No se recorta nada: se
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
uniform float exposicion = 2.2;
// Fuera de la luz. Lo que le da el haz viene en el alfa del fondo
// (fondo_haz.gdshader: bosque_en_el_haz, bosque_resplandor).
uniform float ambiente = 0.25;
const float LUZ_BOSQUE = 4.0;  // la misma en fondo_haz.gdshader
uniform vec3 tinte : source_color = vec3(1.0, 0.86, 0.68);
// v desde la que el bosque se funde a negro (y en cuanto).
uniform float horizonte = 0.677;
uniform float suelo_luz = 0.0;
uniform float suelo_fundido = 0.024;
uniform sampler2D mascara_camino : filter_linear;
uniform float camino : hint_range(0.0, 1.0) = 0.0;
uniform float camino_tapado = 0.0;
uniform float camino_brillo = 1.0;
// Cuanto bosque se ve (1 entero, 0 solo la oscuridad del fondo con el haz): se
// apaga mientras baja el baculo y vuelve al cogerlo (caida_hojarasca.gd, EL
// BOSQUE SE APAGA CON EL BACULO).
uniform float presencia : hint_range(0.0, 1.0) = 1.0;
// La imagen del fondo (la de la SubViewport; caida_hojarasca.gd), con la luz
// del haz para el bosque en el alfa.
uniform sampler2D fondo : filter_linear;

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

// Lo que se mece la copa en q (px de la imagen): el muelle de su franja y
// ramas y ramitas a su aire. Se multiplica por la copa de cada plano. Uno
// para los dos planos (2026-10-14: antes cada plano leia su ruido; con lo poco
// que los separa el paralaje no se nota, y son dos lecturas menos por pixel).
vec2 meneo(vec2 q) {
	float f = clamp(q.x / pantalla.x, 0.0, 1.0) * 4.0;
	int i = min(int(f), 3);
	float k = smoothstep(0.0, 1.0, f - float(i));
	vec2 e = mix(empuje[i], empuje[i + 1], k);
	float ag = mix(agitacion[i], agitacion[i + 1], k);
	vec2 nr = texture(ruido, q / 700.0 + rama_vel * tiempo).rg - 0.5;
	vec2 nt = texture(ruido, q / 150.0 + ramita_vel * tiempo).ba - 0.5;
	return e
		+ nr * 2.0 * (rama_px * brisa + rama_racha_px * ag)
		+ nt * 2.0 * (ramita_px * brisa + ramita_racha_px * ag);
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
	vec2 q_l = px - camara * (1.0 - paralaje_lejos);
	vec2 q_c = px - camara * (1.0 - paralaje_cerca);
	// La copa se mece: se lee la imagen algo mas alla.
	float copa_l = texture(viento_m, q_l / pantalla).r;
	float copa_c = texture(viento_m, q_c / pantalla).r;
	if (max(copa_l, copa_c) > 0.002) {
		vec2 m = meneo(q_c);
		q_l -= copa_l * m;
		q_c -= copa_c * m;
	}
	vec2 uv_l = q_l / pantalla;
	vec2 uv_c = q_c / pantalla;
	vec3 lejos = texture(TEXTURE, uv_l).rgb;
	vec4 cerca = texture(capa_cerca, uv_c);

	vec4 f = texture(fondo, UV);
	float luz = ambiente + f.a * LUZ_BOSQUE;
	float suelo_v = smoothstep(horizonte - 0.02, horizonte + suelo_fundido, UV.y);
	vec3 c = mix(alumbrar(lejos, uv_l, luz, suelo_v), alumbrar(cerca.rgb, uv_c, luz, suelo_v), cerca.a);
	COLOR = vec4(f.rgb + c * presencia, 1.0);
}
