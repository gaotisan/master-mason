shader_type canvas_item;
// Fondo vivo del camino del bosque. Es una sola imagen (Midjourney) y no se
// recorta nada: se desplaza la propia imagen donde la mascara dice que hay rama
// fina, y encima se aplica el aire (niebla, rayos y luz) que pinta
// camino_aire.gdshader a 1/4 de resolucion. Las mascaras y lo que mide cada una
// salen de raw/master_builder/camino_bosque/mascaras.py.
//
// - Copa: las ramas finas a contraluz se mecen. Cinco muelles repartidos a lo
//   ancho (camino_bosque.gd) llevan lo que se inclina la copa en cada franja,
//   asi la racha se ve cruzar de un lado a otro; encima, ramas y ramitas a su
//   aire. Los troncos, el camino y el suelo no se mueven nunca.
// - Camara (2.5D): respira despacio (deriva y un pelin de acercamiento) y cada
//   punto se mueve segun su distancia (profundidad.png: w, 1 cerca .. 0 lejos,
//   ver mascaras.py): S(p) = (camara + (p - foco) * acercamiento) * w.
//   Paralaje con oclusion: para cada pixel se busca, a lo largo del
//   desplazamiento, el punto de la imagen que cae ahi y, si caen varios, el
//   mas cercano; asi un tronco cercano pasa por delante de la niebla sin
//   estirarse (con un simple desplazamiento por profundidad, lo de alrededor de
//   cada tronco se estiraba como una goma). Donde un tronco deja al
//   descubierto lo de detras y no cae nada, se ve detras.png (la imagen sin lo
//   de delante, rellenada) con el desplazamiento del fondo de alrededor.
// - Aire: la niebla es luz dispersa encima de la imagen (no un desenfoque):
//   jirones del color del aire de su zona, mas claros y calidos cuanto mas les
//   da la luz. Nunca mas oscuros que lo que tienen alrededor (si no, salen
//   manchas oscuras); en la sombra casi no se ven, como en la realidad.
//   Los rayos suman y restan luz, mas donde hay niebla. El resplandor respira,
//   a ratos el sol se abre paso y, con el viento, la luz tiembla entre ramas.
// - Suelo: las manchas de luz del camino se mueven y titilan como luz que
//   pasa entre una copa que se mece.

// R copa (cuanto se mueve cada rama), B profundidad (0 cerca, 1 lejos).
uniform sampler2D viento_m : filter_linear;
// R w (1 cerca .. 0 lejos), G w del fondo de alrededor.
uniform sampler2D prof : filter_linear;
// La imagen sin lo que esta por delante, rellenada.
uniform sampler2D detras : filter_linear;
// RGB color medio de la zona, A luz.
uniform sampler2D medio : filter_linear;
// El aire (SubViewport con camino_aire.gdshader): R niebla, G rayos, B luz.
uniform sampler2D niebla : filter_linear;
uniform sampler2D ruido : filter_linear, repeat_enable;
uniform float tiempo = 0.0;

group_uniforms camara;
// Desplazamiento de lo mas cercano (px) y acercamiento (0,005 = 0,5 %), hacia
// el foco (el fondo del camino, que no se mueve).
uniform vec2 camara = vec2(0.0);
uniform float acercamiento = 0.0;
uniform vec2 foco = vec2(1440.0, 900.0);

group_uniforms viento;
uniform float brisa = 0.4;
// Punta de la copa (px) en x = 0, 1/4, 1/2, 3/4 y 1 del ancho, de los muelles.
uniform vec2 empuje[5];
// Racha 0..1 tal como le llega a cada franja.
uniform float agitacion[5];
// Vaiven propio (px): con la brisa y con la racha a tope.
uniform float rama_px = 3.2;
uniform float rama_racha_px = 6.0;
uniform float ramita_px = 2.2;
uniform float ramita_racha_px = 3.8;
// Lo rapido que cambia el vaiven de las ramas y el temblor de las ramitas
// (lo lee tambien camino_bosque.gd para que las hojas sigan a su ramita).
uniform vec2 rama_vel = vec2(-0.05, 0.017);
uniform vec2 ramita_vel = vec2(0.3, -0.22);

group_uniforms aire;
// Apagada por ahora (2026-10-11): no convencia; se retoma al final.
uniform float niebla_fuerza = 0.0;
// Cuanto aclara la niebla el aire de su zona donde la atraviesa la luz, y el
// tono que le suma la luz.
uniform float niebla_brillo = 0.3;
uniform vec3 niebla_luz : source_color = vec3(0.88, 0.74, 0.56);
uniform float rayos_fuerza = 0.13;
uniform float luz_fuerza = 0.12;
uniform vec3 color_luz : source_color = vec3(1.0, 0.8, 0.55);
// Luz moteada en el suelo: cuanto y desde donde (y) es suelo.
uniform float suelo_luz = 0.3;
uniform float suelo_y = 1060.0;
uniform float brisa_suelo = 0.0;   // 0..1, lo que sopla (la copa que mece la luz)
// Grano por fotograma apagado (2026-10-18): en la niebla se leia como ruido
// que se mueve.
uniform float grano = 0.0;

void fragment() {
	vec2 tam = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 p = UV * tam;
	float t = tiempo;
	// --- Camara: el punto de la imagen que cae en este pixel (el mas cercano).
	// S(p, w) se aproxima con p (el acercamiento cambia poco en unos px).
	vec2 por_w = camara + (p - foco) * acercamiento;
	float mejor = -1.0;
	vec2 q = p;
	const int PASOS = 12;
	for (int k = PASOS; k >= 0; k--) {
		float wk = float(k) / float(PASOS);
		vec2 c = p - por_w * wk;
		float wc = texture(prof, c / tam).r;
		if (abs(wc - wk) <= 0.75 / float(PASOS)) {
			mejor = wc;
			q = c;
			break;
		}
	}
	bool hueco = mejor < 0.0;
	if (hueco) {
		q = p - por_w * texture(prof, UV).g;
	}
	vec4 mv = texture(viento_m, q / tam);
	float copa = mv.r;

	// --- Copa.
	if (copa > 0.002) {
		// La franja en la que cae, con su muelle y su racha.
		float f = clamp(q.x / tam.x, 0.0, 1.0) * 4.0;
		int i = min(int(f), 3);
		float k = smoothstep(0.0, 1.0, f - float(i));
		vec2 e = mix(empuje[i], empuje[i + 1], k);
		float ag = mix(agitacion[i], agitacion[i + 1], k);
		vec2 nr = texture(ruido, q / 700.0 + rama_vel * t).rg - 0.5;
		vec2 nt = texture(ruido, q / 150.0 + ramita_vel * t).ba - 0.5;
		q -= copa * (e
			+ nr * 2.0 * (rama_px * brisa + rama_racha_px * ag)
			+ nt * 2.0 * (ramita_px * brisa + ramita_racha_px * ag));
	}
	vec4 col = hueco ? texture(detras, q / tam) : texture(TEXTURE, q / tam);

	vec4 md = texture(medio, UV);

	// --- Suelo: las manchas de luz (lo que ya destaca sobre el color medio)
	// suben y bajan a trozos que derivan despacio y, con viento, titilan.
	float suelo = smoothstep(suelo_y, suelo_y + 120.0, p.y);
	if (suelo > 0.0) {
		float alto = smoothstep(0.01, 0.09, dot(col.rgb - md.rgb, vec3(0.3, 0.59, 0.11)));
		// Manchas grandes y blandas: a escala fina salia un moteado de camuflaje.
		float ml = texture(ruido, p / vec2(900.0, 380.0) + vec2(t * 0.012, t * 0.004)).g - 0.5;
		float mt = texture(ruido, p / vec2(450.0, 220.0) + vec2(t * 0.3, -t * 0.18)).r - 0.5;
		col.rgb *= 1.0 + suelo_luz * suelo * alto * (ml * 2.2 + mt * 1.4 * brisa_suelo);
	}

	// --- Aire.
	vec4 nb = texture(niebla, UV);
	float fa = nb.r * niebla_fuerza;
	float rayo = (nb.g - 0.5) * 2.0;
	float l = (nb.b - 0.5) * 2.0;
	// La niebla coge la luz que hay en su sitio (y la de los haces).
	float iluminada = clamp(md.a * 1.15 + max(rayo, 0.0) * 0.6, 0.0, 1.0);
	vec3 cn = md.rgb * (1.05 + niebla_brillo * iluminada * (1.0 + 0.4 * l)) + niebla_luz * 0.1 * iluminada;
	col.rgb = mix(col.rgb, cn, clamp(fa, 0.0, 1.0));
	// Los haces se ven en el aire iluminado; en lo negro de los lados, poco.
	// Los de sombra, mas flojos: si no, en el pasillo salian manchas oscuras.
	float haz = max(rayo, 0.0) + 0.35 * min(rayo, 0.0);
	col.rgb += color_luz * haz * rayos_fuerza * (0.2 + 0.8 * md.a);
	col.rgb *= 1.0 + luz_fuerza * l * (0.2 + 0.8 * md.a);

	// Grano fino (y de paso sin bandas en los degradados oscuros).
	float g = fract(sin(dot(p + fract(t * 7.13) * 91.7, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	col.rgb += g * grano;
	COLOR = col;
}
