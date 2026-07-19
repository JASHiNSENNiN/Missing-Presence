shader_type canvas_item;

// Solid rounded-rect paper panel with baked-in grain, for use on any Control
// (no StyleBox, no texture asset needed). Same technique as
// Scenes/DialogicUI/kraft_frame_mask.gdshader: color + grain is computed
// directly from a uniform, never sampled from TEXTURE, so it works
// correctly on texture-less nodes (Scenes/Shared/paper_grain.gdshader
// samples TEXTURE and only works on nodes with a real texture asset --
// see developer documentation/gotcha notes for the bug that taught us this).
//
// node_size must be kept in sync with the node's actual pixel size from
// script (e.g. on _ready() and on the node's `resized` signal) -- UV alone
// doesn't tell us the pixel dimensions, and TEXTURE_PIXEL_SIZE depends on
// a bound texture existing, which this node deliberately doesn't have.

uniform vec4 panel_color : source_color = vec4(0.667, 0.424, 0.263, 1.0);
uniform vec2 node_size = vec2(440.0, 190.0);
uniform float corner_radius : hint_range(0.0, 100.0) = 22.0;
uniform float edge_softness : hint_range(0.0, 4.0) = 1.5;
uniform float grain_strength : hint_range(0.0, 0.3) = 0.05;
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
	vec2 local = UV * node_size - node_size * 0.5;
	float d = rounded_box_sdf(local, node_size * 0.5, corner_radius);
	float alpha = smoothstep(0.0, edge_softness + 0.001, -d);

	vec2 grain_uv = FRAGCOORD.xy / grain_scale;
	float flicker = floor(TIME * flicker_speed);
	float grain = hash(grain_uv + flicker) - 0.5;

	COLOR = vec4(panel_color.rgb + grain * grain_strength, panel_color.a * alpha);
}
