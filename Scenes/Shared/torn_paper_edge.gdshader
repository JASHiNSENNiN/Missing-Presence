shader_type canvas_item;

// Solid paper-colored rect with torn/deckled edges, for the ConfirmPopup
// panel and the blinds-wipe transition strips. Same no-TEXTURE-sampling
// technique as paper_panel.gdshader (see its header comment / developer
// documentation gotcha notes) so it works correctly on plain
// texture-less nodes.
//
// Each torn edge is built from a few layered sine terms at incommensurate
// frequencies plus per-segment random jitter along that edge's UV axis, so
// it reads as ragged hand-torn paper fiber rather than a clean rectangle or
// a smooth wave -- the edge itself is where the node's alpha falls off, not
// a drawn line.
//
// tear_edges is a bitmask: 1=bottom, 2=top, 4=right, 8=left. Combine bits to
// tear multiple sides at once (15 = all four, for a torn paper scrap look);
// 0 = no tear, clean rectangle.

uniform vec4 paper_color : source_color = vec4(0.667, 0.424, 0.263, 1.0);
uniform float grain_strength : hint_range(0.0, 0.3) = 0.05;
uniform float grain_scale : hint_range(1.0, 500.0) = 180.0;

uniform int tear_edges = 1;
uniform float tear_amplitude : hint_range(0.0, 0.15) = 0.035;
uniform float tear_frequency : hint_range(1.0, 60.0) = 22.0;
uniform float tear_softness : hint_range(0.0, 0.05) = 0.012;
// Random seed offset so multiple torn panels don't share an identical tear pattern.
uniform float tear_seed = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

// Cheap layered jag: a handful of sine terms at incommensurate frequencies
// plus per-segment random jitter reads as torn paper fiber, not a smooth wave.
float tear_offset(float t) {
	float o = 0.0;
	o += sin(t * tear_frequency + tear_seed) * 0.5;
	o += sin(t * tear_frequency * 2.37 + 1.7 + tear_seed) * 0.28;
	o += sin(t * tear_frequency * 5.11 + 4.2 + tear_seed) * 0.14;
	float seg = floor(t * tear_frequency * 0.5);
	o += (hash(seg + tear_seed * 17.0) - 0.5) * 0.6;
	return o * tear_amplitude;
}

// Signed distance (positive = inside) from a single torn edge boundary.
float edge_distance(float across, float along_axis, bool flip) {
	float d = flip ? (1.0 - tear_amplitude * 2.0) - across : across - tear_amplitude * 2.0;
	return d + tear_offset(along_axis) * (flip ? 1.0 : -1.0);
}

void fragment() {
	float d = 1.0; // start "fully inside"; each active edge tightens this

	if ((tear_edges & 1) != 0) { // bottom
		d = min(d, edge_distance(UV.y, UV.x, true));
	}
	if ((tear_edges & 2) != 0) { // top
		d = min(d, edge_distance(UV.y, UV.x, false));
	}
	if ((tear_edges & 4) != 0) { // right
		d = min(d, edge_distance(UV.x, UV.y, true));
	}
	if ((tear_edges & 8) != 0) { // left
		d = min(d, edge_distance(UV.x, UV.y, false));
	}

	float alpha = tear_edges == 0 ? 1.0 : smoothstep(-tear_softness, tear_softness, d);

	vec2 grain_uv = FRAGCOORD.xy / grain_scale;
	float grain = hash(dot(grain_uv, vec2(12.9898, 78.233)));
	grain = (grain - 0.5) * grain_strength;

	COLOR = vec4(paper_color.rgb + grain, paper_color.a * alpha);
}
