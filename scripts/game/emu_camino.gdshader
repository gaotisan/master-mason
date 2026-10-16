shader_type canvas_item;
// El emu del principio, en primer plano, metido en la luz del bosque. El video
// esta iluminado de estudio, de frente, sobre croma. En la foto la luz viene de
// DETRAS (el fondo del pasillo): los troncos tienen la cara hacia la camara
// oscura y un filo de luz del lado que mira al pasillo. Comparado con un tronco
// real de la foto (medido), lo que lo delataba como recorte era:
//   - luz de estudio de frente y uniforme (sin filo de contraluz),
//   - contorno el doble de nitido que cualquier borde de la foto (149 / ~75),
//   - patas grises de estudio el doble de claras que el suelo (81 / 37),
//   - el mismo brillo de la cabeza a los pies (la foto oscurece hacia abajo y
//     hacia la izquierda).
// Asi que aqui se le vuelve a iluminar como a contraluz:
// - La luz de estudio ya viene quitada de construye.py (iluminacion casi plana
//   y la textura de las plumas entera). Aqui, si acaso, un retoque de
//   contraste (1 = como viene). Los ojos se respetan.
// - Su nivel: el ambiente de su sitio por la luz de baja frecuencia de la foto
//   alrededor de cada pixel (asi oscurece hacia abajo y hacia la izquierda como
//   la foto, sin que se transparente el detalle del fondo).
// - Contraluz: filo de luz en el canto que mira a la luz (normal sacada del
//   alfa en 8 direcciones), con el color de lo que tiene detras: si detras hay
//   niebla clara, filo claro; si hay un tronco, casi nada.
// - Envoltura de la luz del fondo en el canto (light wrap).
// - Canto suavizado (alfa promediado) para igualar la nitidez de la foto.
// - Bruma en los pies, que se pierden en el suelo como las raices.
// - En la embestida, pegado a la camara, mas oscuro (cerca: oscurecer).
// - Grano del mismo nivel que el de la foto, pegado a sus plumas.
// - Desenfoque por cercania y estela de movimiento (de emu_camino.gd): pegado
//   a la camara se va de foco y deja estela en la direccion en que se mueve.
// - Los bordes del cuadro del video, si caen dentro de la pantalla, se funden
//   (no deberian: construye.py lo comprueba).

uniform sampler2D medio : filter_linear;
uniform vec2 pantalla = vec2(2912.0, 1632.0);
uniform vec3 ambiente : source_color = vec3(0.12, 0.11, 0.11);
uniform float exposicion = 2.2;
uniform float saturacion = 0.5;
uniform vec3 tinte : source_color = vec3(1.06, 1.0, 0.9);
// Contraste interno por encima y por debajo del gris de referencia (1 = el del
// video): las luces mucho mas aplanadas que las sombras.
uniform float contraste_luces = 1.0;
uniform float contraste_sombras = 1.0;
uniform float gris_ref = 0.24;
// Cuanto sigue a la luz de la zona (0 = nada, 1 = del todo).
uniform float luz_zona = 0.8;
// Contraluz: direccion de la luz en la textura (x derecha, y abajo), fuerza
// del filo, ancho y cuanto filo hay tambien del lado de la sombra. Los anchos,
// en px de pantalla (px_por_texel lo pone emu_camino.gd: si fueran texels,
// crecerian con el zoom de la embestida y saldria un halo).
uniform vec2 luz_dir = vec2(1.0, -0.7);
// (Mas fuerte dejaba un aura grisacea difusa alrededor: el usuario la vio.)
uniform float contraluz = 0.8;
uniform float filo_px = 4.5;
uniform float filo_sombra = 0.08;
uniform float envolver = 0.22;
uniform float envolver_px = 9.0;
// Suavizado del canto (px de pantalla).
uniform float suavizar_px = 1.9;
uniform float px_por_texel = 1.0;
// Grano: base y lo que crece con el brillo (como el de la imagen).
uniform vec2 grano = vec2(0.045, 0.12);
// Niebla de su distancia de pie; al acercarse se va quitando.
uniform float niebla = 0.08;
uniform float bruma_pies = 0.55;
uniform float bruma_alto = 240.0;
uniform float pies_y = 0.0;
uniform float cerca = 0.0;
uniform float oscurecer = 0.2;
// Desenfoque (px de pantalla) y estela (vector en px de pantalla).
uniform float desenfoque_px = 0.0;
uniform vec2 estela = vec2(0.0);
// El cuadro del video en pantalla (x, y, ancho, alto).
uniform vec4 cuadro = vec4(-100000.0, -100000.0, 200000.0, 200000.0);

varying vec2 local;

const vec3 LUM = vec3(0.3, 0.59, 0.11);
const vec2 DIRS[8] = vec2[8](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0),
	vec2(0.7071, 0.7071), vec2(-0.7071, -0.7071), vec2(0.7071, -0.7071), vec2(-0.7071, 0.7071));

void vertex() {
	local = VERTEX;
}

// Disco de Poisson (12) para el desenfoque.
const vec2 DISCO[12] = vec2[12](vec2(-0.326, -0.406), vec2(-0.840, -0.074), vec2(-0.696, 0.457),
	vec2(-0.203, 0.621), vec2(0.962, -0.195), vec2(0.473, -0.480), vec2(0.519, 0.767),
	vec2(0.185, -0.893), vec2(0.507, 0.064), vec2(0.896, 0.412), vec2(-0.322, -0.933), vec2(-0.792, -0.598));

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Desenfoque y estela: media de tomas en un disco repartidas a lo largo de
	// la estela (en premultiplicado, para que el canto no se oscurezca).
	if (desenfoque_px > 0.5 || length(estela) > 1.0) {
		vec2 tex_px = TEXTURE_PIXEL_SIZE / px_por_texel;
		vec4 acc = vec4(c.rgb * c.a, c.a);
		for (int i = 0; i < 12; i++) {
			float f = (float(i) + 0.5) / 12.0 - 0.5;
			vec2 o = (DISCO[i] * desenfoque_px - estela * f) * tex_px;
			vec4 s = texture(TEXTURE, UV + o);
			acc += vec4(s.rgb * s.a, s.a);
		}
		acc /= 13.0;
		c = vec4(acc.rgb / max(acc.a, 1e-4), acc.a);
	}
	vec4 m = texture(medio, local / pantalla);
	float lm = dot(m.rgb, LUM);

	// --- Su color con la luz de estudio aplanada (los ojos, aparte).
	float l = max(dot(c.rgb, LUM), 1e-3);
	float lc = gris_ref * pow(l / gris_ref, l > gris_ref ? contraste_luces : contraste_sombras);
	vec3 col = mix(vec3(lc), c.rgb * (lc / l), saturacion);
	float ojo = smoothstep(0.22, 0.4, c.r - c.b) * smoothstep(0.3, 0.5, l);
	col = mix(col, mix(vec3(l), c.rgb, 0.8), ojo * 0.8);

	// --- La luz de la zona: la de la foto, de baja frecuencia (cinco tomas a
	// 120 px), respecto a la media de su sitio.
	vec2 e = vec2(120.0) / pantalla;
	vec2 uv = local / pantalla;
	float zona = (lm + dot(texture(medio, uv + vec2(e.x, 0.0)).rgb, LUM) + dot(texture(medio, uv - vec2(e.x, 0.0)).rgb, LUM)
		+ dot(texture(medio, uv + vec2(0.0, e.y)).rgb, LUM) + dot(texture(medio, uv - vec2(0.0, e.y)).rgb, LUM)) / 5.0;
	float factor = mix(1.0, clamp(zona / max(dot(ambiente, LUM), 1e-3), 0.45, 1.4), luz_zona);
	vec3 g = col * ambiente * tinte * exposicion * factor * (1.0 - oscurecer * cerca);

	// --- Normal del canto y cuanto se abre al aire alrededor, en dos radios.
	vec2 rf = TEXTURE_PIXEL_SIZE * filo_px / px_por_texel;
	vec2 rw = TEXTURE_PIXEL_SIZE * envolver_px / px_por_texel;
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
	float hacia_luz = clamp(dot(n, normalize(luz_dir)) * 0.5 + 0.5, 0.0, 1.0);
	// Contraluz: filo fino, sobre todo del lado de la luz, con el color de
	// detras (solo si detras hay luz).
	// En las puntas finas (las plumas erizadas) ni filo ni envoltura: el canto
	// dentado salia como un engranaje con un aro claro, de recortable (como en
	// peregrino_camino.gdshader).
	float fina = 1.0 - smoothstep(0.5, 0.72, abierto_w);
	float filo = smoothstep(0.05, 0.4, abierto_f) * mix(filo_sombra, 1.0, hacia_luz * hacia_luz);
	g += m.rgb * filo * contraluz * smoothstep(0.08, 0.4, lm) * (1.0 - 0.5 * cerca) * fina;
	// Envoltura: la luz del fondo se come el canto, mas ancho y suave.
	float canto = clamp(abierto_w * 1.6, 0.0, 1.0);
	g = mix(g, m.rgb * 1.05, clamp(canto * envolver * smoothstep(0.05, 0.35, lm) * fina, 0.0, 1.0));

	// --- Bruma en los pies y niebla de su distancia, hacia el color de ahi.
	float pies = smoothstep(pies_y - bruma_alto, pies_y + 10.0, local.y) * bruma_pies;
	g = mix(g, m.rgb, clamp(niebla * (1.0 - 0.85 * cerca) + pies, 0.0, 1.0));

	// --- Grano, por texel del atlas (va pegado al emu).
	vec2 t = floor(UV / TEXTURE_PIXEL_SIZE);
	float h = fract(sin(dot(t, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	g += h * (grano.x + grano.y * dot(g, LUM));

	// --- Canto suavizado, como los de la foto.
	vec2 rs = TEXTURE_PIXEL_SIZE * suavizar_px / px_por_texel;
	float a = (c.a * 2.0 + texture(TEXTURE, UV + vec2(rs.x, 0.0)).a + texture(TEXTURE, UV - vec2(rs.x, 0.0)).a
		+ texture(TEXTURE, UV + vec2(0.0, rs.y)).a + texture(TEXTURE, UV - vec2(0.0, rs.y)).a) / 6.0;

	// --- Bordes del cuadro del video.
	vec2 dentro = min(local - cuadro.xy, cuadro.xy + cuadro.zw - local);
	a *= smoothstep(0.0, 24.0, min(dentro.x, dentro.y));
	COLOR = vec4(g, a);
}
