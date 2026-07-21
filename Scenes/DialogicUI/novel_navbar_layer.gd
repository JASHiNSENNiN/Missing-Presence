@tool
extends DialogicLayoutLayer


const MAIN_MENU_SCENE := "res://Scenes/Main Menu/MainMenu.tscn"
const LOAD_SCENE := "res://Scenes/Load/Load.tscn"

const INTRO_DROP_DISTANCE := 46.0
const INTRO_DURATION := 0.5
const INTRO_ROTATION_OVERSHOOT := 0.05
const INTRO_DELAY := 0.15
const STAGGER_STEP := 0.05

const HOVER_SCALE := 1.05
const PRESS_SCALE := 0.95
const HOVER_DURATION := 0.2
const PRESS_DURATION := 0.12
const COLOR_NORMAL := Color(0.631, 0.443, 0.29, 1.0)
const COLOR_HOVER := Color(0.812, 0.392, 0.349, 1.0)

@onready var exit_confirm_dialog: ConfirmPopup = $ExitConfirmDialog
@onready var _ui_sound: Node = get_node_or_null("/root/UISound")

var _scene_transition: Node:
	get: return get_node("/root/SceneTransition")


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	%SaveButton.pressed.connect(_on_save_pressed)
	%LoadButton.pressed.connect(_on_load_pressed)
	exit_confirm_dialog.confirmed.connect(_on_exit_confirmed)
	exit_confirm_dialog.cancelled.connect(_on_exit_cancelled)
	_play_intro()
	_connect_button_feedback()


func _play_intro() -> void:
	var panel: Control = %NavPanel
	panel.pivot_offset = panel.size * 0.5
	panel.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, ^"position:y", panel.position.y, INTRO_DURATION)\
		.from(panel.position.y - INTRO_DROP_DISTANCE).set_trans(Tween.TRANS_BOUNCE).set_delay(INTRO_DELAY)
	tween.tween_property(panel, ^"modulate:a", 1.0, INTRO_DURATION * 0.3).set_delay(INTRO_DELAY)
	tween.tween_property(panel, ^"rotation", 0.0, INTRO_DURATION)\
		.from(-INTRO_ROTATION_OVERSHOOT).set_trans(Tween.TRANS_ELASTIC).set_delay(INTRO_DELAY)

	_stagger_children()


func _stagger_children() -> void:
	var items: Array[Control] = [%MainMenuButton, $NavPanel/Nav/Sep1, %SaveButton, $NavPanel/Nav/Sep2, %LoadButton]
	var step_tween := create_tween().set_parallel(true)
	for i in items.size():
		var item := items[i]
		item.pivot_offset = item.size * 0.5
		item.modulate.a = 0.0
		var delay: float = INTRO_DELAY + INTRO_DURATION * 0.4 + i * STAGGER_STEP
		step_tween.tween_property(item, ^"modulate:a", 1.0, 0.18).set_delay(delay)
		step_tween.tween_property(item, ^"scale", Vector2.ONE, 0.28)\
			.from(Vector2(0.4, 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)


func _connect_button_feedback() -> void:
	for button: Button in [%MainMenuButton, %SaveButton, %LoadButton]:
		button.pivot_offset = button.size * 0.5
		button.add_theme_color_override(&"font_hover_color", COLOR_NORMAL)
		button.mouse_entered.connect(_on_hover.bind(button, true))
		button.mouse_exited.connect(_on_hover.bind(button, false))
		button.button_down.connect(_on_pressed_down.bind(button))
		button.button_up.connect(_on_pressed_up.bind(button))


func _on_hover(button: Button, is_hovering: bool) -> void:
	if button.button_pressed:
		return
	if is_hovering and _ui_sound:
		_ui_sound.hover()
	button.pivot_offset = button.size * 0.5
	var target_scale := Vector2.ONE * HOVER_SCALE if is_hovering else Vector2.ONE
	var target_color := COLOR_HOVER if is_hovering else COLOR_NORMAL

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, ^"scale", target_scale, HOVER_DURATION)
	tween.tween_property(button, ^"theme_override_colors/font_color", target_color, HOVER_DURATION)
	tween.tween_property(button, ^"theme_override_colors/font_hover_color", target_color, HOVER_DURATION)


func _on_pressed_down(button: Button) -> void:
	if _ui_sound:
		_ui_sound.select()
	button.pivot_offset = button.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, ^"scale", Vector2.ONE * PRESS_SCALE, PRESS_DURATION)


func _on_pressed_up(button: Button) -> void:
	button.pivot_offset = button.size * 0.5
	var target := Vector2.ONE * HOVER_SCALE if button.get_global_rect().has_point(button.get_global_mouse_position()) else Vector2.ONE
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, ^"scale", target, HOVER_DURATION)


func _game_flow() -> Node:
	return get_node("/root/GameFlow")


func _on_save_pressed() -> void:
	Dialogic.Save.take_thumbnail()
	_open_save_load_screen("save")


func _on_load_pressed() -> void:
	_open_save_load_screen("load")


func _open_save_load_screen(mode: String) -> void:
	var game_flow := _game_flow()
	game_flow.set("return_to_game", true)
	game_flow.set("save_load_mode", mode)
	if Dialogic.Styles.has_active_layout_node():
		Dialogic.Styles.get_layout_node().hide()
	get_tree().paused = true
	_scene_transition.change_scene(LOAD_SCENE)


func _on_main_menu_pressed() -> void:
	if _game_flow().get("dirty_since_last_save"):
		get_tree().paused = true
		exit_confirm_dialog.open("Return to Main Menu? Unsaved progress will be lost.", "Return to Main Menu", "Keep Playing")
	else:
		_exit_to_main_menu()


func _on_exit_confirmed() -> void:
	_exit_to_main_menu()


func _on_exit_cancelled() -> void:
	get_tree().paused = false


func _exit_to_main_menu() -> void:
	get_tree().paused = false
	await _game_flow().finish_pending_text_reveal()
	await Dialogic.end_timeline(true)
	Dialogic.clear()
	await _scene_transition.change_scene(MAIN_MENU_SCENE)
	get_tree().paused = false
