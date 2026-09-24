shader_type canvas_item;
// Mascara de oscuridad para la pantalla de titulo. Todo se cuenta con luz:
//  - Charcos de luz de las dos velas, donde estan en la imagen.
//  - Foco de arriba, el "sol", iluminando la pared alta.
//  - Contorno del cristal del ataud: el marco del panel se dibuja en la oscuridad.
//  - Y al final ese mismo foco crece y se queda: es su luz la que acaba llegando a
//    toda la sala. No hay barrido ni frente que viaje, es el charco haciendose
//    grande, con un rebote de fondo que termina de sacar los rincones.
// Ademas dibuja el vaho del cristal (mismo ruido que vaho_cristal.gdshader),
// contenido en la ventana del sarcofago que la imagen tiene pintada, y al final un
// destello recorre las letras del titulo.
// Se dibuja con premultiplied alpha: rgb se SUMA (halos, destello, vaho) y alpha
// OSCURECE lo que hay debajo.
render_mode unshaded, blend_premul_alpha;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float aspect = 1.784;
uniform float darkness : hint_range(0.0, 1.0) = 1.0;
// Trozo de la imagen que la camara tiene en pantalla, en UV de la imagen
// (x_min, y_min, x_max, y_max). Las luces estan medidas sobre la imagen, asi que
// cuando la camara hace zoom la mascara se mueve con ella y no se queda pegada al
// cristal de la pantalla.
uniform vec4 view_rect = vec4(0.0, 0.0, 1.0, 1.0);

// Velas (UV de la imagen)
uniform vec2 candle_a = vec2(0.2981, 0.5086);
uniform vec2 candle_b = vec2(0.6360, 0.5159);
uniform float candle_radius : hint_range(0.0, 1.0) = 0.0;
uniform float candle_a_flicker : hint_range(0.0, 1.5) = 1.0;
uniform float candle_b_flicker : hint_range(0.0, 1.5) = 1.0;
uniform float candle_glow : hint_range(0.0, 1.0) = 0.0;
// 1 encendida, 0 apagada. La llama esta pintada en la imagen, asi que al apagar
// una vela hay que tapar el dibujo: una sombra pequena justo donde estaba.
uniform float candle_a_on : hint_range(0.0, 1.0) = 1.0;
uniform float candle_b_on : hint_range(0.0, 1.0) = 1.0;

// Foco superior (el "sol")
uniform vec2 sun_pos = vec2(0.503, 0.0);
uniform float sun_radius : hint_range(0.0, 4.0) = 0.0;
uniform float sun_intensity : hint_range(0.0, 1.0) = 0.0;

// Rebote: la luz que el foco reparte por la sala cuando ya es fuerte. Termina de
// sacar los rincones a los que el charco no llega.
uniform float room_light : hint_range(0.0, 1.0) = 0.0;

// Contorno del cristal del ataud, el marco del panel de la imagen.
uniform float frame_light : hint_range(0.0, 1.0) = 0.0;
// Oscuridad propia del interior del cristal, para la salida: al apagarse las
// velas es el rectangulo lo que se apaga, aunque fuera siga dando el foco.
uniform float window_dark : hint_range(0.0, 1.0) = 0.0;
uniform float frame_width : hint_range(0.005, 0.2) = 0.032;

// Destello que recorre las letras del titulo.
uniform float glint : hint_range(-1.0, 2.0) = -1.0;
uniform float glint_strength : hint_range(0.0, 1.0) = 0.75;
uniform vec4 title_rect = vec4(0.34, 0.33, 0.66, 0.62);

// Apagado de las letras del titulo, para la salida: estan pintadas en la imagen,
// y oscurecer el cristal no basta porque oscurece letra y panel por igual y las
// letras siguen leyendose cuando la camara ya se esta metiendo por el hueco.
// No se tapan con una sombra (saldrian en negativo, mas oscuras que el panel):
// se les quita el brillo que les sobra hasta dejarlas al nivel del panel, asi que
// lo que ya era panel no se entera y la letra se funde en el.
uniform float title_fade : hint_range(0.0, 1.0) = 0.0;
// Los bordes del rectangulo van difuminados, asi que tiene que sobrar sitio por
// los cuatro lados: las letras ocupan x 0.376-0.556, y 0.364-0.577, y si el
// difuminado las pilla se quedan a medio apagar los trazos de los extremos (el
// palo de la M, la base de MASON). La vela derecha (x 0.636) queda fuera: a
// x 0.61 la imagen ya vuelve a ser panel.
uniform vec4 title_fade_rect = vec4(0.340, 0.334, 0.595, 0.610);
// Brillo del panel detras de las letras, medido sobre el PNG a los lados de cada
// trazo: (arriba, abajo). Es una rampa y no un numero porque el panel va de 0.27
// arriba a 0.15 abajo, y con un valor fijo "THE" acaba mas oscura que su fondo y
// "MASON" mas clara, que es justo el negativo que se queria quitar.
uniform vec2 title_panel_lum = vec2(0.266, 0.149);
// Color del panel ahi mismo. Solo se usa el tono: el nivel lo pone la rampa.
uniform vec3 title_panel_col = vec3(0.315, 0.152, 0.048);
// Cuanto se rellena el relieve oscuro. No llega a 1: aplanar del todo dejaria un
// rectangulo liso dentro del panel, que se nota tanto como las letras.
uniform float title_fill : hint_range(0.0, 1.0) = 0.9;

// Vaho / humo ambiental dentro de la ventana del ataud.
// window_rect = (x_min, y_min, x_max, y_max) del panel interior del marco.
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 window_rect = vec4(0.2215, 0.320, 0.755, 0.702);

const vec3 LUMW = vec3(0.3, 0.59, 0.11);
const vec3 CANDLE_COLOR = vec3(1.0, 0.62, 0.25);
const vec3 SUN_COLOR = vec3(1.0, 0.80, 0.48);
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

// Distancia al borde del rectangulo de la ventana: negativa dentro, positiva
// fuera, cero justo en el marco. Sirve para encender solo el contorno.
float border_dist(vec2 uv, vec4 r) {
	vec2 c = vec2(r.x + r.z, r.y + r.w) * 0.5;
	vec2 h = vec2(r.z - r.x, r.w - r.y) * 0.5;
	vec2 d = (abs(uv - c) - h) * vec2(aspect, 1.0);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
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

	vec2 p = uv * vec2(aspect, 1.0) * 3.0;
	vec2 drift = vec2(TIME * 0.022, -TIME * 0.048);
	vec2 warp = vec2(fbm(p * 0.8 + drift), fbm(p * 0.8 + drift + 5.7)) - 0.5;
	float n = fbm(p + drift + warp * 1.2) * 0.78 + fbm(p * 2.1 - drift * 1.6) * 0.34;
	n = clamp(n * 2.0 - 0.38, 0.0, 1.0);
	n = n * n * (3.0 - 2.0 * n);

	float m = blob(uv, candle_a + vec2(0.0, -0.055), vec2(0.055, 0.09)) * candle_glow;
	m += blob(uv, candle_b + vec2(0.0, -0.055), vec2(0.055, 0.09)) * candle_glow;
	m += blob(uv, vec2(c.x, window_rect.w - 0.075), vec2(0.25, 0.085)) * 0.95;
	m = clamp(m, 0.0, 1.0);

	float box = 1.0 - smoothstep(0.72, 1.0, length(vec2(q.x * 0.95, q.y)));
	return m * box * n;
}

void fragment() {
	// uv en el espacio de la imagen; la textura de pantalla se lee donde toca.
	vec2 uv = mix(view_rect.xy, view_rect.zw, SCREEN_UV);
	vec4 scr = texture(screen_texture, SCREEN_UV);
	float lum = dot(scr.rgb, LUMW);

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

	// Contorno del cristal del ataud.
	float bd = border_dist(uv, window_rect);
	float lf = exp(-pow(bd / frame_width, 2.0)) * frame_light;

	float light = max(max(la, lb), max(max(ls, lf), room_light));
	float dark = clamp(1.0 - light, 0.0, 1.0) * darkness;

	// Vela apagada: se tapa la llama pintada con una sombra suave donde estaba.
	// No llega a negro: asi, cuando el cristal ya esta apagado, la sombra se
	// funde con el y no queda un punto mas oscuro que el resto.
	float snuff = exp(-(da * da) / 0.0015) * (1.0 - candle_a_on)
		+ exp(-(db * db) / 0.0015) * (1.0 - candle_b_on);
	dark = max(dark, clamp(snuff, 0.0, 1.0) * 0.85 * darkness);

	// El interior del cristal se apaga por su cuenta. El borde queda fuera de la
	// sombra para que el marco siga dibujando el rectangulo.
	float inside = 1.0 - smoothstep(-0.03, 0.0, bd);
	dark = max(dark, inside * window_dark * darkness);

	// Las letras del titulo se aplanan contra el panel. Estan talladas, asi que no
	// basta con quitarles el brillo: se quedaria el relieve oscuro leyendose en
	// negativo, que es lo que peor queda con la camara ya dentro del hueco. Se
	// tocan los dos lados: lo que sobresale del panel se baja aqui (por debajo de
	// la sombra del cristal, no con max(), porque esa baja letra y panel por igual
	// y no borra la diferencia), y el relieve oscuro se rellena mas abajo con luz.
	float in_title = smoothstep(title_fade_rect.x, title_fade_rect.x + 0.025, uv.x)
		* (1.0 - smoothstep(title_fade_rect.z - 0.025, title_fade_rect.z, uv.x))
		* smoothstep(title_fade_rect.y, title_fade_rect.y + 0.025, uv.y)
		* (1.0 - smoothstep(title_fade_rect.w - 0.025, title_fade_rect.w, uv.y));
	float title_mix = in_title * title_fade;
	float title_panel = mix(title_panel_lum.x, title_panel_lum.y,
		clamp((uv.y - title_fade_rect.y) / max(title_fade_rect.w - title_fade_rect.y, 0.001), 0.0, 1.0));
	float flatten = clamp(1.0 - title_panel / max(lum, 0.001), 0.0, 1.0) * title_mix;
	dark = clamp(1.0 - (1.0 - dark) * (1.0 - flatten * darkness), 0.0, 1.0);
	// Brillo que tendran estas letras una vez aplanadas. Lo que venga despues tiene
	// que mirar esto y no lum: el calor del foco se reparte segun lo cargado que
	// este ya el pixel, y con lum las letras se quedaban sin su parte y salian a
	// media luz sobre el panel, o sea seguian leyendose.
	float lum_flat = mix(lum, title_panel, title_mix);

	// --- Luz aditiva ---
	vec3 add = vec3(0.0);

	// Halo calido de cada vela (sutil).
	float ga = exp(-(da * da) / 0.0022) * candle_a_flicker;
	float gb = exp(-(db * db) / 0.0022) * candle_b_flicker;
	add += CANDLE_COLOR * (ga + gb) * candle_glow * 0.22;

	// Un poco de calor del foco, solo donde el cuadro tiene sitio para mas luz:
	// asi la parte alta se siente iluminada sin llegar a reventar a blanco.
	float headroom = 1.0 - smoothstep(0.35, 0.85, lum_flat);
	add += SUN_COLOR * pool(ds, sun_radius * 0.8) * sun_intensity * headroom * 0.1;

	// Destello sobre las letras: banda diagonal enmascarada por el brillo de la imagen.
	float letters = smoothstep(0.42, 0.72, lum);
	float in_rect = smoothstep(title_rect.x, title_rect.x + 0.03, uv.x) * (1.0 - smoothstep(title_rect.z - 0.03, title_rect.z, uv.x))
		* smoothstep(title_rect.y, title_rect.y + 0.03, uv.y) * (1.0 - smoothstep(title_rect.w - 0.03, title_rect.w, uv.y));
	float gl = (uv.x - title_rect.x) / (title_rect.z - title_rect.x) + (uv.y - 0.5) * 0.45;
	float band = exp(-pow((gl - glint) / 0.085, 2.0));
	add += GLINT_COLOR * band * letters * in_rect * glint_strength;

	// Relleno del relieve oscuro de las letras: solo donde la imagen esta por
	// debajo del panel. Va multiplicado por (1.0 - dark) para que se apague con la
	// sala; si no, al final quedaria un fantasma encendido sobre el negro.
	float sunken = clamp(title_panel - lum, 0.0, 1.0) * title_mix * title_fill;
	add += title_panel_col * (sunken / max(dot(title_panel_col, LUMW), 0.001)) * (1.0 - dark);

	// --- Vaho ---
	// El humo solo se ve donde le da luz: al principio son jirones alrededor de
	// cada llama, y se apaga del todo cuando la sala ya esta a la vista.
	float lit = clamp(max(light, (ga + gb) * candle_glow), 0.0, 1.0);
	float fog = clamp(fog_density(uv) * fog_amount * (0.6 + 0.4 * lit), 0.0, 0.7);
	vec3 fog_col = mix(FOG_COLOR, vec3(0.85, 0.6, 0.36), clamp((ga + gb) * candle_glow * 1.2, 0.0, 1.0));

	// Composicion premultiplicada: primero se oscurece la sala, luego el vaho se
	// interpone entre el espectador y todo lo demas, incluida la luz aditiva.
	float alpha = 1.0 - (1.0 - dark) * (1.0 - fog);
	COLOR = vec4(add * (1.0 - fog) + fog_col * fog, alpha);
}
