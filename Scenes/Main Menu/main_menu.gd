extends Node2D

@onready var game_flow: Node = get_node("/root/GameFlow")
@onready var _ui_sound: Node = get_node_or_null("/root/UISound")

var _scene_transition: Node:
	get: return get_node("/root/SceneTransition")

@onready var background_layers: Node2D = $CanvasLayer/BackgroundLayers
@onready var character: Sprite2D = $CanvasLayer/BackgroundLayers/Character
@onready var grass_mid: Sprite2D = $CanvasLayer/BackgroundLayers/GrassMid
@onready var grass_front: Sprite2D = $CanvasLayer/BackgroundLayers/GrassFront

@onready var paper_panel: TextureRect = $CanvasLayer/MenuLayout/PaperPanel
@onready var title_logo: TextureRect = $CanvasLayer/MenuLayout/TitleLogo
@onready var highlight_icon: TextureRect = $CanvasLayer/MenuLayout/HighlightIcon
@onready var content_vbox: VBoxContainer = $CanvasLayer/MenuLayout/ContentVBox
@onready var start_label: Label = $CanvasLayer/MenuLayout/ContentVBox/StartLabel
@onready var load_label: Label = $CanvasLayer/MenuLayout/ContentVBox/LoadLabel
@onready var options_label: Label = $CanvasLayer/MenuLayout/ContentVBox/OptionsLabel
@onready var exit_label: Label = $CanvasLayer/MenuLayout/ContentVBox/ExitLabel
@onready var menu_labels: Array[Label] = [
	start_label,
	load_label,
	options_label,
	exit_label,
]

@onready var continue_cascade: ContinueCascade = $CanvasLayer/ContinueCascade
@onready var confirm_flash: ColorRect = $CanvasLayer/ConfirmFlash

const PAPER_DROP_DISTANCE := 1200.0
const PAPER_DURATION := 0.3
const HIGHLIGHT_SLIDE_DISTANCE := 300.0
const HIGHLIGHT_DURATION := 0.35

const OPTIONS_SCENE_PATH := "res://Scenes/Options/Options.tscn"
const LOAD_SCENE_PATH := "res://Scenes/Load/Load.tscn"
const DIALOGIC_TEST_SCENE_PATH := "res://Scenes/DialogicTest/DialogicTest.tscn"

const HIGHLIGHT_HOVER_DURATION := 0.25
const LABEL_HOVER_TILT_DEGREES := -6.0
const LABEL_TILT_DURATION := 0.2

const LABEL_PRESS_SCALE := 0.92
const LABEL_PRESS_DURATION := 0.08

const FOCUS_ZOOM_FACTOR := 1.18
const FOCUS_PAN_AMOUNT := 0.28
const FOCUS_DURATION := 0.9

const FOCUS_TARGET_VIEWPORT_RATIO := Vector2(0.6, 0.48)
const FOCUS_HOLD_DURATION := 0.15
const GRASS_FRONT_PART_OFFSET := Vector2(-450.0, 220.0)
const GRASS_MID_PART_OFFSET := Vector2(-320.0, 160.0)

const MENU_SLIDE_DISTANCE := 500.0

const CONFIRM_FLASH_PEAK_ALPHA := 0.3
const CONFIRM_FLASH_IN_DURATION := 0.05
const CONFIRM_FLASH_OUT_DURATION := 0.2

var _highlight_tween: Tween
var _label_tweens: Dictionary = {}
var _cascade_active: bool = false
var _focus_base_scale: Vector2
var _focus_base_position: Vector2


func _ready() -> void:
	if _ui_sound:
		_ui_sound.play_ambience()
	_play_intro()
	_setup_label_hover()
	exit_label.gui_input.connect(_on_exit_label_gui_input)
	options_label.gui_input.connect(_on_options_label_gui_input)
	load_label.gui_input.connect(_on_load_label_gui_input)
	start_label.gui_input.connect(_on_start_label_gui_input)

	continue_cascade.continue_pressed.connect(_on_cascade_continue_pressed)
	continue_cascade.start_over_pressed.connect(_on_cascade_start_over_pressed)
	continue_cascade.cancel_pressed.connect(_on_cascade_cancel_pressed)


func _play_intro() -> void:
	var rest_top := paper_panel.offset_top
	var rest_bottom := paper_panel.offset_bottom

	var paper_tween := create_tween()
	paper_tween.set_parallel(true)
	paper_tween.tween_property(paper_panel, "offset_top", rest_top, PAPER_DURATION) \
		.from(rest_top - PAPER_DROP_DISTANCE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	paper_tween.tween_property(paper_panel, "offset_bottom", rest_bottom, PAPER_DURATION) \
		.from(rest_bottom - PAPER_DROP_DISTANCE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	paper_tween.chain().tween_callback(_play_highlight_intro)


func _play_highlight_intro() -> void:
	var rest_left := highlight_icon.offset_left
	var rest_right := highlight_icon.offset_right

	var highlight_tween := create_tween()
	highlight_tween.set_parallel(true)
	highlight_tween.tween_property(highlight_icon, "offset_left", rest_left, HIGHLIGHT_DURATION) \
		.from(rest_left - HIGHLIGHT_SLIDE_DISTANCE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	highlight_tween.tween_property(highlight_icon, "offset_right", rest_right, HIGHLIGHT_DURATION) \
		.from(rest_right - HIGHLIGHT_SLIDE_DISTANCE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _setup_label_hover() -> void:
	for label in menu_labels:
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.pivot_offset = label.size / 2.0
		label.mouse_entered.connect(_on_label_hovered.bind(label))
		label.mouse_exited.connect(_on_label_unhovered.bind(label))


func _on_label_hovered(label: Label) -> void:
	if _ui_sound:
		_ui_sound.hover()
	_slide_highlight_to(label)
	_tilt_label(label, LABEL_HOVER_TILT_DEGREES)


func _on_label_unhovered(label: Label) -> void:
	_tilt_label(label, 0.0)


func _slide_highlight_to(label: Label) -> void:
	var target_center_y := label.global_position.y + label.size.y / 2.0
	var highlight_center_y := highlight_icon.global_position.y + highlight_icon.size.y / 2.0
	var delta := target_center_y - highlight_center_y

	if _highlight_tween:
		_highlight_tween.kill()

	_highlight_tween = create_tween()
	_highlight_tween.set_parallel(true)
	_highlight_tween.tween_property(highlight_icon, "offset_top", highlight_icon.offset_top + delta, HIGHLIGHT_HOVER_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_highlight_tween.tween_property(highlight_icon, "offset_bottom", highlight_icon.offset_bottom + delta, HIGHLIGHT_HOVER_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _tilt_label(label: Label, degrees: float) -> void:
	if _label_tweens.has(label):
		_label_tweens[label].kill()

	var tween := create_tween()
	tween.tween_property(label, "rotation_degrees", degrees, LABEL_TILT_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_label_tweens[label] = tween


func _on_exit_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_punch_label(exit_label)
		get_tree().quit()


func _on_options_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_punch_label(options_label)
		_scene_transition.change_scene(OPTIONS_SCENE_PATH)


func _on_load_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_punch_label(load_label)
		game_flow.set("return_to_game", false)
		game_flow.set("save_load_mode", "load")
		_scene_transition.change_scene(LOAD_SCENE_PATH)


func _on_start_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_punch_label(start_label)
		_on_start_pressed()


func _punch_label(label: Label) -> void:
	if _ui_sound:
		_ui_sound.select()
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * LABEL_PRESS_SCALE, LABEL_PRESS_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, LABEL_PRESS_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_start_pressed() -> void:
	if _cascade_active:
		return
	var latest_slot: String = Dialogic.Save.get_latest_slot()
	if not latest_slot.is_empty() and Dialogic.Save.has_slot(latest_slot):
		_play_continue_cascade()
	else:
		_start_new_game()



func _play_continue_cascade() -> void:
	_cascade_active = true
	var head_screen_pos := await _play_focus_and_slide_away()
	continue_cascade.layout_and_spawn(head_screen_pos)


func _play_focus_and_slide_away() -> Vector2:
	background_layers.set_process(false)

	_focus_base_scale = background_layers.scale
	_focus_base_position = background_layers.position
	var focus_scale := _focus_base_scale * FOCUS_ZOOM_FACTOR
	var character_screen_pos := _focus_base_position + character.position * _focus_base_scale
	var focus_target := get_viewport_rect().size * FOCUS_TARGET_VIEWPORT_RATIO
	var target_character_screen_pos: Vector2 = character_screen_pos.lerp(focus_target, FOCUS_PAN_AMOUNT)
	var focus_position := target_character_screen_pos - character.position * focus_scale

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background_layers, "scale", focus_scale, FOCUS_DURATION)
	tween.tween_property(background_layers, "position", focus_position, FOCUS_DURATION)
	tween.tween_property(grass_front, "position", grass_front.position + GRASS_FRONT_PART_OFFSET, FOCUS_DURATION)
	tween.tween_property(grass_mid, "position", grass_mid.position + GRASS_MID_PART_OFFSET, FOCUS_DURATION)

	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(paper_panel, "position:x", paper_panel.position.x - MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(content_vbox, "position:x", content_vbox.position.x - MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(highlight_icon, "position:x", highlight_icon.position.x - MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(title_logo, "position:x", title_logo.position.x - MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(paper_panel, "modulate:a", 0.0, FOCUS_DURATION * 0.6)
	tween.tween_property(content_vbox, "modulate:a", 0.0, FOCUS_DURATION * 0.6)
	tween.tween_property(highlight_icon, "modulate:a", 0.0, FOCUS_DURATION * 0.6)
	tween.tween_property(title_logo, "modulate:a", 0.0, FOCUS_DURATION * 0.6)

	await tween.finished
	await get_tree().create_timer(FOCUS_HOLD_DURATION).timeout
	return target_character_screen_pos


func _on_cascade_continue_pressed() -> void:
	_cascade_active = false
	_play_confirm_flash()
	game_flow.set("pending_load_slot", Dialogic.Save.get_latest_slot())
	_scene_transition.change_scene(DIALOGIC_TEST_SCENE_PATH)


func _on_cascade_start_over_pressed() -> void:
	_cascade_active = false
	_play_confirm_flash()
	_start_new_game()


func _play_confirm_flash() -> void:
	if _ui_sound:
		_ui_sound.confirm()
	var flash_tween := create_tween()
	flash_tween.tween_property(confirm_flash, "color:a", CONFIRM_FLASH_PEAK_ALPHA, CONFIRM_FLASH_IN_DURATION)
	flash_tween.tween_property(confirm_flash, "color:a", 0.0, CONFIRM_FLASH_OUT_DURATION)


func _on_cascade_cancel_pressed() -> void:
	if _ui_sound:
		_ui_sound.back()
	_reverse_continue_cascade()


func _reverse_continue_cascade() -> void:
	continue_cascade.reset()

	var tween := create_tween()
	tween.set_parallel(true)

	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background_layers, "scale", _focus_base_scale, FOCUS_DURATION)
	tween.tween_property(background_layers, "position", _focus_base_position, FOCUS_DURATION)
	tween.tween_property(grass_front, "position", grass_front.position - GRASS_FRONT_PART_OFFSET, FOCUS_DURATION)
	tween.tween_property(grass_mid, "position", grass_mid.position - GRASS_MID_PART_OFFSET, FOCUS_DURATION)

	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(paper_panel, "position:x", paper_panel.position.x + MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(content_vbox, "position:x", content_vbox.position.x + MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(highlight_icon, "position:x", highlight_icon.position.x + MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(title_logo, "position:x", title_logo.position.x + MENU_SLIDE_DISTANCE, FOCUS_DURATION * 0.6)
	tween.tween_property(paper_panel, "modulate:a", 1.0, FOCUS_DURATION * 0.6)
	tween.tween_property(content_vbox, "modulate:a", 1.0, FOCUS_DURATION * 0.6)
	tween.tween_property(highlight_icon, "modulate:a", 1.0, FOCUS_DURATION * 0.6)
	tween.tween_property(title_logo, "modulate:a", 1.0, FOCUS_DURATION * 0.6)

	await tween.finished
	background_layers.set_process(true)
	_cascade_active = false



func _start_new_game() -> void:
	game_flow.set("pending_load_slot", "")
	if Dialogic.current_timeline != null:
		await game_flow.finish_pending_text_reveal()
		await Dialogic.end_timeline(true)
		Dialogic.clear()
	_scene_transition.change_scene(DIALOGIC_TEST_SCENE_PATH)
