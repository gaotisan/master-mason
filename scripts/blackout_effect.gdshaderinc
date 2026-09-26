// Cuerpo comun de blackout_effect.gdshader y blackout_effect_lod0.gdshader. Cada
// uno declara antes screen_texture: el primero con mipmaps y el segundo sin.
uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float blackout : hint_range(0.0, 1.0) = 0.0;
uniform float blink : hint_range(0.0, 1.0) = 0.0;
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec4 color = vec4(0.0);
	
	float blur = blur_amount * 0.001;
	
	if (blur > 0.0005) {
		// Kernel 3x3. Antes el paso iba en UV (blur * 2), que en 2912x1632 son 1,78
		// veces mas pixeles en horizontal que en vertical, y con lecturas sueltas
		// separadas hasta 20 px: las velas y los hilos salian en tres copias en fila
		// en vez de deshacerse. Ahora el paso es igual en los dos ejes y sale de la
		// media geometrica de los dos pasos viejos (asi no depende de la
		// resolucion), al 0,8: comparado en capturas, con eso los primeros segundos
		// del desmayo (blur 0,5-2,5) se ven igual de borrosos que antes. Cada
		// lectura va a un mipmap ya suavizado (unas 4 veces mas fino que el paso)
		// que rellena el hueco entre lecturas: sin copias fantasma y sin bloques.
		vec2 px = 1.0 / SCREEN_PIXEL_SIZE;
		float paso_px = blur * 1.6 * sqrt(px.x * px.y);
		float lod = clamp(log2(max(paso_px, 1.0)) - 2.0, 0.0, 4.0);
		vec2 paso = paso_px * SCREEN_PIXEL_SIZE;
		float total_weight = 0.0;
		for (float x = -1.0; x <= 1.0; x += 1.0) {
			for (float y = -1.0; y <= 1.0; y += 1.0) {
				float weight = exp(-(x*x + y*y) / 1.2);
				color += textureLod(screen_texture, uv + vec2(x, y) * paso, lod) * weight;
				total_weight += weight;
			}
		}
		color /= total_weight;
	} else {
		color = textureLod(screen_texture, uv, 0.0);
	}

	// Tinte dorado suave
	vec3 golden = vec3(0.88, 0.72, 0.38);
	color.rgb = mix(color.rgb, color.rgb * golden, tint_amount * 0.5);
	
	// Viñeta suave
	vec2 center_offset = uv - vec2(0.5);
	float dist = length(center_offset);
	float vignette = smoothstep(0.25, 0.85, dist);
	color.rgb = mix(color.rgb, color.rgb * (1.0 - vignette * 0.9), vignette_intensity);
	
	// Parpadeo - párpados con arco: bajan más por el centro que por los extremos.
	// El -0.08 deja el ojo del todo abierto con blink = 0; sin el, el borde
	// difuminado de 0.08 oscurecia ya arriba y abajo desde el frame del golpe.
	// Con blink = 1 cierra exactamente igual que antes.
	float arc = 1.0 - pow(abs(uv.x - 0.5) * 2.0, 2.0);
	float lid = blink * (0.58 + 0.08 * arc) - 0.08;
	float top_lid = smoothstep(lid, lid + 0.08, uv.y);
	float bottom_lid = smoothstep(lid, lid + 0.08, 1.0 - uv.y);
	float eye_open = top_lid * bottom_lid;
	color.rgb *= eye_open;
	
	// Fundido a negro suave
	color.rgb = mix(color.rgb, vec3(0.0), blackout);
	
	COLOR = vec4(color.rgb, 1.0);
}
