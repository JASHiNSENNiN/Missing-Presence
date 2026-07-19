shader_type canvas_item;

// Very slow, infinite horizontal drift for the sky layer's painted clouds.
// Oscillates gently back and forth within a small UV range instead of
// scrolling past the texture edge -- the source art isn't seamlessly
// tileable, so any wrap (even mirrored) shows up as a visible flip in the
// cloud shapes. This never touches the edge, so there is no seam, ever.

uniform float scroll_amplitude : hint_range(0.0, 0.1) = 0.025;
uniform float scroll_speed : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * scroll_speed) * scroll_amplitude;
	COLOR = texture(TEXTURE, uv);
}
