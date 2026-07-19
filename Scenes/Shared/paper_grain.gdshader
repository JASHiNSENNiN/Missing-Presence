shader_type canvas_item;

uniform float grain_strength : hint_range(0.0, 0.3) = 0.05;
uniform float grain_scale : hint_range(1.0, 500.0) = 220.0;
uniform float flicker_speed : hint_range(0.0, 5.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 grain_uv = FRAGCOORD.xy / grain_scale;
	float flicker = floor(TIME * flicker_speed);
	float grain = hash(grain_uv + flicker) - 0.5;
	COLOR = vec4(base.rgb + grain * grain_strength, base.a);
}
