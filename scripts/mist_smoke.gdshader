shader_type canvas_item;

uniform float speed : hint_range(0.0, 1.0) = 0.06;
uniform float density : hint_range(0.0, 2.0) = 1.0;
uniform vec4 smoke_color : source_color = vec4(0.48, 0.38, 0.25, 0.55);

// ------------------ NOISE ------------------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * speed;

    // -------- Domain warping estable --------
    vec2 warp;
    warp.x = noise(uv * 2.0 + vec2(t, 0.0));
    warp.y = noise(uv * 2.0 + vec2(0.0, t));

    vec2 warped_uv = uv * 3.0 + warp * 0.6;

    float n1 = noise(warped_uv + vec2(t * 0.6, 0.0));
    float n2 = noise(warped_uv * 0.7 - vec2(0.0, t * 0.4));

    float combined = (n1 + n2) * 0.5;
    float dust = smoothstep(0.45, 0.75, combined * density);

    // -------- MÁSCARA CENTRADA Y CONTROLADA --------
    vec2 center = vec2(0.5, 0.4);   // CENTRO REAL, un poco más arriba
    vec2 scale  = vec2(1.2, 1.0);   // ligeramente más ancho

    vec2 d = (uv - center) * scale;
    float mask = length(d);

    // radio claro, sin invadir bordes derechos
    mask = smoothstep(0.85, 0.0, mask);

    float alpha = dust * mask * smoke_color.a;

    COLOR = vec4(smoke_color.rgb, alpha);
}
