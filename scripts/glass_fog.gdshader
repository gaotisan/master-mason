shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // RESPIRACIÓN SUTIL: Ritmo muy lento (~6 segundos) y rango mínimo (0.9 a 1.0)
    float breathing = (sin(TIME * 1.0) * 0.05) + 0.95;
    
    float noise = sin(uv.x * 20.0 + TIME * 0.1) * cos(uv.y * 20.0 - TIME * 0.1);
    
    // Intensidad base muy baja, apenas afectada por la respiración
    float fog_mask = (noise * 0.05 + 0.15) * breathing;
    fog_mask = clamp(fog_mask, 0.0, 0.25);
    
    vec4 screen_color = texture(SCREEN_TEXTURE, uv);
    // Color más transparente
    vec4 fog_color = vec4(0.85, 0.88, 0.92, 0.5); 
    
    vec4 final_color = mix(screen_color, fog_color, fog_mask);
    
    // Viñeta suave
    float vignette = distance(uv, vec2(0.5));
    final_color.rgb *= smoothstep(0.9, 0.35, vignette);
    
    COLOR = final_color;
}
