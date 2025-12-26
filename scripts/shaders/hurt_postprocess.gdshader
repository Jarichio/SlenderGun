shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE 
	: hint_screen_texture, repeat_disable, filter_linear_mipmap; // Linear for damage blur

uniform float injury_factor = 0.0;
uniform float pulse_speed = 0.9;
uniform vec4 vignette_color : source_color = vec4(1.0, 0.0, 0.0, 0.6);

uniform int color_quant = 10;
uniform float color_quant_threshold = 0.5;

uniform float blur_threshold = 0.4;
uniform float blur_factor = 1.5;

uniform float r_scale = 8.0;
uniform float g_scale = 4.0;
uniform float b_scale = 0.0;

void fragment() {
	float pulse = cos((TIME * PI*2.0) / pulse_speed);
	
	float chroma_pulse = pulse * 0.5 + 0.5;
	chroma_pulse = injury_factor * max(0.0, (chroma_pulse - 0.2) / (1.0 - 0.2));
	
	float blur_pulse = pulse * 0.1 + (1.0 - 0.1);
	float lod = max(0.0, injury_factor * blur_pulse - blur_threshold) / (1.0 - blur_threshold) * blur_factor;
	
	vec2 centered_uv = (SCREEN_UV - vec2(0.5)) * 2.0;
	// We unfortunately need to do 3x mipmap texture samples per mixel :/
	float chroma_r = textureLod(SCREEN_TEXTURE, SCREEN_UV - centered_uv * r_scale * chroma_pulse * SCREEN_PIXEL_SIZE, lod).r;
	float chroma_g = textureLod(SCREEN_TEXTURE, SCREEN_UV - centered_uv * g_scale * chroma_pulse * SCREEN_PIXEL_SIZE, lod).g;
	float chroma_b = textureLod(SCREEN_TEXTURE, SCREEN_UV - centered_uv * b_scale * chroma_pulse * SCREEN_PIXEL_SIZE, lod).b;
	vec3 out_col = vec3(chroma_r, chroma_g, chroma_b);

	// Since this is consistent between fragments, I don't think 
	// the if statement will matter for performance.
	// It will alweays take the same path for every fragment in each frame
	if (injury_factor >= color_quant_threshold) {
		float color_count = mix(256.0, float(color_quant), (injury_factor - color_quant_threshold) / (1.0 - color_quant_threshold));
		out_col = floor(out_col * color_count)/color_count;
	}
	
	float vignette_pulse = injury_factor * (pulse * 0.1 + 0.9);
	float center_dist = distance(UV, vec2(0.5));
	float vignette = smoothstep(0.0, 1.0, center_dist);
	out_col = mix(out_col, vignette_color.rgb, vignette * vignette_color.a * vignette_pulse);
	COLOR = vec4(out_col, 1.0);
}
