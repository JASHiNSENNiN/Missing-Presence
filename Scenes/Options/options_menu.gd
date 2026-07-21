extends Node2D

@onready var settings: Node = get_node("/root/Settings")
@onready var game_flow: Node = get_node("/root/GameFlow")
@onready var _ui_sound: Node = get_node_or_null("/root/UISound")

@onready var book_root: Control = $CanvasLayer/MenuLayout/BookRoot
@onready var content_root: Control = $CanvasLayer/MenuLayout/BookRoot/ContentRoot

@onready var page_stacks: Array[Panel] = [
	$CanvasLayer/MenuLayout/BookRoot/PageStack1,
	$CanvasLayer/MenuLayout/BookRoot/PageStack2,
	$CanvasLayer/MenuLayout/BookRoot/PageStack3,
	$CanvasLayer/MenuLayout/BookRoot/PageStack4,
]

@onready var full_screen_checkbox_box: TextureRect = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/FullScreenCheckboxBox
@onready var full_screen_checkmark: TextureRect = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/FullScreenCheckmark
@onready var windowed_checkbox_box: TextureRect = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/WindowedCheckboxBox
@onready var windowed_checkmark: TextureRect = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/WindowedCheckmark

@onready var text_speed_slider: HSlider = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/TextSpeedSlider
@onready var forward_speed_slider: HSlider = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/ForwardSpeedSlider

@onready var background_music_slider: HSlider = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/BackgroundMusicSlider
@onready var sound_effects_slider: HSlider = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/SoundEffectsSlider
@onready var ui_sounds_slider: HSlider = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/UiSoundsSlider

@onready var background_music_percent: Label = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/BackgroundMusicPercent
@onready var sound_effects_percent: Label = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/SoundEffectsPercent
@onready var ui_sounds_percent: Label = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/UiSoundsPercent

@onready var visual_quality_slider: HSlider = $CanvasLayer/MenuLayout/BookRoot/ContentRoot/VisualQualitySlider

@onready var back_button: ColorRect = $CanvasLayer/MenuLayout/BookRoot/StickyBack

var _scene_transition: Node:
	get: return get_node("/root/SceneTransition")

var _leaving: bool = false

const BACK_SCENE_PATH := "res://Scenes/Main Menu/MainMenu.tscn"
const DIALOGIC_TEST_SCENE_PATH := "res://Scenes/DialogicTest/DialogicTest.tscn"

const BOOK_DROP_DISTANCE := 900.0
const BOOK_DURATION := 0.35

const PAGE_STACK_START_SCALE := 0.65
const PAGE_STACK_TILTS: Array[float] = [-5.0, 4.0, -3.0, 2.0]
const PAGE_STACK_POP_DURATION := 0.16
const PAGE_STACK_STAGGER := 0.06

const CONTENT_FADE_DURATION := 0.25
const CONTENT_START_SCALE := 0.97

const CHECKBOX_HOVER_TILT_DEGREES := -10.0
const CHECKBOX_TILT_DURATION := 0.2
const SLIDER_HOVER_SCALE := 1.06
const SLIDER_HOVER_DURATION := 0.15
const BACK_BUTTON_HOVER_TILT_DEGREES := 6.0

var _tilt_tweens: Dictionary = {}
var _slider_tweens: Dictionary = {}


func _ready() -> void:
	if _ui_sound:
		_ui_sound.play_ambience()
		_ui_sound.book_open()
	_load_current_values()
	_connect_signals()
	_play_intro()
	_setup_checkbox_hover()
	_setup_slider_hover()
	_setup_back_button()


func _load_current_values() -> void:
	_update_fullscreen_checkmarks(settings.get("fullscreen"))

	text_speed_slider.value = settings.get("text_speed")
	forward_speed_slider.value = settings.get("auto_advance_speed")

	background_music_slider.value = settings.get("music_volume")
	sound_effects_slider.value = settings.get("sfx_volume")
	ui_sounds_slider.value = settings.get("ui_volume")

	visual_quality_slider.value = settings.get("background_quality")

	_update_percent_label(background_music_percent, background_music_slider.value)
	_update_percent_label(sound_effects_percent, sound_effects_slider.value)
	_update_percent_label(ui_sounds_percent, ui_sounds_slider.value)

	_apply_text_speed_to_dialogic(text_speed_slider.value)
	_apply_forward_speed_to_dialogic(forward_speed_slider.value)


func _connect_signals() -> void:
	full_screen_checkbox_box.gui_input.connect(_on_full_screen_gui_input)
	windowed_checkbox_box.gui_input.connect(_on_windowed_gui_input)

	text_speed_slider.value_changed.connect(Callable(settings, "set_text_speed"))
	text_speed_slider.value_changed.connect(_apply_text_speed_to_dialogic)
	forward_speed_slider.value_changed.connect(Callable(settings, "set_auto_advance_speed"))
	forward_speed_slider.value_changed.connect(_apply_forward_speed_to_dialogic)

	background_music_slider.value_changed.connect(_on_background_music_changed)
	sound_effects_slider.value_changed.connect(_on_sound_effects_changed)
	ui_sounds_slider.value_changed.connect(_on_ui_sounds_changed)

	visual_quality_slider.value_changed.connect(_on_visual_quality_changed)


func _on_full_screen_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _ui_sound:
			_ui_sound.select()
		settings.call("set_fullscreen", true)
		_update_fullscreen_checkmarks(true)


func _on_windowed_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _ui_sound:
			_ui_sound.select()
		settings.call("set_fullscreen", false)
		_update_fullscreen_checkmarks(false)


func _update_fullscreen_checkmarks(is_fullscreen: bool) -> void:
	full_screen_checkmark.visible = is_fullscreen
	windowed_checkmark.visible = not is_fullscreen


func _on_background_music_changed(value: float) -> void:
	settings.call("set_music_volume", value)
	_update_percent_label(background_music_percent, value)


func _on_sound_effects_changed(value: float) -> void:
	settings.call("set_sfx_volume", value)
	_update_percent_label(sound_effects_percent, value)


func _on_ui_sounds_changed(value: float) -> void:
	settings.call("set_ui_volume", value)
	_update_percent_label(ui_sounds_percent, value)


func _on_visual_quality_changed(value: float) -> void:
	settings.call("set_background_quality", roundi(value))


func _update_percent_label(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value * 100.0)



func _speed_multiplier(slider_value: float) -> float:
	return 1.5 - slider_value


func _apply_text_speed_to_dialogic(value: float) -> void:
	Dialogic.Settings.text_speed = _speed_multiplier(value)


func _apply_forward_speed_to_dialogic(value: float) -> void:
	Dialogic.Settings.autoadvance_delay_modifier = _speed_multiplier(value)



func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	if _leaving:
		return
	_leaving = true
	get_tree().paused = false
	if game_flow.get("return_to_game"):
		game_flow.set("return_to_game", false)
		if Dialogic.Styles.has_active_layout_node():
			Dialogic.Styles.get_layout_node().show()
		_scene_transition.change_scene(DIALOGIC_TEST_SCENE_PATH)
	else:
		_scene_transition.change_scene(BACK_SCENE_PATH)


func _play_intro() -> void:
	_prepare_page_stack_intro()
	_prepare_content_intro()

	var rest_y := book_root.position.y
	var tween := create_tween()
	tween.tween_property(book_root, "position:y", rest_y, BOOK_DURATION) \
		.from(rest_y - BOOK_DROP_DISTANCE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_play_page_stack_intro)
	tween.tween_interval(_page_stack_total_duration())
	tween.tween_callback(_show_content)


func _prepare_page_stack_intro() -> void:
	for i in page_stacks.size():
		var stack := page_stacks[i]
		stack.pivot_offset = stack.size / 2.0
		stack.scale = Vector2(PAGE_STACK_START_SCALE, PAGE_STACK_START_SCALE)
		stack.rotation_degrees = PAGE_STACK_TILTS[i]


func _play_page_stack_intro() -> void:
	for i in page_stacks.size():
		var stack := page_stacks[i]
		var tween := create_tween()
		tween.tween_interval(i * PAGE_STACK_STAGGER)
		tween.tween_property(stack, "scale", Vector2.ONE, PAGE_STACK_POP_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(stack, "rotation_degrees", 0.0, PAGE_STACK_POP_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _page_stack_total_duration() -> float:
	return (page_stacks.size() - 1) * PAGE_STACK_STAGGER + PAGE_STACK_POP_DURATION


func _prepare_content_intro() -> void:
	content_root.modulate = Color(1, 1, 1, 0)
	content_root.pivot_offset = content_root.size / 2.0
	content_root.scale = Vector2(CONTENT_START_SCALE, CONTENT_START_SCALE)


func _show_content() -> void:
	var tween := create_tween()
	tween.tween_property(content_root, "modulate:a", 1.0, CONTENT_FADE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(content_root, "scale", Vector2.ONE, CONTENT_FADE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _setup_checkbox_hover() -> void:
	for box in [full_screen_checkbox_box, windowed_checkbox_box]:
		box.pivot_offset = box.size / 2.0
		box.mouse_entered.connect(_on_tilt_hovered.bind(box, CHECKBOX_HOVER_TILT_DEGREES))
		box.mouse_exited.connect(_on_tilt_hovered.bind(box, 0.0))


func _on_tilt_hovered(control: Control, degrees: float) -> void:
	if degrees != 0.0 and _ui_sound:
		_ui_sound.hover()
	_tilt_control(control, degrees)


func _tilt_control(control: Control, degrees: float) -> void:
	if _tilt_tweens.has(control):
		_tilt_tweens[control].kill()

	var tween := create_tween()
	tween.tween_property(control, "rotation_degrees", degrees, CHECKBOX_TILT_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tilt_tweens[control] = tween


func _setup_slider_hover() -> void:
	for slider in [text_speed_slider, forward_speed_slider, background_music_slider, sound_effects_slider, ui_sounds_slider, visual_quality_slider]:
		slider.pivot_offset = slider.size / 2.0
		slider.mouse_entered.connect(_on_slider_hovered.bind(slider))
		slider.mouse_exited.connect(_on_slider_unhovered.bind(slider))


func _on_slider_hovered(slider: HSlider) -> void:
	if _ui_sound:
		_ui_sound.hover()
	_scale_slider(slider, SLIDER_HOVER_SCALE)


func _on_slider_unhovered(slider: HSlider) -> void:
	_scale_slider(slider, 1.0)


func _scale_slider(slider: HSlider, target_scale: float) -> void:
	if _slider_tweens.has(slider):
		_slider_tweens[slider].kill()

	var tween := create_tween()
	tween.tween_property(slider, "scale", Vector2(target_scale, target_scale), SLIDER_HOVER_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slider_tweens[slider] = tween


func _setup_back_button() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	back_button.mouse_entered.connect(_on_tilt_hovered.bind(back_button, BACK_BUTTON_HOVER_TILT_DEGREES))
	back_button.mouse_exited.connect(_on_tilt_hovered.bind(back_button, 0.0))
	back_button.gui_input.connect(_on_back_button_gui_input)


func _on_back_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _ui_sound:
			_ui_sound.back()
		_go_back()
