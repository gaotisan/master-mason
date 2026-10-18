shader_type canvas_item;
render_mode blend_add, unshaded;
// Lo que rodea a la bola de la marca de guardado (marca_guardado.gd), como lo
// que se penso para la bola del baston (baston.gd: "al recargarse, motas de luz
// que entran en la bola; llena, chispas que suben despacio"), pero en brillos
// suaves y no en pixeles:
//   recarga  0..1  motas que vienen de alrededor y se meten en la bola
//   chispas  0..1  llena: unas pocas chispas que suben despacio y se apagan
// Suma (es luz). El cuadrado es mayor que la bola; radio_bola es su radio en
// fracciones del medio lado.

uniform float recarga : hint_range(0.0, 1.0) = 0.0;
uniform float chispas : hint_range(0.0, 1.0) = 0.0;
uniform float radio_bola = 0.16;
uniform vec3 color : source_color = vec3(1.0, 0.62, 0.18);
uniform float semilla = 0.0;

const int MOTAS = 9;
const int CHISPAS = 3;

float azar(float n) {
	return fract(sin(n * 91.345 + semilla * 7.13) * 47453.5453);
}

float brillo(vec2 p, vec2 c, float r) {
	vec2 d = p - c;
	return exp(-dot(d, d) / (r * r));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;      // -1..1 en el cuadrado
	float luz = 0.0;
	// Motas: cada una en su ciclo, desde un angulo al azar, entra en espiral
	// suave hasta el borde de la bola y se apaga al tocarla.
	for (int i = 0; i < MOTAS; i++) {
		float fi = float(i);
		float periodo = 0.9 + 0.5 * azar(fi);
		float t = fract(TIME / periodo + azar(fi + 17.0));
		float ciclo = floor(TIME / periodo + azar(fi + 17.0));
		float ang = 6.2832 * azar(fi * 3.1 + ciclo * 1.7) + t * 0.9;
		float r = mix(0.85, radio_bola * 1.05, t * t * (3.0 - 2.0 * t));
		vec2 c = vec2(cos(ang), sin(ang)) * r;
		float vida = smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.8, 1.0, t));
		float tam = mix(0.035, 0.022, t);
		luz += brillo(p, c, tam) * vida * 0.9 + brillo(p, c, tam * 2.6) * vida * 0.18;
	}
	luz *= recarga;
	// Chispas: suben despacio desde lo alto de la bola, se mecen y se apagan.
	float ch = 0.0;
	for (int i = 0; i < CHISPAS; i++) {
		float fi = float(i) + 40.0;
		float periodo = 1.6 + 0.6 * azar(fi);
		float t = fract(TIME / periodo + azar(fi + 5.0));
		float ciclo = floor(TIME / periodo + azar(fi + 5.0));
		float x0 = (azar(fi + ciclo * 2.3) - 0.5) * radio_bola * 1.2;
		vec2 c = vec2(x0 + sin(t * 5.0 + fi) * 0.04, -radio_bola * 0.8 - t * 0.6);
		float vida = smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.5, 1.0, t));
		ch += brillo(p, c, 0.02) * vida + brillo(p, c, 0.05) * vida * 0.15;
	}
	luz += ch * chispas;
	// que no llegue al borde del cuadrado
	luz *= 1.0 - smoothstep(0.85, 1.0, length(p));
	vec3 c = mix(color, vec3(1.0, 0.92, 0.75), 0.45);
	COLOR = vec4(c * luz, 1.0);
}
