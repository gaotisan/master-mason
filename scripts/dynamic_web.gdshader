shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform float strength : hint_range(0.0, 50.0) = 15.0;
uniform vec4 web_color : source_color = vec4(0.9, 0.9, 1.0, 0.3);

void vertex() {
    // El movimiento aumenta con UV.y (la parte de abajo se mueve más)
    float wave = sin(TIME * speed + VERTEX.y * 0.05) * strength * UV.y;
    VERTEX.x += wave;
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    // Solo mostramos las líneas brillantes del ruido y las coloreamos
    COLOR = vec4(web_color.rgb, tex.r * web_color.a);
}
