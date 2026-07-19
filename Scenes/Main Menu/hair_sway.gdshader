shader_type canvas_item;

// Gentle sway restricted to the loose trailing hair on the left side of the
// character crop. Her face/shoulder sit on the right side of the image and
// must stay rigid, so the effect is masked out horizontally (fades to zero
// before reaching the face) and eases in vertically (least near the scalp,
// most where the strands trail off).

uniform float sway_amplitude : hint_range(0.0, 0.03) = 0.01;
uniform float sway_speed : hint_range(0.0, 5.0) = 0.5;
uniform float sway_frequency : hint_range(0.0, 20.0) = 4.0;
uniform float face_mask_start : hint_range(0.0, 1.0) = 0.45;
uniform float face_mask_end : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	float horizontal_mask = 1.0 - smoothstep(face_mask_start, face_mask_end, UV.x);
	float vertical_mask = smoothstep(0.12, 0.85, UV.y);
	float mask = horizontal_mask * vertical_mask;

	float sway = sin(UV.y * sway_frequency + TIME * sway_speed) * sway_amplitude * mask;
	vec2 uv = UV;
	uv.x += sway;
	COLOR = texture(TEXTURE, uv);
}
