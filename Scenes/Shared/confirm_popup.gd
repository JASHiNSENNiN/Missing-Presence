class_name ConfirmPopup
extends CanvasLayer


signal confirmed
signal cancelled

@onready var dim_background: ColorRect = $DimBackground
@onready var paper_panel: TextureRect = $PaperPanel
@onready var back_tab: ColorRect = $BackTab
@onready var message_label: Label = $PaperPanel/Margin/VBox/MessageLabel
@onready var choice_highlight: TextureRect = $PaperPanel/Margin/VBox/ChoiceArea/ChoiceHighlight
@onready var confirm_label: Label = $PaperPanel/Margin/VBox/ChoiceArea/ChoiceVBox/ConfirmLabel
@onready var cancel_label: Label = $PaperPanel/Margin/VBox/ChoiceArea/ChoiceVBox/CancelLabel
@onready var _ui_sound: Node = get_node_or_null("/root/UISound")

const POP_IN_DURATION := 0.22
const DIM_FADE_DURATION := 0.18
const BACK_TAB_HOVER_TILT_DEGREES := 6.0
const TILT_DURATION := 0.2

const BACK_TAB_BASE_TILT_DEGREES := -6.8754

const HIGHLIGHT_SLIDE_DURATION := 0.2
const LABEL_HOVER_TILT_DEGREES := -6.0
const HIGHLIGHT_PADDING_X := 22.0

var _tilt_tweens: Dictionary = {}
var _highlight_tween: Tween


func _ready() -> void:
	hide()
	confirm_label.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_label.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cancel_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	confirm_label.gui_input.connect(_on_confirm_gui_input)
	cancel_label.gui_input.connect(_on_cancel_gui_input)
	confirm_label.mouse_entered.connect(_on_choice_hovered.bind(confirm_label))
	cancel_label.mouse_entered.connect(_on_choice_hovered.bind(cancel_label))
	confirm_label.mouse_exited.connect(_on_choice_unhovered.bind(confirm_label))
	cancel_label.mouse_exited.connect(_on_choice_unhovered.bind(cancel_label))

	back_tab.rotation_degrees = BACK_TAB_BASE_TILT_DEGREES
	back_tab.mouse_entered.connect(_on_back_tab_hovered)
	back_tab.mouse_exited.connect(_on_back_tab_unhovered)
	back_tab.gui_input.connect(_on_back_tab_gui_input)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func open(message: String, confirm_text := "Yes", cancel_text := "Cancel") -> void:
	message_label.text = message
	confirm_label.text = confirm_text
	cancel_label.text = cancel_text

	show()

	dim_background.modulate.a = 0.0
	paper_panel.modulate.a = 0.0
	paper_panel.pivot_offset = paper_panel.size / 2.0
	paper_panel.scale = Vector2(0.9, 0.9)
	back_tab.modulate.a = 0.0
	back_tab.pivot_offset = back_tab.size / 2.0
	choice_highlight.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(dim_background, "modulate:a", 1.0, DIM_FADE_DURATION)
	tween.tween_property(paper_panel, "modulate:a", 1.0, POP_IN_DURATION)
	tween.tween_property(paper_panel, "scale", Vector2.ONE, POP_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(back_tab, "modulate:a", 1.0, POP_IN_DURATION).set_delay(0.08)

	await get_tree().create_timer(POP_IN_DURATION * 0.6).timeout
	await _snap_highlight_to(confirm_label)
	choice_highlight.modulate.a = 1.0


func _on_choice_hovered(label: Label) -> void:
	if _ui_sound:
		_ui_sound.hover()
	_slide_highlight_to(label)
	_tilt_control(label, LABEL_HOVER_TILT_DEGREES)


func _on_choice_unhovered(label: Label) -> void:
	_tilt_control(label, 0.0)


func _slide_highlight_to(label: Label) -> void:
	var target_center_y := label.global_position.y + label.size.y / 2.0
	var highlight_center_y := choice_highlight.global_position.y + choice_highlight.size.y / 2.0
	var delta := target_center_y - highlight_center_y
	var half_width := label.size.x / 2.0 + HIGHLIGHT_PADDING_X

	if _highlight_tween:
		_highlight_tween.kill()

	_highlight_tween = create_tween()
	_highlight_tween.set_parallel(true)
	_highlight_tween.tween_property(choice_highlight, "offset_top", choice_highlight.offset_top + delta, HIGHLIGHT_SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(choice_highlight, "offset_bottom", choice_highlight.offset_bottom + delta, HIGHLIGHT_SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(choice_highlight, "offset_left", -half_width, HIGHLIGHT_SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(choice_highlight, "offset_right", half_width, HIGHLIGHT_SLIDE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _snap_highlight_to(label: Label) -> void:
	await get_tree().process_frame
	var target_center_y := label.global_position.y + label.size.y / 2.0
	var highlight_center_y := choice_highlight.global_position.y + choice_highlight.size.y / 2.0
	var delta := target_center_y - highlight_center_y
	choice_highlight.offset_top += delta
	choice_highlight.offset_bottom += delta
	var half_width := label.size.x / 2.0 + HIGHLIGHT_PADDING_X
	choice_highlight.offset_left = -half_width
	choice_highlight.offset_right = half_width


func _tilt_control(control: Control, degrees: float) -> void:
	if _tilt_tweens.has(control):
		_tilt_tweens[control].kill()

	var tween := create_tween()
	tween.tween_property(control, "rotation_degrees", degrees, TILT_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tilt_tweens[control] = tween


func _on_back_tab_hovered() -> void:
	if _ui_sound:
		_ui_sound.hover()
	_tilt_control(back_tab, BACK_TAB_BASE_TILT_DEGREES + BACK_TAB_HOVER_TILT_DEGREES)


func _on_back_tab_unhovered() -> void:
	_tilt_control(back_tab, BACK_TAB_BASE_TILT_DEGREES)


func _on_confirm_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_confirm_pressed()


func _on_cancel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_pressed()


func _on_back_tab_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cancel_pressed()


func _on_confirm_pressed() -> void:
	if _ui_sound:
		_ui_sound.confirm()
	hide()
	confirmed.emit()


func _on_cancel_pressed() -> void:
	if _ui_sound:
		_ui_sound.back()
	hide()
	cancelled.emit()
