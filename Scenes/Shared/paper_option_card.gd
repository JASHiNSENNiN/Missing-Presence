extends Control


@onready var background: TextureRect = $CardBackground
@onready var content_margin: MarginContainer = $ContentMargin
@onready var label: Label = $ContentMargin/Label

signal pressed

const HOVER_SCALE := 1.08
const HOVER_TILT_BONUS := -3.0
const HOVER_DURATION := 0.15
const SPAWN_SLIDE_DISTANCE := 30.0
const SPAWN_DURATION := 0.4

const DIM_ALPHA := 0.55
const DIM_DURATION := 0.15

const CONFIRM_PUNCH_SCALE := 1.22
const CONFIRM_PUNCH_DURATION := 0.14

const DISMISS_SLIDE_DISTANCE := 40.0
const DISMISS_DURATION := 0.18

var _base_rotation: float = 0.0
var _hover_tween: Tween
var _dim_tween: Tween


func _ready() -> void:
	pivot_offset = size * 0.5
	_base_rotation = rotation_degrees
	content_margin.resized.connect(_sync_background_size)
	_sync_background_size()

	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_hovered)
	mouse_exited.connect(_on_unhovered)
	gui_input.connect(_on_gui_input)


func _sync_background_size() -> void:
	background.size = content_margin.size
	pivot_offset = background.size * 0.5


func set_text(value: String) -> void:
	label.text = value


func spawn(delay: float) -> void:
	visible = true
	var rest_position := position
	modulate.a = 0.0
	position = rest_position + Vector2(0.0, -SPAWN_SLIDE_DISTANCE)

	var tween := create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, SPAWN_DURATION)
	tween.tween_property(self, "position", rest_position, SPAWN_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_hovered() -> void:
	_tween_to(HOVER_SCALE, _base_rotation + HOVER_TILT_BONUS)


func _on_unhovered() -> void:
	_tween_to(1.0, _base_rotation)


func _tween_to(target_scale: float, target_rotation: float) -> void:
	if _hover_tween:
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE * target_scale, HOVER_DURATION)
	_hover_tween.tween_property(self, "rotation_degrees", target_rotation, HOVER_DURATION)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()


func set_dimmed(dimmed: bool) -> void:
	if _dim_tween:
		_dim_tween.kill()
	_dim_tween = create_tween()
	_dim_tween.tween_property(self, "modulate:a", DIM_ALPHA if dimmed else 1.0, DIM_DURATION)


func play_confirm_punch() -> Tween:
	if _hover_tween:
		_hover_tween.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * CONFIRM_PUNCH_SCALE, CONFIRM_PUNCH_DURATION)
	return tween


func play_dismiss() -> Tween:
	if _hover_tween:
		_hover_tween.kill()
	if _dim_tween:
		_dim_tween.kill()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, DISMISS_DURATION)
	tween.tween_property(self, "position:y", position.y + DISMISS_SLIDE_DISTANCE, DISMISS_DURATION)
	return tween
