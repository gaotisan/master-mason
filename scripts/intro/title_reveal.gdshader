shader_type canvas_item;
// Mascara de oscuridad para la pantalla de titulo.
// Empieza en negro y va abriendo la imagen alrededor de las velas, luego el foco
// superior, y al final la luz del foco se derrama hasta llenar la sala.
// El revelado final es un degradado sin borde que baja desde el foco: nunca hay una
// linea ni un anillo recorriendo la pantalla, y ninguna parte del cuadro se adelanta
// a las demas. Cada zona sube de luz junto a lo que tiene al lado.
// Ademas dibuja el vaho del cristal del ataud (mismo ruido que vaho_cristal.gdshader),
// contenido dentro de la ventana del sarcofago que aparece en la propia imagen.
// Se dibuja con premultiplied alpha: rgb se SUMA (halos, frente de luz, brillo del
// titulo) y alpha OSCURECE lo que hay debajo.
render_mode unshaded, blend_premul_alpha;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float aspect = 1.784;
uniform float darkness : hint_range(0.0, 1.0) = 1.0;

// Velas (UV de la imagen)
uniform vec2 candle_a = vec2(0.2981, 0.5086);
uniform vec2 candle_b = vec2(0.6360, 0.5159);
uniform float candle_radius : hint_range(0.0, 1.0) = 0.0;
uniform float candle_a_flicker : hint_range(0.0, 1.5) = 1.0;
uniform float candle_b_flicker : hint_range(0.0, 1.5) = 1.0;
uniform float candle_glow : hint_range(0.0, 1.0) = 0.0;

// Foco superior (el "sol")
uniform vec2 sun_pos = vec2(0.503, 0.0);
uniform float sun_radius : hint_range(0.0, 2.0) = 0.0;
uniform float sun_intensity : hint_range(0.0, 1.0) = 0.0;

// Alcance de la luz que baja del foco. 0 = solo los charcos de luz de velas y foco;
// a partir de ~2.1 la claridad ha llegado hasta los rincones de abajo.
uniform float reveal_reach : hint_range(0.0, 2.5) = 0.0;

// Vaho / humo ambiental dentro de la ventana del ataud.
// window_rect = (x_min, y_min, x_max, y_max) del panel interior del marco.
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 window_rect = vec4(0.25, 0.288, 0.773, 0.699);

// Destello que recorre las letras del titulo
uniform float glint : hint_range(-1.0, 2.0) = -1.0;
uniform float glint_strength : hint_range(0.0, 1.0) = 0.75;
uniform vec4 title_rect = vec4(0.34, 0.33, 0.66, 0.62);

const vec3 CANDLE_COLOR = vec3(1.0, 0.62, 0.25);
const vec3 SUN_COLOR = vec3(1.0, 0.78, 0.45);
const vec3 GLINT_COLOR = vec3(1.0, 0.92, 0.7);
const vec3 FOG_COLOR = vec3(0.66, 0.60, 0.50);

float dist_uv(vec2 uv, vec2 p) {
	return length((uv - p) * vec2(aspect, 1.0));
}

// Hueco suave: 1 en el centro, 0 a partir del radio.
float pool(float d, float r) {
	if (r <= 0.0001) {
		return 0.0;
	}
	float x = clamp(d / r, 0.0, 1.0);
	return pow(1.0 - x, 1.6);
}

// Ruido de valor, igual que vaho_cristal.gdshader.
float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p + 33.33);
	return fract((p.x + p.y) * p.x);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.0) * 0.25;
}

// Mancha gaussiana elipsoidal, para anclar el vaho a sitios concretos.
float blob(vec2 uv, vec2 p, vec2 r) {
	vec2 d = (uv - p) / r;
	return exp(-dot(d, d));
}

// Densidad del vaho. No llena la ventana entera: son dos penachos subiendo de las
// llamas y una capa baja posada en el cristal, rotos en mechones por el ruido.
float fog_density(vec2 uv) {
	vec2 c = vec2(window_rect.x + window_rect.z, window_rect.y + window_rect.w) * 0.5;
	vec2 half_size = vec2(window_rect.z - window_rect.x, window_rect.w - window_rect.y) * 0.5;
	vec2 q = (uv - c) / half_size;

	// Ruido con el dominio deformado: mechones con huecos, no una mancha lisa.
	vec2 p = uv * vec2(aspect, 1.0) * 3.0;
	vec2 drift = vec2(TIME * 0.022, -TIME * 0.048);
	vec2 warp = vec2(fbm(p * 0.8 + drift), fbm(p * 0.8 + drift + 5.7)) - 0.5;
	float n = fbm(p + drift + warp * 1.2) * 0.78 + fbm(p * 2.1 - drift * 1.6) * 0.34;
	n = clamp(n * 2.0 - 0.38, 0.0, 1.0);
	n = n * n * (3.0 - 2.0 * n);

	// Penachos sobre cada vela y bruma posada en la parte baja del cristal.
	float m = blob(uv, candle_a + vec2(0.0, -0.055), vec2(0.055, 0.09)) * candle_glow;
	m += blob(uv, candle_b + vec2(0.0, -0.055), vec2(0.055, 0.09)) * candle_glow;
	m += blob(uv, vec2(c.x, window_rect.w - 0.075), vec2(0.25, 0.085)) * 0.95;
	m = clamp(m, 0.0, 1.0);

	// Garantia de que nada se sale de la ventana del ataud.
	float box = 1.0 - smoothstep(0.72, 1.0, length(vec2(q.x * 0.95, q.y)));
	return m * box * n;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 scr = texture(screen_texture, uv);
	float lum = dot(scr.rgb, vec3(0.3, 0.59, 0.11));

	// Velas: el hueco respira con el parpadeo.
	float da = dist_uv(uv, candle_a);
	float db = dist_uv(uv, candle_b);
	float ra = candle_radius * (0.85 + 0.15 * candle_a_flicker);
	float rb = candle_radius * (0.85 + 0.15 * candle_b_flicker);
	float la = pool(da, ra) * min(candle_a_flicker, 1.0);
	float lb = pool(db, rb) * min(candle_b_flicker, 1.0);

	// Foco superior.
	float ds = dist_uv(uv, sun_pos);
	float ls = pool(ds, sun_radius) * sun_intensity;

	// --- Derrame de luz desde el foco ---
	// Distancia achatada en horizontal: la claridad baja por la pared como la luz de
	// un tragaluz, en vez de abrirse en circulo. Un ruido lento le quita simetria.
	float dv = length(vec2((uv.x - sun_pos.x) * aspect * 0.5, uv.y - sun_pos.y));
	float grain = fbm(uv * vec2(aspect, 1.0) * 2.1 + vec2(TIME * 0.01, -TIME * 0.016)) - 0.375;
	float lr = clamp(reveal_reach - dv * 0.9 + grain * 0.3, 0.0, 1.0);

	float light = max(max(la, lb), max(ls, lr));
	float dark = clamp(1.0 - light, 0.0, 1.0) * darkness;

	// --- Luz aditiva ---
	vec3 add = vec3(0.0);

	// Halo calido de cada vela (sutil).
	float ga = exp(-(da * da) / 0.0022) * candle_a_flicker;
	float gb = exp(-(db * db) / 0.0022) * candle_b_flicker;
	add += CANDLE_COLOR * (ga + gb) * candle_glow * 0.22;

	// Destello sobre las letras: banda diagonal enmascarada por el brillo de la imagen.
	float letters = smoothstep(0.42, 0.72, lum);
	float in_rect = smoothstep(title_rect.x, title_rect.x + 0.03, uv.x) * (1.0 - smoothstep(title_rect.z - 0.03, title_rect.z, uv.x))
		* smoothstep(title_rect.y, title_rect.y + 0.03, uv.y) * (1.0 - smoothstep(title_rect.w - 0.03, title_rect.w, uv.y));
	float g = (uv.x - title_rect.x) / (title_rect.z - title_rect.x) + (uv.y - 0.5) * 0.45;
	float band = exp(-pow((g - glint) / 0.085, 2.0));
	add += GLINT_COLOR * band * letters * in_rect * glint_strength;

	// --- Vaho ---
	// El humo solo se ve donde le da luz: al principio son jirones alrededor de
	// cada llama, y cuando la sala se revela queda como bruma en toda la ventana.
	float lit = clamp(max(light, (ga + gb) * candle_glow), 0.0, 1.0);
	float fog = clamp(fog_density(uv) * fog_amount * (0.6 + 0.4 * lit), 0.0, 0.7);
	vec3 fog_col = mix(FOG_COLOR, vec3(0.85, 0.6, 0.36), clamp((ga + gb) * candle_glow * 1.2, 0.0, 1.0));

	// Composicion premultiplicada: primero se oscurece la sala, luego el vaho se
	// interpone entre el espectador y todo lo demas, incluida la luz aditiva.
	float alpha = 1.0 - (1.0 - dark) * (1.0 - fog);
	COLOR = vec4(add * (1.0 - fog) + fog_col * fog, alpha);
}
