shader_type canvas_item;

// Persona-style panel: a rounded rect with the top-right corner diagonally
// chamfered (the signature "not quite a rectangle" cut) plus a bold
// outline stroke. Rendered as a background ColorRect behind a plain
// (StyleBoxEmpty) panel, since Godot's StyleBox system has no shader
// variant to hook this into directly.

uniform vec4 fill_color : source_color = vec4(1.0, 0.957, 0.812, 1.0);
uniform vec4 border_color : source_color = vec4(0.322, 0.196, 0.098, 1.0);
uniform float border_width : hint_range(0.0, 20.0) = 4.0;
uniform float corner_radius : hint_range(0.0, 60.0) = 22.0;
uniform float chamfer_size : hint_range(0.0, 120.0) = 34.0;
uniform vec2 rect_size = vec2(560.0, 155.0);

float rounded_box_sdf(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 half_size = rect_size * 0.5;
	vec2 p = UV * rect_size - half_size;

	float d = rounded_box_sdf(p, half_size, corner_radius);

	// Chamfer plane: clips the top-right corner diagonally.
	float chamfer_plane = (p.x - half_size.x) - (p.y + half_size.y) + chamfer_size;
	d = max(d, chamfer_plane);

	float alpha = 1.0 - smoothstep(0.0, 1.5, d);
	float is_fill = 1.0 - smoothstep(-border_width - 1.0, -border_width, d);
	vec3 col = mix(border_color.rgb, fill_color.rgb, is_fill);

	COLOR = vec4(col, alpha);
}
