shader_type canvas_item;

uniform vec2 ray_origin = vec2(0.72, -0.05);
uniform float ray_angle : hint_range(-1.5, 1.5) = 0.55;
uniform float ray_count : hint_range(1.0, 40.0) = 11.0;
uniform float ray_softness : hint_range(0.0, 1.0) = 0.55;
uniform float ray_strength : hint_range(0.0, 1.0) = 0.22;
uniform float ray_length : hint_range(0.1, 2.0) = 1.1;
uniform float drift_speed = 0.06;
uniform vec4 ray_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);

void fragment() {
	vec2 delta = UV - ray_origin;
	float rotated = delta.x * cos(ray_angle) - delta.y * sin(ray_angle);
	float along = delta.x * sin(ray_angle) + delta.y * cos(ray_angle);

	float bands = sin(rotated * ray_count + TIME * drift_speed);
	bands = mix(bands, sin(rotated * ray_count * 1.7 - TIME * drift_speed * 0.6), 0.4);
	bands = smoothstep(-ray_softness, 1.0, bands);

	float falloff = clamp(1.0 - along / ray_length, 0.0, 1.0);
	falloff *= falloff;

	float alpha = bands * falloff * ray_strength;
	COLOR = vec4(ray_color.rgb, clamp(alpha, 0.0, 1.0));
}
