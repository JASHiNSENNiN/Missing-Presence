extends Control

const ICON_COLOR := Color(0.68, 0.6, 0.5, 0.55)
const ICON_LINE_WIDTH := 2.0

const IDLE_PULSE_MIN_ALPHA := 0.4
const IDLE_PULSE_MAX_ALPHA := 0.85
const IDLE_PULSE_SPEED := 1.1

var _idle_time := randf() * TAU


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	_idle_time += delta * IDLE_PULSE_SPEED
	var pulse := (sin(_idle_time) + 1.0) / 2.0
	modulate.a = lerpf(IDLE_PULSE_MIN_ALPHA, IDLE_PULSE_MAX_ALPHA, pulse)
	queue_redraw()


func _draw() -> void:
	var icon_size := minf(size.x, size.y) * 0.32
	var center := size / 2.0

	var frame_size := Vector2(icon_size * 2.0, icon_size * 1.44)
	var frame_rect := Rect2(center - frame_size / 2.0, frame_size)
	draw_rect(frame_rect, ICON_COLOR, false, ICON_LINE_WIDTH)

	var sun_center := frame_rect.position + Vector2(frame_rect.size.x * 0.26, frame_rect.size.y * 0.3)
	draw_arc(sun_center, icon_size * 0.16, 0.0, TAU, 16, ICON_COLOR, ICON_LINE_WIDTH)

	var mountain_base_y := frame_rect.position.y + frame_rect.size.y * 0.86
	var points := PackedVector2Array([
		Vector2(frame_rect.position.x + frame_rect.size.x * 0.06, mountain_base_y),
		Vector2(frame_rect.position.x + frame_rect.size.x * 0.38, frame_rect.position.y + frame_rect.size.y * 0.4),
		Vector2(frame_rect.position.x + frame_rect.size.x * 0.6, frame_rect.position.y + frame_rect.size.y * 0.64),
		Vector2(frame_rect.position.x + frame_rect.size.x * 0.8, frame_rect.position.y + frame_rect.size.y * 0.46),
		Vector2(frame_rect.position.x + frame_rect.size.x * 0.96, mountain_base_y),
	])
	draw_polyline(points, ICON_COLOR, ICON_LINE_WIDTH, true)
