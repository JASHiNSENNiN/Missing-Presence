shader_type canvas_item;

// Wind sway for grass silhouette layers. The bottom of the crop (UV.y = 1)
// stays anchored while the top/tips (UV.y = 0) drift horizontally, so the
// blades read as swaying in place instead of the whole sprite shifting.

uniform float sway_amplitude : hint_range(0.0, 0.05) = 0.012;
uniform float sway_speed : hint_range(0.0, 5.0) = 0.6;
uniform float sway_frequency : hint_range(0.0, 20.0) = 5.0;
uniform float height_curve : hint_range(0.5, 4.0) = 1.6;

void fragment() {
	float height_factor = pow(clamp(1.0 - UV.y, 0.0, 1.0), height_curve);
	float sway = sin(UV.x * sway_frequency + TIME * sway_speed) * sway_amplitude * height_factor;
	// secondary faster/finer wobble so it doesn't read as a single rigid wave
	sway += sin(UV.x * sway_frequency * 2.7 + TIME * sway_speed * 1.8) * sway_amplitude * 0.35 * height_factor;
	vec2 uv = UV;
	uv.x += sway;
	COLOR = texture(TEXTURE, uv);
}
