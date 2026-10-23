shader_type canvas_item;
// Fondo del ataud con profundidad (prueba 2026-10-22). Lo maneja ataud_camara.gd.
//
// El fondo es una sola imagen. Aqui se parte en dos planos:
//  - el cristal (el marco del ataud y las telaranas grandes que cruzan la
//    ventana, mascara ataud_cristal.png): el color del fondo tal cual, quieto
//    respecto a la cabeza (lo mueve la Camera2D entera);
//  - la sala (ataud_sala.png, sin marco ni telaranas, rellena por debajo):
//    cada punto se desplaza segun su profundidad (ataud_profundidad.png, de
//    Depth Anything): lo del fondo de la sala se queda casi quieto en pantalla
//    y lo cercano se va con la cabeza, como al mover la cabeza de verdad.
// Encima, todo en esta misma pasada (en la P520 cada pasada a pantalla completa
// cuesta): niebla en dos capas a distinta profundidad, calima sobre las
// llamas, las dos cadenas meciendose, suciedad del cristal que coge la luz de
// detras, desenfoque por profundidad (foco en el cristal) y
// aberracion de color en el golpe.
//
// Sirve igual para los recortes iluminados de fondo_parches_luz.gd (usan el
// material del padre): en un Sprite2D con region, UV ya es la del fondo entero.

uniform sampler2D sala : filter_linear_mipmap, repeat_disable;
uniform sampler2D profundidad : filter_linear, repeat_disable;
uniform sampler2D cristal : filter_linear, repeat_disable;
uniform sampler2D ruido : filter_linear, repeat_enable;

// Lo que se ha movido la cabeza, en px del fondo. La sala se desplaza
// vista * (1 - profundidad) respecto al cristal.
uniform vec2 vista = vec2(0.0);
// 0 = foco en la sala; 1 = foco en el cristal (lo lejano se desenfoca).
uniform float foco_cristal = 0.0;
uniform float aberracion = 0.0;
uniform float niebla = 1.0;
uniform float suciedad = 1.0;
uniform float calima = 1.0;
uniform float cadenas = 1.0;
// Golpe en el cristal: xy = donde (px del fondo), z = segundos desde el golpe,
// w = fuerza. El cristal se comba y la sala se ondula vista a traves.
uniform vec4 golpe = vec4(0.0, 0.0, 99.0, 0.0);
// Llamas de las velas, en px del fondo (base de la llama).
uniform vec2 llamas[7];

vec2 girar(vec2 q, vec2 eje, float a) {
	vec2 r = q - eje;
	float c = cos(a);
	float s = sin(a);
	return eje + vec2(c * r.x - s * r.y, s * r.x + c * r.y);
}

// Peso de una cadena: rigida a lo largo, suave por los lados y al pie.
float cadena(vec2 q, float x, float largo) {
	float lado = 1.0 - smoothstep(26.0, 60.0, abs(q.x - x));
	float pie = 1.0 - smoothstep(largo, largo + 70.0, q.y);
	return lado * pie;
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 tam = 1.0 / px;
	vec2 desp = vista * px;

	// Punto de la sala que cae en este pixel: p + desp * (1 - d(p)) = UV.
	// Dos pasadas de punto fijo bastan con la profundidad suavizada y
	// desplazamientos de pocos px.
	vec2 p = UV;
	float d = texture(profundidad, p).r;
	p = UV - desp * (1.0 - d);
	d = texture(profundidad, p).r;
	p = UV - desp * (1.0 - d);

	vec2 q = p * tam;

	// Onda del golpe: anillos que salen del punto del golpe y se apagan.
	if (golpe.z < 0.7 && golpe.w > 0.0) {
		vec2 r = UV * tam - golpe.xy;
		float dist = length(r);
		float onda = sin(dist * 0.045 - golpe.z * 38.0) * exp(-golpe.z * 6.5) * exp(-dist * 0.0018);
		q += (dist > 1.0 ? r / dist : vec2(0.0)) * onda * 7.0 * golpe.w;
	}

	// Cadenas: cuelgan de detras del marco de arriba y se mecen un pelo.
	float t = TIME;
	float w1 = cadena(q, 1236.0, 650.0);
	float w2 = cadena(q, 1357.0, 545.0);
	if (cadenas > 0.0 && w1 + w2 > 0.0) {
		float a1 = (sin(t * 0.83) * 0.6 + sin(t * 1.91 + 1.3) * 0.25) * 0.0085 * cadenas;
		float a2 = (sin(t * 0.97 + 2.1) * 0.6 + sin(t * 2.23 + 0.4) * 0.25) * 0.0085 * cadenas;
		q = girar(q, vec2(1236.0, 130.0), a1 * w1);
		q = girar(q, vec2(1357.0, 130.0), a2 * w2);
	}

	// Calima: el aire caliente encima de cada llama ondula lo de detras. Solo
	// en la franja de alturas de las llamas (y = 658..891, 190 px por encima).
	float caliente = 0.0;
	if (calima > 0.0 && q.y > 460.0 && q.y < 895.0) {
		for (int i = 0; i < 7; i++) {
			vec2 r = q - llamas[i];
			if (abs(r.x) < 70.0) {
				float ancho = exp(-(r.x * r.x) / (2.0 * 22.0 * 22.0));
				float alto = smoothstep(-190.0, -70.0, r.y) * (1.0 - smoothstep(-26.0, -6.0, r.y));
				caliente += ancho * alto;
			}
		}
	}
	if (caliente > 0.001) {
		float n = texture(ruido, q * vec2(0.0045, 0.0028) + vec2(0.0, t * 0.22)).r;
		q.x += (n - 0.5) * 5.0 * min(caliente, 1.0) * calima;
	}

	vec2 ps = q * px;

	// Desenfoque del foco en el cristal: crece con lo lejos que esta cada cosa.
	float lod = foco_cristal * (1.0 - d) * 2.2;
	vec3 col;
	if (lod > 0.05) {
		vec2 r = px * exp2(lod) * 0.45;
		col = (textureLod(sala, ps + vec2(r.x, r.y * 0.4), lod).rgb
			+ textureLod(sala, ps + vec2(-r.x * 0.4, r.y), lod).rgb
			+ textureLod(sala, ps + vec2(-r.x, -r.y * 0.4), lod).rgb
			+ textureLod(sala, ps + vec2(r.x * 0.4, -r.y), lod).rgb) * 0.25;
	} else {
		col = textureLod(sala, ps, 0.0).rgb;
	}
	if (aberracion > 0.001) {
		vec2 hacia = (ps - 0.5) * aberracion * 0.006;
		col.r = textureLod(sala, ps + hacia, lod).r;
		col.b = textureLod(sala, ps - hacia, lod).b;
	}

	// Luz de alrededor (mipmap alto): da color a la niebla y a la suciedad,
	// asi se encienden cerca de las velas.
	vec3 alrededor = textureLod(sala, ps, 5.5).rgb;

	// Niebla en dos capas: una pegada a la pared del fondo y otra a media sala,
	// entre la mesa y la pared. Cada una con su propio desplazamiento.
	if (niebla > 0.0) {
		vec2 asp = vec2(tam.x / tam.y, 1.0);
		vec2 u1 = (UV - desp * 0.88) * asp * 0.9 + vec2(t * 0.0045, t * 0.0012);
		vec2 u2 = (UV - desp * 0.62) * asp * 1.6 + vec2(-t * 0.0075, t * 0.0021);
		float n1 = texture(ruido, u1).r;
		float n2 = texture(ruido, u2 + vec2(0.53, 0.29)).r;
		float lejos = 1.0 - smoothstep(0.08, 0.30, d);
		float medio = 1.0 - smoothstep(0.30, 0.52, d);
		float f = smoothstep(0.42, 0.85, n1) * lejos * 0.16 + smoothstep(0.48, 0.9, n2) * medio * 0.11;
		vec3 humo = alrededor * 1.25 + vec3(0.03, 0.028, 0.026);
		col = mix(col, humo, clamp(f * niebla, 0.0, 1.0));
	}

	// Cristal: la imagen tal cual donde hay marco o telarana.
	float m = texture(cristal, UV).r;
	vec3 vidrio = texture(TEXTURE, UV).rgb;
	col = mix(col, vidrio, m);

	// Suciedad del cristal: manchas que solo se ven donde hay luz detras.
	if (suciedad > 0.0) {
		vec2 asp = vec2(tam.x / tam.y, 1.0);
		float s = texture(ruido, UV * asp * 2.7 + vec2(0.31, 0.17)).r;
		float mancha = smoothstep(0.52, 0.8, s);
		float luz = dot(alrededor, vec3(0.3, 0.5, 0.2));
		col += alrededor * mancha * smoothstep(0.18, 0.55, luz) * 0.22 * suciedad * (1.0 - m);
	}

	COLOR = vec4(col, 1.0);
}
