shader_type canvas_item;

uniform float vignette_strength : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_softness : hint_range(0.01, 1.0) = 0.55;
uniform vec4 vignette_color : source_color = vec4(0.16, 0.10, 0.05, 1.0);
uniform float grain_strength : hint_range(0.0, 0.25) = 0.035;
uniform float grain_speed = 9.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 1.41421356;
	float vignette = smoothstep(1.0 - vignette_softness, 1.0, dist) * vignette_strength;

	float grain = (rand(UV + fract(TIME * grain_speed)) - 0.5) * grain_strength;

	float alpha = clamp(vignette + abs(grain), 0.0, 1.0);
	COLOR = vec4(vignette_color.rgb, alpha);
}
