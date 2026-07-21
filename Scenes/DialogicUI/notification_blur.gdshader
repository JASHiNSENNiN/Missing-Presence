shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float blur_radius : hint_range(0.0, 8.0) = 3.0;
uniform float desaturation : hint_range(0.0, 1.0) = 0.4;
uniform vec4 dim_color : source_color = vec4(0.05, 0.04, 0.09, 1.0);
uniform float dim_strength : hint_range(0.0, 1.0) = 0.42;

vec4 sample_blur(vec2 uv, vec2 step_size) {
	vec4 col = texture(screen_tex, uv) * 0.2270270270;
	col += texture(screen_tex, uv + vec2(step_size.x, 0.0)) * 0.1945945946;
	col += texture(screen_tex, uv - vec2(step_size.x, 0.0)) * 0.1945945946;
	col += texture(screen_tex, uv + vec2(0.0, step_size.y)) * 0.1216216216;
	col += texture(screen_tex, uv - vec2(0.0, step_size.y)) * 0.1216216216;
	col += texture(screen_tex, uv + step_size) * 0.0702702703;
	col += texture(screen_tex, uv - step_size) * 0.0702702703;
	return col;
}

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * blur_radius * amount;
	vec4 blurred = sample_blur(SCREEN_UV, step_size);
	float luma = dot(blurred.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desat = mix(blurred.rgb, vec3(luma), desaturation * amount);
	vec3 dimmed = mix(desat, dim_color.rgb, dim_strength * amount);
	COLOR = vec4(dimmed, 1.0);
}
