shader_type canvas_item;
render_mode blend_add;
// El bosque de fondo (bosque_fondo_mj.png, de Midjourney; antes bosque_fondo.jpg,
// de Gemini), sumado a la oscuridad del
// fondo e iluminado por el mismo haz: los troncos que caen en el cono o junto
// al resplandor del suelo se ven, los de los lados casi no. La imagen viene casi
// negra (media 7/255) y aclarada tiene grano: exposicion moderada. Sin
// mipmaps ni compresion (en lo oscuro, la de video saca manchas).
// El suelo de la imagen (por debajo de la linea de los arboles) no se ve:
// nuestro lecho acaba en la oscuridad y su bruma, como sin el bosque. Iluminado
// salia una franja naranja; en sombra, una banda borrosa y plana detras del
// lecho que se leia como el suelo de la escena ("algo super cutre", 2026-10-13).
// El camino de la derecha (mascara bosque_camino*.png) no se ve hasta `camino`
// (0 tapado, 1 a la vista). En la de Midjourney el camino va por el suelo (sale
// del borde derecho y baja hasta el lecho): dentro de su mascara el suelo no se
// corta, asi que destapado se ve entero, y es lo unico del suelo que se ve.

uniform vec2 pantalla = vec2(2912.0, 1632.0);
uniform vec2 haz_origen = vec2(1620.0, -700.0);
uniform vec2 haz_destino = vec2(1456.0, 1200.0);
uniform float haz_apertura = 0.17;
uniform float exposicion = 2.2;
uniform float ambiente = 0.25;        // fuera de la luz
uniform float en_el_haz = 1.4;        // de mas dentro del cono
uniform float resplandor = 1.0;       // de mas junto a donde pega en el suelo
uniform vec2 resplandor_tam = vec2(900.0, 420.0);   // (mas, y la base de los troncos era una mancha rojiza)
uniform vec3 tinte : source_color = vec3(1.0, 0.86, 0.68);   // la luz calida del haz
uniform float horizonte = 0.677;      // v del borde de los arboles con el suelo (y 1040 de 1536)
uniform float suelo_luz = 0.0;        // el suelo de la imagen: nada
uniform float suelo_fundido = 0.024;  // en cuanto (fraccion del alto) se va: cortado en seco, los arboles flotan
uniform sampler2D mascara_camino : filter_linear;
uniform float camino : hint_range(0.0, 1.0) = 0.0;
uniform float camino_tapado = 0.0;    // lo que queda de el tapado

void fragment() {
	vec2 px = UV * pantalla;
	vec3 c = texture(TEXTURE, UV).rgb;
	vec2 eje = normalize(haz_destino - haz_origen);
	float a = acos(clamp(dot(normalize(px - haz_origen), eje), -1.0, 1.0));
	float cono = 1.0 - smoothstep(haz_apertura * 0.5, haz_apertura * 1.8, a);
	vec2 e = (px - haz_destino) / resplandor_tam;
	float glow = exp(-dot(e, e) * 1.2);
	float m = texture(mascara_camino, UV).r;
	float suelo = smoothstep(horizonte - 0.02, horizonte + suelo_fundido, UV.y) * (1.0 - m);
	float k = exposicion * mix(ambiente + en_el_haz * cono + resplandor * glow, suelo_luz, suelo);
	k *= mix(1.0, mix(camino_tapado, 1.0, camino), m);
	COLOR = vec4(c * tinte * k, 1.0);
}
