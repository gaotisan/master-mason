shader_type canvas_item;
render_mode blend_add;
// Luz de las ventanas de la casa de Dominus: "una luz temblorosa".
//
// La capa se SUMA encima de la silueta (blend_add): negro = nada, y el alfa de
// la textura dice cuanta luz calida se anade. Asi el nivel la apaga o la
// enciende con el alfa del modulate, sin tocar la casa.
//
// POR QUE UNA LISTA DE LUCES Y NO RUIDO EN EL ESPACIO. Con ruido que depende de
// la posicion, el temblor cambia DENTRO de cada ventana (media ventana brilla y
// la otra no) y se ve como una ola que cruza la fachada. Una vela tiembla
// entera. Aqui cada fuente (cada ventana encendida y el vano de la puerta) lleva
// su propio reloj, y cada pixel mezcla los relojes de las fuentes cercanas con
// un peso gaussiano: el cristal y su halo tiemblan juntos, y donde se tocan dos
// halos el paso es suave, sin costuras. Son ~11 fuentes: nada para la GPU.
//
// Los datos salen de casa_meta.json ("luces_shader"), que escribe
// tools/mundo/casa_exterior.py. Si se mueven ventanas, se copian otra vez al
// parametro "luces" del material en casa_exterior.tscn.

/// Cuanto baja o sube la luz como mucho. 0,1 ya se nota; mas de 0,25 parece
/// una bombilla que falla, no una vela.
uniform float temblor : hint_range(0.0, 0.5) = 0.13;
/// Velocidad del temblor. 1 = vela en una habitacion sin corrientes.
uniform float velocidad : hint_range(0.0, 4.0) = 1.0;
/// Fuentes: xy = centro en UV, z = radio de influencia en UV de x, w = semilla.
uniform vec4 luces[16];
uniform int n_luces = 0;
/// Alto / ancho de la textura, para que el radio sea redondo y no ovalado.
uniform float aspecto = 0.476923;

float hash1(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

// Ruido de valor 1D suave: el vaiven de una llama no tiene saltos.
float ruido1(float x) {
	float i = floor(x);
	float f = fract(x);
	float u = f * f * (3.0 - 2.0 * f);
	return mix(hash1(i), hash1(i + 1.0), u);
}

// El pulso de una vela: un vaiven lento, un chisporroteo pequeno encima y, de
// vez en cuando, una bajada mas honda (una corriente de aire). Centrado en 0.
float llama(float semilla, float t) {
	float lento = ruido1(t * 1.1 + semilla * 37.0) - 0.5;
	float rapido = ruido1(t * 6.7 + semilla * 91.0) - 0.5;
	float racha = pow(ruido1(t * 0.43 + semilla * 53.0), 5.0);
	return lento * 1.3 + rapido * 0.45 - racha * 1.6;
}

void fragment() {
	float t = TIME * velocidad;
	float suma = 0.0;
	float peso = 0.0;
	for (int i = 0; i < n_luces; i++) {
		vec4 l = luces[i];
		vec2 d = (UV - l.xy) * vec2(1.0, aspecto);
		float w = exp(-dot(d, d) / (l.z * l.z));
		suma += w * llama(l.w, t);
		peso += w;
	}
	float f = peso > 0.0001 ? suma / peso : 0.0;
	// COLOR ya trae textura * modulate: se escala, no se sustituye, para que el
	// modulate (intensidad_luz) siga mandando.
	COLOR.rgb *= max(0.0, 1.0 + temblor * f);
}
