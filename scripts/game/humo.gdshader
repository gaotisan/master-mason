shader_type canvas_item;
// Columna de humo lejana (los humos de la ciudad sin nombre). La textura es una
// columna suave; aqui se la hace subir y ondular un poco, muy despacio: esta a
// kilometros y tiene que leerse tranquila.

uniform float velocidad = 0.012;
uniform float ondula = 0.04;

void fragment() {
	vec2 uv = UV;
	float sube = TIME * velocidad;
	uv.x += sin((uv.y + sube) * 9.0) * ondula * (1.0 - uv.y);
	vec4 c = texture(TEXTURE, uv);
	// respiracion lenta de la densidad a lo largo de la columna
	c.a *= 0.8 + 0.2 * sin((uv.y * 6.0) + sube * 25.0);
	COLOR = c * COLOR;
}
