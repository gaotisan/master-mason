shader_type canvas_item;
// El peregrino (PeregrinoFrontal) metido en la luz del camino del bosque. Lo
// lleva peregrino_camino.gd, que le pone el material en la raiz (lo usan el
// cuerpo, la garra y la correa).
//
// En la foto la luz viene de DETRAS: el resplandor del fondo del pasillo. El
// peregrino anda hacia la camara saliendo de esa luz, asi que se le ilumina
// como al emu (emu_camino.gdshader, medido contra los troncos de la foto):
// - su nivel, el ambiente de su sitio por la luz de baja frecuencia de la foto;
// - contraluz: el canto que mira al resplandor (la normal sale del alfa en 8
//   direcciones) se funde con el color de lo que tiene detras, SIN PASARLO:
//   sumado, el canto quedaba mas claro que la bruma (191 contra 175 en el pico
//   de la capucha) y se veia una raya clara alrededor, un halo de recortable;
// - envoltura de la luz del fondo en el canto y canto suavizado como los de la
//   foto;
// - niebla de su distancia (lejos se pierde en la bruma clara del fondo) y
//   bruma en los pies;
// - delante de el, el aire de la escena: los haces de luz (y la luz que
//   respira) le pasan por encima en la parte del camino que queda entre el y
//   la camara;
// - vista: lo que se le ve a traves de la bruma del fondo (0 = todo bruma,
//   1 = el): va con la distancia, asi que sale de la luz al acercarse y se
//   pierde en ella al alejarse.
// - En las piezas finas (el palo, la garra) ni filo ni envoltura: en la garra
//   vacia hacian un aro claro (se leia como una bola) y, como el baston
//   guardado (pegado a la espalda) no lo lleva, al guardar y sacar el baston
//   esa luz se iba y volvia (el usuario: "queda raro, hay que igualar"). El
//   contorno del cuerpo si lo lleva.
// - Grano de celda fija en pantalla (~1,2 px) pegada a el: por texel, de cerca
//   (2,5 px por texel) salia mas gordo que el de la foto.
// - El baston a la espalda y su correa usan copias de este material (el
//   componente se las pone y les copia los parametros cada fotograma): la
//   misma luz que el cuerpo, asi al sacarlo (pasa al baston del video) no
//   cambia de luz. desde / corte: el tramo de la madera que se dibuja, como
//   corte_madera.gdshader (0 y 1 = entero). encima: lo que va pegado delante
//   del cuerpo (la correa, el palo sobre la espalda): sin filo ni envoltura,
//   que detras tiene la tunica y no el fondo (le salia un contorno claro).
// Las distancias van en px de pantalla (px_por_texel: la escala del sprite);
// las tomas alrededor, como mucho a 6 texeles (el atlas deja 8 entre casillas).

uniform sampler2D medio : filter_linear;
// El aire (la SubViewport de camino_aire.gdshader): R niebla, G rayos, B luz.
uniform sampler2D aire : filter_linear;
uniform vec2 pantalla = vec2(2912.0, 1632.0);
// La escena va ampliada (sobre) y desplazada (origen): de la pantalla a la
// imagen.
uniform vec2 origen = vec2(0.0);
uniform float sobre = 1.0;
uniform vec3 ambiente : source_color = vec3(0.3, 0.27, 0.24);
uniform float exposicion = 1.0;
uniform float saturacion = 0.55;
// Las luces del video (la barba, las manos) aplanadas: a contraluz la cara que
// mira a la camara no tiene brillos (1 = como viene).
uniform float contraste_luces = 0.7;
uniform float gris_ref = 0.3;
uniform vec3 tinte : source_color = vec3(1.04, 1.0, 0.94);
uniform float luz_zona = 0.6;
// El resplandor (imagen): hacia ahi mira el filo de contraluz.
uniform vec2 resplandor = vec2(1440.0, 520.0);
uniform float contraluz = 1.5;
uniform float filo_px = 3.5;
uniform float filo_sombra = 0.12;
uniform float envolver = 0.25;
uniform float envolver_px = 7.0;
uniform float suavizar_px = 1.2;
uniform float px_por_texel = 1.0;
// Grano a 0,4 (2026-10-18): el fondo ya no trae el suyo (mascaras.py, GRANO_H)
// y con el de antes el peregrino quedaba mas granulado que la niebla.
uniform vec2 grano = vec2(0.012, 0.032);
uniform float niebla = 0.1;
uniform float bruma_pies = 0.35;
uniform float bruma_alto = 60.0;
uniform float pies_y = 0.0;
// Cuanto aire hay entre el y la camara (0..1) y la fuerza de los haces y de
// la luz sobre el (las de camino_fondo).
uniform float aire_delante = 0.5;
uniform float rayos_fuerza = 0.13;
uniform float luz_fuerza = 0.12;
uniform vec3 color_luz : source_color = vec3(1.0, 0.8, 0.55);
uniform float vista = 1.0;
uniform float desde : hint_range(0.0, 1.0) = 0.0;
uniform float corte : hint_range(0.0, 1.0) = 1.0;
uniform float encima : hint_range(0.0, 1.0) = 0.0;
// La garra del baston (centro, en el mismo espacio que MODEL_MATRIX, y radio;
// radio 0 = no hay): ahi ni filo ni envoltura. Las pues de la garra del video
// son algo mas gruesas que las del baston dibujado: con solo lo de las piezas
// finas, la del video seguia con un filo claro y al guardar el baston (pasa a
// la dibujada, oscura) esa luz se iba (el usuario: no es consistente). La pone
// el componente cada fotograma (PeregrinoFrontal).
uniform vec3 garra = vec3(0.0);
// Engordar el trazo (texeles): el baston dibujado (baston.png) tiene las pues y
// el palo mas finos que los que pinta la IA en los videos de sacar y guardar
// (de espaldas, un 30 % menos de madera con la misma silueta): sin engordarlo,
// al acabar de guardarlo parecia mas pequeno. Lo pone el componente en las
// copias del baston; el cuerpo, 0.
uniform float engordar = 0.0;
uniform float grano_px = 1.2;

varying vec2 img;
varying vec2 mundo;
// modulate / self_modulate (en fragment, COLOR ya viene multiplicado por la
// textura: usarlo otra vez elevaba al cuadrado el alfa del canto)
varying vec4 modula;

const vec3 LUM = vec3(0.3, 0.59, 0.11);
const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.7071, 0.7071), vec2(-0.7071, -0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, 0.7071));

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	img = (mundo - origen) / sobre;
	modula = COLOR;
}

vec2 radio(float px, vec2 texel) {
	return texel * min(px / max(px_por_texel, 1e-3), 6.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (engordar > 0.0) {
		// el alfa, el mayor de alrededor; el color, la media (premultiplicada) de
		// lo que hay: con el color de un solo vecino salia moteado
		vec4 suma = vec4(c.rgb * c.a, c.a);
		float maximo = c.a;
		for (int i = 0; i < 8; i++) {
			vec4 s = texture(TEXTURE, UV + DIRS[i] * TEXTURE_PIXEL_SIZE * engordar);
			suma += vec4(s.rgb * s.a, s.a);
			maximo = max(maximo, s.a);
		}
		c = vec4(suma.rgb / max(suma.a, 1e-4), maximo);
	}
	vec2 uv = img / pantalla;
	vec4 m = texture(medio, uv);
	float lm = dot(m.rgb, LUM);

	// --- Su color, algo desaturado (la bruma se come el color).
	// (el color de modulate: el tinte de la madera del baston dibujado; en el
	// cuerpo, blanco)
	c.rgb *= modula.rgb;
	float l = max(dot(c.rgb, LUM), 1e-3);
	float lc = l > gris_ref ? gris_ref + (l - gris_ref) * contraste_luces : l;
	vec3 col = mix(vec3(lc), c.rgb * (lc / l), saturacion);

	// --- La luz de la zona: la de la foto, de baja frecuencia, respecto a la
	// media de su sitio.
	vec2 e = vec2(120.0) / pantalla;
	float zona = (lm + dot(texture(medio, uv + vec2(e.x, 0.0)).rgb, LUM) + dot(texture(medio, uv - vec2(e.x, 0.0)).rgb, LUM)
		+ dot(texture(medio, uv + vec2(0.0, e.y)).rgb, LUM) + dot(texture(medio, uv - vec2(0.0, e.y)).rgb, LUM)) / 5.0;
	float factor = mix(1.0, clamp(zona / max(dot(ambiente, LUM), 1e-3), 0.6, 1.3), luz_zona);
	vec3 g = col * ambiente * tinte * exposicion * factor;

	// --- Normal del canto y cuanto se abre al aire, en dos radios.
	vec2 rf = radio(filo_px, TEXTURE_PIXEL_SIZE);
	vec2 rw = radio(envolver_px, TEXTURE_PIXEL_SIZE);
	vec2 n = vec2(0.0);
	float abierto_f = 0.0;
	float abierto_w = 0.0;
	for (int i = 0; i < 8; i++) {
		float vf = 1.0 - texture(TEXTURE, UV + DIRS[i] * rf).a;
		float vw = 1.0 - texture(TEXTURE, UV + DIRS[i] * rw).a;
		n += DIRS[i] * (vf + vw);
		abierto_f += vf;
		abierto_w += vw;
	}
	abierto_f /= 8.0;
	abierto_w /= 8.0;
	n = length(n) > 1e-3 ? normalize(n) : vec2(0.0);
	vec2 hacia = resplandor - img;
	hacia = length(hacia) > 1e-3 ? normalize(hacia) : vec2(0.0, -1.0);
	float hacia_luz = clamp(dot(n, hacia) * 0.5 + 0.5, 0.0, 1.0);
	// pieza fina: abierta por casi todos lados (un canto recto lo esta por la
	// mitad, ~0,4)
	float fina = (1.0 - smoothstep(0.5, 0.72, abierto_w)) * (1.0 - encima);
	if (garra.z > 0.0) {
		fina *= smoothstep(garra.z * 0.85, garra.z * 1.1, distance(mundo, garra.xy));
	}
	float filo = smoothstep(0.05, 0.4, abierto_f) * mix(filo_sombra, 1.0, hacia_luz * hacia_luz);
	// (tambien en el anillo semitransparente de fuera del contorno, el que abre
	// el suavizado: como no pasa del fondo, ahi lo funde con la bruma; sin el,
	// ese anillo quedaba con el color oscuro de dentro y se veia un doble borde)
	g = mix(g, m.rgb, clamp(filo * contraluz * smoothstep(0.08, 0.4, lm) * fina, 0.0, 0.85));
	float canto = clamp(abierto_w * 1.6, 0.0, 1.0);
	g = mix(g, m.rgb * 1.05, clamp(canto * envolver * smoothstep(0.05, 0.35, lm) * fina, 0.0, 1.0));

	// --- Niebla de su distancia y bruma en los pies, hacia el color de ahi;
	// saliendo de la luz, toda bruma.
	float pies = smoothstep(pies_y - bruma_alto, pies_y + 4.0, img.y) * bruma_pies;
	float bruma = clamp(niebla + pies, 0.0, 1.0);
	bruma = mix(1.0, bruma, vista);
	g = mix(g, m.rgb, bruma);

	// --- El aire de delante: haces y luz que respira (como en camino_fondo).
	vec4 nb = texture(aire, uv);
	float rayo = (nb.g - 0.5) * 2.0;
	float lz = (nb.b - 0.5) * 2.0;
	float haz = max(rayo, 0.0) + 0.35 * min(rayo, 0.0);
	g += color_luz * haz * rayos_fuerza * (0.2 + 0.8 * m.a) * aire_delante;
	g *= 1.0 + luz_fuerza * lz * (0.2 + 0.8 * m.a) * aire_delante;

	// --- Grano: celdas de grano_px de pantalla, pegadas a la tunica.
	vec2 t = floor(UV / TEXTURE_PIXEL_SIZE * px_por_texel / grano_px);
	float h = fract(sin(dot(t, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	g += h * (grano.x + grano.y * dot(g, LUM));

	// --- Canto suavizado, como los de la foto.
	vec2 rs = radio(suavizar_px, TEXTURE_PIXEL_SIZE);
	float a = (c.a * 2.0 + texture(TEXTURE, UV + vec2(rs.x, 0.0)).a + texture(TEXTURE, UV - vec2(rs.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, rs.y)).a + texture(TEXTURE, UV - vec2(0.0, rs.y)).a) / 6.0;
	if (engordar > 0.0) {
		a = max(a, c.a * 0.9);
	}
	a *= smoothstep(0.0, 0.35, vista);
	// (solo si se pide: el cuerpo va en un atlas, y su UV es de la hoja entera)
	if (corte < 1.0) {
		a *= 1.0 - smoothstep(corte - 0.008, corte, UV.y);
	}
	if (desde > 0.0) {
		a *= smoothstep(desde, desde + 0.008, UV.y);
	}
	COLOR = vec4(g, a * modula.a);
}
