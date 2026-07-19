extends Control

const DASH_COLOR := Color(0.62, 0.55, 0.47, 0.4)
const DASH_LENGTH := 6.0
const LINE_WIDTH := 1.0


func _draw() -> void:
	draw_dashed_line(Vector2(1, 0), Vector2(1, size.y), DASH_COLOR, LINE_WIDTH, DASH_LENGTH)
