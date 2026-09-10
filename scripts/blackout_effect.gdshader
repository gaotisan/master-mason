shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float blackout : hint_range(0.0, 1.0) = 0.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 color = vec4(0.0);
	
	float blur = blur_amount * 0.001;
	
	if (blur > 0.0005) {
		// Blur gaussiano con más muestras para suavidad
		float total_weight = 0.0;
		
		// Kernel 5x5 aproximado
		for (float x = -2.0; x <= 2.0; x += 1.0) {
			for (float y = -2.0; y <= 2.0; y += 1.0) {
				float weight = exp(-(x*x + y*y) / 4.0);
				vec2 offset = vec2(x, y) * blur;
				color += texture(screen_texture, uv + offset) * weight;
				total_weight += weight;
			}
		}
		color /= total_weight;
	} else {
		color = texture(screen_texture, uv);
	}
	
	// Tinte dorado suave
	vec3 golden = vec3(0.88, 0.72, 0.38);
	color.rgb = mix(color.rgb, color.rgb * golden, tint_amount * 0.5);
	
	// Viñeta suave
	vec2 center_offset = uv - vec2(0.5);
	float dist = length(center_offset);
	float vignette = smoothstep(0.25, 0.85, dist);
	color.rgb = mix(color.rgb, color.rgb * (1.0 - vignette * 0.9), vignette_intensity);
	
	// Parpadeo - párpados suaves
	float eyelid_close = blink;
	float top_lid = smoothstep(eyelid_close * 0.5, eyelid_close * 0.5 + 0.05, uv.y);
	float bottom_lid = smoothstep(eyelid_close * 0.5, eyelid_close * 0.5 + 0.05, 1.0 - uv.y);
	float eye_open = top_lid * bottom_lid;
	color.rgb *= eye_open;
	
	// Fundido a negro suave
	color.rgb = mix(color.rgb, vec3(0.0), blackout);
	
	COLOR = vec4(color.rgb, 1.0);
}
