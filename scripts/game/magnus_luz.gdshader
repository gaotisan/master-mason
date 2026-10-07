shader_type canvas_item;
// La luz de la escena de la hojarasca sobre Magnus, sin tocar sus hojas de
// sprites: sin esto va iluminado plano y frio (capucha azulada) sobre un mundo
// ambar, y parece pegado encima.
//   - Tinte por posicion: en el haz, calido y claro; fuera, en penumbra parda.
//     La luz es la mancha del suelo (luz_en de hojarasca.py, con la que se
//     pinto el lecho) o el propio haz (el cono de fondo_haz), la que sea mas:
//     cayendo por dentro del haz se enciende, no solo al llegar al suelo.
//   - Oclusion junto al suelo: las hojas le quitan luz a los pies.
//   - Rebote dorado de la hojarasca en la parte baja de la tunica.
//   - Borde encendido arriba y del lado del haz (contraluz), como las hojas.
// Se le pone desde caida_hojarasca.gd; lado_luz lo actualiza cada fotograma.

uniform vec2 haz_origen = vec2(1620.0, -700.0);
uniform vec2 haz_destino = vec2(1456.0, 1200.0);
uniform float haz_apertura = 0.17;
uniform float y_suelo = 1200.0;
uniform vec3 color_luz : source_color = vec3(1.0, 0.83, 0.6);
uniform vec3 color_sombra : source_color = vec3(0.46, 0.37, 0.3);
uniform vec3 color_rebote : source_color = vec3(1.0, 0.6, 0.25);
uniform float rebote_fuerza = 0.22;
uniform float oclusion = 0.4;
uniform float borde_fuerza = 0.5;
uniform float borde_px = 3.0;
uniform float lado_luz = 0.0;   // -1..1 en x de UV del sprite

varying vec2 mundo;

void vertex() {
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float luz_en(vec2 p) {
	float dx = (p.x - haz_destino.x) / 1050.0;
	float dy = (p.y - haz_destino.y) / 520.0;
	float suelo = 0.28 + 0.87 * exp(-(dx * dx + 0.6 * dy * dy) * 1.6);
	vec2 eje = normalize(haz_destino - haz_origen);
	float a = acos(clamp(dot(normalize(p - haz_origen), eje), -1.0, 1.0));
	float haz = 0.28 + 0.8 * (1.0 - smoothstep(haz_apertura * 0.35, haz_apertura, a));
	return max(suelo, haz);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = luz_en(mundo);
	float t = clamp((l - 0.28) / 0.87, 0.0, 1.0);
	vec3 col = c.rgb * mix(color_sombra, color_luz, t) * (0.8 + 0.3 * t);
	// Rebote calido de las hojas: la tunica cerca del suelo.
	float bajo = smoothstep(y_suelo - 170.0, y_suelo - 20.0, mundo.y);
	col += color_rebote * c.rgb * rebote_fuerza * bajo * (0.4 + 0.6 * t);
	// Los pies, metidos en la hojarasca, reciben menos luz.
	col *= 1.0 - oclusion * smoothstep(y_suelo - 60.0, y_suelo - 4.0, mundo.y);
	// Borde de luz: pixel opaco cuyo vecino hacia la luz es transparente.
	vec2 hacia = normalize(vec2(lado_luz * 0.7, -1.0)) * borde_px * TEXTURE_PIXEL_SIZE;
	float vecino = texture(TEXTURE, UV + hacia).a;
	float borde = c.a * (1.0 - vecino);
	col += color_luz * borde * borde_fuerza * (0.25 + 0.75 * t);
	COLOR = vec4(col, c.a);
}
