shader_type canvas_item;

// Draws a solid kraft-paper frame covering the whole rect, with a rounded-rect
// "window" punched out (fully transparent) so whatever renders behind this
// node - the Dialogic background layer - shows through only inside the window.
// Grain noise is baked in so we don't need a second shader pass like
// Scenes/Shared/paper_grain.gdshader (that one samples TEXTURE, which a bare
// ColorRect doesn't have).
//
// All geometry is expressed as ratios of the actual screen size (via
// SCREEN_PIXEL_SIZE), not hardcoded pixels - otherwise this breaks in
// fullscreen/any resolution other than the one it was tuned at, since
// window/stretch/mode="canvas_items" grows the real render surface but
// FRAGCOORD math doesn't auto-rescale on its own.

uniform vec4 frame_color : source_color = vec4(0.831, 0.643, 0.376, 1.0);
uniform vec2 window_position_ratio = vec2(0.06163, 0.09414);
uniform vec2 window_size_ratio = vec2(0.87674, 0.85031);
uniform float corner_radius_ratio : hint_range(0.0, 0.3) = 0.04012;
uniform float edge_softness_ratio : hint_range(0.0, 0.02) = 0.00231;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.04;
uniform float grain_scale : hint_range(1.0, 500.0) = 180.0;
uniform float flicker_speed : hint_range(0.0, 5.0) = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

	vec2 window_position = window_position_ratio * screen_size;
	vec2 window_size = window_size_ratio * screen_size;
	float corner_radius = corner_radius_ratio * screen_size.y;
	float edge_softness = edge_softness_ratio * screen_size.y;

	vec2 local = FRAGCOORD.xy - window_position - window_size * 0.5;
	float d = rounded_box_sdf(local, window_size * 0.5, corner_radius);
	float alpha = smoothstep(0.0, edge_softness + 0.001, d);

	vec2 grain_uv = FRAGCOORD.xy / grain_scale;
	float flicker = floor(TIME * flicker_speed);
	float grain = hash(grain_uv + flicker) - 0.5;

	COLOR = vec4(frame_color.rgb + grain * grain_strength, frame_color.a * alpha);
}
