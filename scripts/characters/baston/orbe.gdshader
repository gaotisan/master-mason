shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;
// Bola del baston, toda por codigo. El cuadrado es mas grande que la bola para
// que quepa el halo: la esfera ocupa `radio` (fraccion del medio lado).
//   carga     0 vacia (cristal apagado) .. 1 llena
//   color     el de la magia; el brillo se pinta en neutro y se tine con esto
//   destello  1 justo al gastar, baja solo desde baston.gd
// La carga manda en todo a la vez, para que se lea el poder de un vistazo:
// cuanto sube el liquido de luz, lo que brilla, lo rapido que gira la
// espiral, el tamano del halo y, llena, un latido. Casi vacia, la brasa del
// fondo parpadea.

uniform float carga : hint_range(0.0, 1.0) = 1.0;
uniform vec3 color : source_color = vec3(1.0, 0.62, 0.18);
uniform float radio : hint_range(0.1, 1.0) = 0.34;
uniform float halo : hint_range(0.0, 3.0) = 1.1;
uniform float facetas : hint_range(1.0, 8.0) = 3.0;
uniform float destello : hint_range(0.0, 1.0) = 0.0;
// 1: solo el halo de fuera de la esfera (sin la esfera). PeregrinoFrontal lo pone
// en una copia por delante del cuerpo mientras la bola, detras, pasa de la mano a
// la espalda o al reves (en la espalda va delante y su halo cae sobre la capucha).
uniform float solo_halo : hint_range(0.0, 1.0) = 0.0;
// Con solo_halo: el baston que en la escena va encima del halo (su alfa lo tapa).
// mascara_uv: uv de la mascara = xy + UV * zw.
uniform sampler2D mascara : filter_linear, repeat_disable;
uniform vec4 mascara_uv = vec4(0.0, 0.0, 0.0, 0.0);
uniform float con_mascara = 0.0;

vec3 vidrio(vec3 n) {
	vec3 l = normalize(vec3(-0.45, -0.65, 0.6));
	float d = clamp(dot(n, l), 0.0, 1.0);
	return mix(vec3(0.04, 0.035, 0.05), vec3(0.22, 0.20, 0.24), d);
}

float ruido(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 / radio;     // 1 = borde de la esfera
	float r = length(p);
	float lleno_del_todo = smoothstep(0.97, 1.0, carga);
	float latido = 1.0 + 0.18 * pow(0.5 + 0.5 * sin(TIME * 3.2), 3.0) * lleno_del_todo;
	// casi vacia: la luz que queda tiembla
	float t8 = floor(TIME * 14.0);
	float temblor = mix(1.0, 0.55 + 0.45 * ruido(t8), 1.0 - smoothstep(0.08, 0.25, carga));
	float energia = (0.35 + 0.65 * carga) * latido * temblor;
	vec3 rgb = vec3(0.0);
	float a = 0.0;
	float borde = 1.0 - smoothstep(0.9, 1.0, r);
	if (r < 1.0) {
		vec3 n = vec3(p, sqrt(max(0.0, 1.0 - r * r)));
		vec3 nq = normalize(floor(n * facetas + 0.5) / facetas);
		vec3 base = vidrio(nq);
		// nivel del relleno: de abajo (p.y = 1) arriba (p.y = -1); un minimo
		// para que vacia quede una brasa en el fondo
		float c = max(carga, 0.06);
		float nivel = 1.0 - 2.0 * c;
		float ola = 0.09 * sin(p.x * 4.0 + TIME * 3.0) * (1.0 - lleno_del_todo);
		float lleno = smoothstep(nivel + ola - 0.05, nivel + ola + 0.05, p.y);
		// espiral: gira mas rapido cuanta mas carga
		float ang = atan(p.y, p.x);
		float giro = TIME * (0.8 + 2.6 * carga);
		float esp = 0.5 + 0.5 * sin(ang * 2.0 + r * 8.0 - giro);
		float esp2 = 0.5 + 0.5 * sin(ang * 3.0 - r * 5.0 + giro * 0.7);
		float nucleo = pow(1.0 - r, 1.4);
		float luz = (0.45 + 0.35 * esp + 0.2 * esp2) * (0.5 + nucleo) * energia;
		luz *= 0.82 + 0.25 * dot(nq, normalize(vec3(-0.3, -0.5, 0.8)));
		// el centro se va a blanco cuando esta cargada: es lo que dice "poder"
		vec3 caliente = mix(color, vec3(1.0, 0.97, 0.9), nucleo * carga * 0.75);
		vec3 brillo = caliente * luz * 1.6;
		// la linea de la superficie brilla un poco mas, para leer el nivel
		float linea = exp(-abs(p.y - (nivel + ola)) * 18.0) * (1.0 - lleno_del_todo);
		brillo += color * linea * 0.8 * energia;
		rgb = mix(base, brillo, lleno);
		rgb += color * linea * 0.5 * (1.0 - lleno);
		float spec = 1.0 - smoothstep(0.0, 0.25, length(p - vec2(-0.38, -0.42)));
		rgb += vec3(spec * 0.4);
		rgb += vec3(1.0) * destello * 0.9 * (1.0 - r * 0.5);
		a = borde;
		rgb *= a;
	}
	// halo aditivo (alfa 0 en premultiplicado = suma): crece con la carga
	float alcance = mix(5.0, 1.6, carga);
	float h = exp(-max(r - 0.95, 0.0) * alcance) * smoothstep(0.8, 1.0, r);
	// que se apague antes del borde del cuadrado, o se ve el recuadro
	h *= 1.0 - smoothstep(0.7, 1.0, length(UV - 0.5) * 2.0);
	float fuerza = halo * (0.08 + carga * carga) * energia + destello * 1.5;
	vec3 suma = mix(color, vec3(1.0), destello * 0.5) * h * fuerza * (1.0 - a);
	if (solo_halo > 0.5) {
		if (con_mascara > 0.5) {
			vec2 m = mascara_uv.xy + UV * mascara_uv.zw;
			if (m.x >= 0.0 && m.x <= 1.0 && m.y >= 0.0 && m.y <= 1.0) {
				suma *= 1.0 - texture(mascara, m).a;
			}
		}
		COLOR = vec4(suma, 0.0);
	} else {
		COLOR = vec4(rgb + suma, a);
	}
}
