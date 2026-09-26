shader_type canvas_item;
// Hoja de la puerta abriendose hacia dentro.
//
// Vista de frente, una hoja que gira sobre la bisagra se estrecha (eso lo hace
// el script con scale.x = cos(angulo)) y ademas su canto lejano se va al fondo,
// asi que se ve algo mas bajo: la perspectiva lo encoge hacia la altura de los
// ojos. Eso es lo que hace este shader, y es lo que convierte "un rectangulo
// que adelgaza" en "una puerta que se abre".
//
// Se hace en el fragment, pixel a pixel, y no moviendo los vertices: con solo
// cuatro vertices el trapecio se partiria en dos triangulos con la textura
// torcida en la diagonal.
//
// El canto lejano, cuando se aparta, recibe la luz de dentro: un filo calido.

/// 0 = cerrada, 1 = abierta del todo (lo pone el script).
uniform float apertura : hint_range(0.0, 1.0) = 0.0;
/// Cuanto encoge el canto lejano con la puerta abierta del todo.
uniform float fuga : hint_range(0.0, 0.2) = 0.06;
/// Altura de los ojos en UV.y (0 = arriba de la hoja). El canto encoge hacia ahi.
uniform float altura_ojo : hint_range(0.0, 1.0) = 0.22;
uniform vec4 color_luz : source_color = vec4(1.0, 0.70, 0.36, 1.0);
/// Fuerza del filo de luz en el canto.
uniform float canto_luz : hint_range(0.0, 1.0) = 0.3;

varying vec4 tinte;

void vertex() {
	// modulate / self_modulate llegan aqui; se guardan porque el fragment
	// vuelve a leer la textura y sustituye COLOR.
	tinte = COLOR;
}

void fragment() {
	float k = fuga * apertura * UV.x;
	float v = (UV.y - altura_ojo) / (1.0 - k) + altura_ojo;
	vec4 tex = texture(TEXTURE, vec2(UV.x, v));
	tex.a *= step(0.0, v) * step(v, 1.0);
	vec4 c = tex * tinte;
	c.rgb += color_luz.rgb * canto_luz * apertura * smoothstep(0.86, 1.0, UV.x) * tex.a;
	COLOR = c;
}
