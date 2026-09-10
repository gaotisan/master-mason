shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.3;
uniform float speed : hint_range(0.0, 5.0) = 2.0;
uniform float border_size : hint_range(0.0, 0.5) = 0.15;

void fragment() {
    vec2 uv = UV;
    vec4 tex = texture(TEXTURE, uv);
    
    // Calcular distancia al borde (más efecto en esquinas y bordes)
    float dist_left = uv.x;
    float dist_right = 1.0 - uv.x;
    float dist_top = uv.y;
    float dist_bottom = 1.0 - uv.y;
    
    float border_mask = 1.0 - smoothstep(
        0.0,
        border_size,
        min(min(dist_left, dist_right), min(dist_top, dist_bottom))
    );
    
    // Esquinas tienen más efecto
    float corner_boost =
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_left)) *
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_top));

    corner_boost +=
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_right)) *
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_top));

    corner_boost +=
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_left)) *
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_bottom));

    corner_boost +=
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_right)) *
        (1.0 - smoothstep(0.0, border_size * 2.0, dist_bottom));
    
    float mask = max(border_mask, corner_boost * 0.5);
    
    // Desplazamiento errático tipo viento
    float time_offset = TIME * speed;
    float shake_x = sin(time_offset * 1.7 + uv.y * 10.0) * cos(time_offset * 0.9);
    float shake_y = cos(time_offset * 1.3 + uv.x * 8.0) * sin(time_offset * 1.1);
    
    vec2 offset = vec2(shake_x, shake_y) * intensity * 0.008 * mask;
    
    COLOR = texture(TEXTURE, uv + offset);
}
