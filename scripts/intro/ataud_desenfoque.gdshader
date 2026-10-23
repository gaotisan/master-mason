shader_type canvas_item;
// Pieza suelta de la sala del ataud (cerdo, pendulo, manta), para que case
// con el fondo pintado (ataud_camara.gd pone los valores):
//  - la misma bruma que el fondo a su profundidad: se mezcla con la luz de
//    alrededor del fondo (mipmap alto de la sala), lo que la apaga y le da el
//    color del sitio donde esta;
//  - se desenfoca a la par que el fondo cuando la vista se va al cristal.

// Radio del desenfoque en px de la textura.
uniform float radio = 0.0;
// Cuanta bruma (0..1).
uniform float neblina = 0.0;
uniform sampler2D sala : filter_linear_mipmap, repeat_disable;
uniform vec2 tam_sala = vec2(2912.0, 1632.0);

varying vec4 tinte;
varying vec2 mundo;

void vertex() {
	tinte = COLOR;
	mundo = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (radio > 0.3) {
		vec2 r = TEXTURE_PIXEL_SIZE * radio;
		vec4 c = texture(TEXTURE, UV) * 0.2;
		c += texture(TEXTURE, UV + r * vec2(1.0, 0.0)) * 0.1;
		c += texture(TEXTURE, UV + r * vec2(-1.0, 0.0)) * 0.1;
		c += texture(TEXTURE, UV + r * vec2(0.0, 1.0)) * 0.1;
		c += texture(TEXTURE, UV + r * vec2(0.0, -1.0)) * 0.1;
		c += texture(TEXTURE, UV + r * vec2(0.6, 0.6)) * 0.1;
		c += texture(TEXTURE, UV + r * vec2(-0.6, 0.6)) * 0.1;
		c += texture(TEXTURE, UV + r * vec2(0.6, -0.6)) * 0.1;
		c += texture(TEXTURE, UV + r * vec2(-0.6, -0.6)) * 0.1;
		COLOR = c * tinte;
	}
	if (neblina > 0.0) {
		vec3 humo = textureLod(sala, mundo / tam_sala, 5.5).rgb * 1.15;
		float gris = dot(COLOR.rgb, vec3(0.3, 0.55, 0.15));
		COLOR.rgb = mix(mix(vec3(gris), COLOR.rgb, 1.0 - neblina * 0.5), humo, neblina);
	}
}
