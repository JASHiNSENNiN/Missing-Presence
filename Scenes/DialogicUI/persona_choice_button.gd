extends DialogicNode_ChoiceButton


const STAGGER_STEP := 0.08
const POP_DURATION := 0.26

const HOVER_SCALE := 1.05
const PRESS_SCALE := 0.95
const FEEDBACK_DURATION := 0.14

var _connected_feedback := false


func _load_info(choice_info: Dictionary) -> void:
	super(choice_info)
	if not visible:
		return

	if not _connected_feedback:
		_connected_feedback = true
		mouse_entered.connect(_on_hover.bind(true))
		mouse_exited.connect(_on_hover.bind(false))
		button_down.connect(_on_pressed_down)
		button_up.connect(_on_pressed_up)

	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.5, 0.5)

	var delay: float = (choice_info.get("button_index", 1) - 1) * STAGGER_STEP
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, ^"modulate:a", 1.0, POP_DURATION * 0.6).set_delay(delay)
	tween.tween_property(self, ^"scale", Vector2.ONE, POP_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)


func _on_hover(is_hovering: bool) -> void:
	if button_pressed or Input.is_action_pressed("dialogic_default_action"):
		return
	if is_hovering:
		var ui_sound = get_node_or_null("/root/UISound")
		if ui_sound:
			ui_sound.hover()
	pivot_offset = size * 0.5
	var target := Vector2.ONE * HOVER_SCALE if is_hovering else Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"scale", target, FEEDBACK_DURATION)


func _on_pressed_down() -> void:
	var ui_sound = get_node_or_null("/root/UISound")
	if ui_sound:
		ui_sound.select()
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"scale", Vector2.ONE * PRESS_SCALE, FEEDBACK_DURATION * 0.6)


func _on_pressed_up() -> void:
	pivot_offset = size * 0.5
	var target := Vector2.ONE * HOVER_SCALE if get_global_rect().has_point(get_global_mouse_position()) else Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, ^"scale", target, FEEDBACK_DURATION)
