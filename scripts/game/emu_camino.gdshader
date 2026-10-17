shader_type canvas_item;
// El emu del principio, en primer plano, metido en la luz del bosque. El video
// esta iluminado de estudio, de frente, sobre croma. En la foto la luz viene de
// DETRAS (el fondo del pasillo): los troncos tienen la cara hacia la camara
// oscura y un filo de luz del lado que mira al pasillo.
//
// Primera vuelta (2026-10-14), comparado con un tronco real de la foto: le
// delataban la luz de estudio de frente, el contorno el doble de nitido que
// cualquier borde de la foto, las patas grises de estudio el doble de claras
// que el suelo y el mismo brillo de la cabeza a los pies. Arreglado aplanando
// la luz de estudio (construye.py) y con un filo de contraluz en el canto.
//
// Segunda vuelta (2026-10-17, el usuario: "aun se ve como un pastiche"): con la
// luz aplanada quedaba como un carton recortado: el mismo nivel en todo el
// cuerpo, sin volumen, sin nada de la luz que tiene alrededor, y los ojos
// encendidos como faros (la unica luz de estudio que quedaba). Ahora se le
// vuelve a iluminar como a un cuerpo redondo metido en esa niebla:
// - Relieve: construye.py saca de la silueta, por fotograma, una normal (un
//   bulto ancho para la masa del cuerpo y otro estrecho para el canto que se
//   curva: las patas y el cuello salen como cilindros) y el grosor. Va en el
//   atlas emu_relieve_N (a la mitad, mismas UV).
// - Luz de la imagen: cada punto recibe la luz de lo que tiene alrededor en la
//   direccion hacia la que mira (la foto desenfocada, medio). La cara que mira
//   a la camara ve el bosque que hay detras de la camara: oscuro (frente). Lo
//   que mira hacia arriba, la niebla de arriba (cielo); hacia abajo, el suelo
//   (rebote). Lo que mira de lado ve lo que hay a ese lado: hacia la niebla del
//   camino se aclara, hacia el tronco se pierde en la oscuridad como los
//   troncos de la foto.
// - Contraluz: el resplandor del fondo del pasillo pega en el canto que mira
//   hacia el (luz rasante, solo donde la normal ya casi no mira a la camara),
//   con el color de detras. Y las plumas finas del canto dejan pasar un poco
//   de esa luz (translucidez), poca: un aro claro en las puntas se leia como
//   un recortable (un engranaje).
// - Ojos: reflejan la luz que les llega (algo mas que las plumas, y un brillo
//   pequeno), ya no se encienden.
// - Lo de antes sigue: nivel por la luz de baja frecuencia de la foto, canto
//   suavizado, bruma en los pies, niebla de su distancia, grano, desenfoque
//   por cercania y estela, bordes del cuadro del video.

uniform sampler2D medio : filter_linear;
// Normales (rg) y grosor (b) del fotograma, de la misma pagina (emu_camino.gd).
uniform sampler2D relieve : filter_linear;
uniform vec2 pantalla = vec2(2912.0, 1632.0);
uniform vec3 ambiente : source_color = vec3(0.12, 0.11, 0.11);
uniform float exposicion = 2.3;
uniform float saturacion = 0.45;
uniform vec3 tinte : source_color = vec3(1.06, 1.0, 0.92);
// Contraste del detalle de las plumas por encima y por debajo del gris de
// referencia (1 = el del video). Las luces, algo aplanadas: las manchas claras
// del pecho eran de la IA, no de la luz.
uniform float contraste_luces = 0.8;
uniform float contraste_sombras = 1.0;
uniform float gris_ref = 0.24;
// Cuanto sigue a la luz de la zona (0 = nada, 1 = del todo).
uniform float luz_zona = 0.8;
// La luz por direcciones (respecto a la de la zona): lo que mira a la camara,
// hacia arriba, hacia abajo y hacia un lado, y a que distancia (px de imagen)
// se mira lo que tiene alrededor.
uniform float frente = 0.6;
// (pegado a la camara, mas: si no, en la embestida era una mancha negra con ojos)
uniform float frente_cerca = 0.95;
uniform float cielo = 0.06;
uniform float rebote = 0.2;
uniform float lado = 0.7;
uniform float alcance = 260.0;
// Cuanto se nota el relieve (0 = plano como antes).
uniform float relieve_fuerza = 1.0;
// Contraluz: de donde viene (imagen), fuerza, y lo rasante que tiene que ser.
uniform vec2 resplandor = vec2(1440.0, 520.0);
uniform float contraluz = 0.6;
uniform float rasante = 12.0;
uniform float translucidez = 0.18;
// Cuanto se rompe el filo en mechones (0 = liso).
uniform float mechones = 2.0;
// El sol que se abre paso (camino_bosque.gd): todo un pelin mas de luz.
uniform float claro = 0.0;
uniform float claro_luz = 0.18;
// Ojos: cuanto mas que las plumas reflejan y el brillo.
uniform float ojos = 0.85;
uniform float ojos_brillo = 0.1;
// Envoltura de la luz del fondo en el canto (light wrap), en px de pantalla
// (px_por_texel lo pone emu_camino.gd: si fueran texels, crecerian con el zoom
// de la embestida y saldria un halo).
uniform float envolver = 0.16;
uniform float envolver_px = 9.0;
// Suavizado del canto (px de pantalla).
uniform float suavizar_px = 1.9;
uniform float px_por_texel = 1.0;
// Grano: base y lo que crece con el brillo (como el de la imagen).
uniform vec2 grano = vec2(0.04, 0.11);
// Niebla de su distancia de pie; al acercarse se va quitando.
uniform float niebla = 0.1;
uniform float bruma_pies = 0.55;
uniform float bruma_alto = 240.0;
uniform float pies_y = 0.0;
uniform float cerca = 0.0;
uniform float oscurecer = 0.15;
// Desenfoque (px de pantalla) y estela (vector en px de pantalla).
uniform float desenfoque_px = 0.0;
uniform vec2 estela = vec2(0.0);
// El aire de delante (la SubViewport AireVista: haces y luz que respira, como
// en camino_fondo y el peregrino): lo que se le cruza por delante.
uniform sampler2D aire : filter_linear;
uniform float aire_delante = 0.4;
uniform float rayos_fuerza = 0.13;
uniform float luz_fuerza = 0.12;
uniform vec3 color_luz : source_color = vec3(1.0, 0.8, 0.55);
// Pasando rozando la camara (emu_camino.gd, 0..1): pegado al objetivo y a
// contraluz le tapa la luz: casi negro (hacia oscuro_pasa, con lo que quede de
// su luz en pasa_luz) y muy desenfocado (con el doble de tomas, girado: con 12
// se veian copias).
uniform float tapado = 0.0;
uniform vec3 oscuro_pasa : source_color = vec3(0.035, 0.027, 0.022);
uniform float pasa_luz = 0.3;
// El cuadro del video en pantalla (x, y, ancho, alto).
uniform vec4 cuadro = vec4(-100000.0, -100000.0, 200000.0, 200000.0);

varying vec2 local;
// (el modulate del nodo: el shader escribe COLOR entero y si no se perdia)
varying vec4 modula;

const vec3 LUM = vec3(0.3, 0.59, 0.11);
const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.7071, 0.7071), vec2(-0.7071, -0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, 0.7071));

void vertex() {
	local = VERTEX;
	modula = COLOR;
}

// Disco de Poisson (12) para el desenfoque.
const vec2 DISCO[12] = vec2[12](vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457),
	vec2(-0.203, 0.621), vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767),
	vec2(0.185, -0.893), vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

// El trozo del atlas de este fotograma (UV): lo que se lee de alrededor (el
// desenfoque, los cantos) no sale de el. Si salia, el desenfoque cogia los
// fotogramas vecinos y se veia un velo con una costura recta.
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);

vec4 tex(sampler2D t, vec2 uv) {
	return texture(t, clamp(uv, region.xy, region.zw));
}

vec3 foto(vec2 p) {
	return texture(medio, clamp(p / pantalla, vec2(0.0), vec2(1.0))).rgb;
}

void fragment() {
	vec4 c = tex(TEXTURE, UV);
	// Desenfoque y estela: media de tomas en un disco repartidas a lo largo de
	// la estela (en premultiplicado, para que el canto no se oscurezca).
	if (desenfoque_px > 0.5 || length(estela) > 1.0) {
		vec2 tex_px = TEXTURE_PIXEL_SIZE / px_por_texel;
		vec4 acc = vec4(c.rgb * c.a, c.a);
		float n = 1.0;
		for (int i = 0; i < 12; i++) {
			float f = (float(i) + 0.5) / 12.0 - 0.5;
			vec2 o = (DISCO[i] * desenfoque_px - estela * f) * tex_px;
			vec4 s = tex(TEXTURE, UV + o);
			acc += vec4(s.rgb * s.a, s.a);
			n += 1.0;
		}
		if (tapado > 0.0 || length(estela) > 24.0) {
			// otras 12 (pasando, o con mucha estela: con 12 salian rayas, copias): el disco girado y a otro radio, la estela entre medias
			for (int i = 0; i < 12; i++) {
				float f = float(i) / 12.0 - 0.5;
				vec2 d = vec2(DISCO[i].y, -DISCO[i].x) * 0.7;
				vec2 o = (d * desenfoque_px - estela * f) * tex_px;
				vec4 s = tex(TEXTURE, UV + o);
				acc += vec4(s.rgb * s.a, s.a);
				n += 1.0;
			}
		}
		acc /= n;
		c = vec4(acc.rgb / max(acc.a, 1e-4), acc.a);
	}
	vec3 m = foto(local);
	float lm = dot(m, LUM);

	// --- Su color (las plumas), con la luz de estudio ya quitada. En el canto
	// semitransparente, sin color: ahi queda un ribete magenta de quitar el
	// verde del croma.
	c.rgb = mix(vec3(dot(c.rgb, LUM)), c.rgb, smoothstep(0.35, 0.9, c.a));
	float l = max(dot(c.rgb, LUM), 1e-3);
	float lc = gris_ref * pow(l / gris_ref, l > gris_ref ? contraste_luces : contraste_sombras);
	vec3 col = mix(vec3(lc), c.rgb * (lc / l), saturacion);
	float ojo = smoothstep(0.22, 0.4, c.r - c.b) * smoothstep(0.3, 0.5, l);
	col = mix(col, c.rgb * ojos, ojo);

	// --- Relieve.
	vec3 r = texture(relieve, clamp(UV, region.xy, region.zw)).rgb;
	vec2 nxy = (r.rg * 2.0 - 1.0) * relieve_fuerza;
	float nz = sqrt(clamp(1.0 - dot(nxy, nxy), 0.0, 1.0));
	float grosor = r.b;
	float lat = length(nxy);
	vec2 dir = lat > 1e-3 ? nxy / lat : vec2(0.0, -1.0);

	// --- La luz de la zona: la de la foto, de baja frecuencia (cinco tomas a
	// 120 px), respecto a la media de su sitio (asi oscurece hacia abajo y
	// hacia la izquierda como la foto).
	vec2 e = vec2(120.0, 0.0);
	float zona = (lm + dot(foto(local + e.xy), LUM) + dot(foto(local - e.xy), LUM)
		+ dot(foto(local + e.yx), LUM) + dot(foto(local - e.yx), LUM)) / 5.0;
	float factor = mix(1.0, clamp(zona / max(dot(ambiente, LUM), 1e-3), 0.45, 1.4), luz_zona);
	vec3 base = ambiente * factor;

	// --- La luz que le llega por direcciones, de lo que tiene alrededor.
	vec3 de_lado = foto(local + dir * alcance);
	vec3 de_arriba = foto(local - vec2(0.0, alcance * 1.5));
	vec3 de_abajo = foto(local + vec2(0.0, alcance));
	// (lo que se ve alrededor, relativo a lo que hay justo detras: en la misma
	// escala que base)
	vec3 luz = base * mix(frente, frente_cerca, cerca) * mix(1.0, nz, 0.5)
		+ base * (de_arriba / max(lm, 1e-3)) * cielo * max(-nxy.y, 0.0)
		+ base * (de_abajo / max(lm, 1e-3)) * rebote * max(nxy.y, 0.0)
		+ base * (de_lado / max(lm, 1e-3)) * lado * pow(lat, 6.0) * mix(1.0, pow(clamp(l / gris_ref, 0.0, 1.6), mechones), 0.5);
	luz *= 1.0 + claro_luz * claro;
	vec3 g = col * luz * tinte * exposicion * (1.0 - oscurecer * cerca);

	// --- Contraluz: el resplandor pega rasante en el canto que mira hacia el.
	vec2 hacia = resplandor - local;
	hacia = length(hacia) > 1e-3 ? normalize(hacia) : vec2(0.0, -1.0);
	float mira = max(dot(dir, hacia), 0.0);
	float rasa = pow(lat, rasante) * mira;
	// En las puntas finas (las plumas erizadas) ni filo ni envoltura fuertes: el
	// canto dentado salia como un engranaje con un aro claro, de recortable.
	vec2 rw = TEXTURE_PIXEL_SIZE * envolver_px / px_por_texel;
	float abierto = 0.0;
	for (int i = 0; i < 8; i++) {
		abierto += 1.0 - tex(TEXTURE, UV + DIRS[i] * rw).a;
	}
	abierto /= 8.0;
	float fina = 1.0 - smoothstep(0.5, 0.72, abierto);
	float luz_detras = smoothstep(0.06, 0.4, dot(de_lado, LUM));
	// (a contraluz, un animal peludo no brilla liso: se encienden los mechones
	// claros y los oscuros no; el filo va con el detalle de las plumas, elevado a mechones)
	float mechon = pow(clamp(l / gris_ref, 0.0, 1.6), mechones);
	g += de_lado * col / gris_ref * mechon * rasa * contraluz * luz_detras * (1.0 - 0.5 * cerca) * mix(0.35, 1.0, fina);
	// Translucidez: lo fino del canto deja pasar algo de la luz de detras.
	float fino = 1.0 - smoothstep(0.0, 0.6, grosor);
	g += m * fino * translucidez * (0.4 + 0.6 * mira) * smoothstep(0.08, 0.4, lm) * fina;
	// Envoltura: la luz del fondo se come el canto, mas ancho y suave.
	float canto = clamp(abierto * 1.6, 0.0, 1.0);
	g = mix(g, m * 1.05, clamp(canto * envolver * smoothstep(0.05, 0.35, lm) * fina, 0.0, 1.0));

	// --- Ojos: un brillo pequeno (lo mas claro del ojo, con la luz de alli).
	g += m * ojo * ojos_brillo * smoothstep(0.55, 0.8, l);

	// --- Pasando: le tapa la luz.
	g = mix(g, oscuro_pasa + g * pasa_luz, tapado);

	// --- Bruma en los pies y niebla de su distancia, hacia el color de ahi.
	float pies = smoothstep(pies_y - bruma_alto, pies_y + 10.0, local.y) * bruma_pies;
	g = mix(g, m, clamp(niebla * (1.0 - 0.85 * cerca) + pies, 0.0, 1.0));

	// --- El aire de delante: haces y luz que respira (menos cuanto mas cerca).
	vec4 nb = texture(aire, local / pantalla);
	float rayo = (nb.g - 0.5) * 2.0;
	float lz = (nb.b - 0.5) * 2.0;
	float haz = max(rayo, 0.0) + 0.35 * min(rayo, 0.0);
	float delante = aire_delante * (1.0 - 0.6 * cerca);
	g += color_luz * haz * rayos_fuerza * delante;
	g *= 1.0 + luz_fuerza * lz * delante;

	// --- Grano, por texel del atlas (va pegado al emu).
	vec2 t = floor(UV / TEXTURE_PIXEL_SIZE);
	float h = fract(sin(dot(t, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	g += h * (grano.x + grano.y * dot(g, LUM));

	// --- Canto suavizado, como los de la foto.
	vec2 rs = TEXTURE_PIXEL_SIZE * suavizar_px / px_por_texel;
	float a = (c.a * 2.0 + tex(TEXTURE, UV + vec2(rs.x, 0.0)).a + tex(TEXTURE, UV - vec2(rs.x, 0.0)).a
		+ tex(TEXTURE, UV + vec2(0.0, rs.y)).a + tex(TEXTURE, UV - vec2(0.0, rs.y)).a) / 6.0;
	// (desenfocado, el canto es el del desenfoque: con el de la textura nitida
	// volvian los cantos duros y las puntas de las plumas como cuernos)
	a = mix(a, c.a, clamp(max(desenfoque_px, length(estela)) / 8.0, 0.0, 1.0));

	// --- Bordes del cuadro del video.
	vec2 dentro = min(local - cuadro.xy, cuadro.xy + cuadro.zw - local);
	a *= smoothstep(0.0, 24.0, min(dentro.x, dentro.y));
	COLOR = vec4(g, a * modula.a);
}
