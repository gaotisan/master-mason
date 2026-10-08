shader_type canvas_item;
// Madera del baston: solo se dibuja entre `desde` y `corte` (fracciones del
// alto, 0 arriba). Con la funda de cuero (2026-10-08), de perfil el baston va
// detras del cuerpo y una copia (MaderaDelante) pone delante solo el tramo del
// hombro a la funda; por debajo de la funda no se dibuja (va hacia la cadera
// contraria, tapado). 0 y 1 = entero.
uniform float desde : hint_range(0.0, 1.0) = 0.0;
uniform float corte : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// COLOR ya trae la textura por modulate / self_modulate (en la mano la
	// madera se esconde asi). Antes se volvia a multiplicar por la textura y la
	// madera salia al cuadrado: mucho mas oscura y saturada que baston.png, y
	// al guardar el baston no casaba con el ultimo fotograma de la animacion.
	COLOR.a *= 1.0 - smoothstep(corte - 0.008, corte, UV.y);
	if (desde > 0.0) {
		COLOR.a *= smoothstep(desde, desde + 0.008, UV.y);
	}
}
