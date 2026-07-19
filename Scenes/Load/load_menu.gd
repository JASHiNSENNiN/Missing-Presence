extends Node2D

@onready var game_flow: Node = get_node("/root/GameFlow")
@onready var _ui_sound: Node = get_node_or_null("/root/UISound")

@onready var book_root: Control = $CanvasLayer/MenuLayout/BookRoot

@onready var page_stacks: Array[Panel] = [
	$CanvasLayer/MenuLayout/BookRoot/PageStack1,
	$CanvasLayer/MenuLayout/BookRoot/PageStack2,
	$CanvasLayer/MenuLayout/BookRoot/PageStack3,
	$CanvasLayer/MenuLayout/BookRoot/PageStack4,
]

@onready var save_slots: Array[Control] = [
	$CanvasLayer/MenuLayout/BookRoot/ContentRoot/SaveSlot1,
	$CanvasLayer/MenuLayout/BookRoot/ContentRoot/SaveSlot2,
	$CanvasLayer/MenuLayout/BookRoot/ContentRoot/SaveSlot3,
	$CanvasLayer/MenuLayout/BookRoot/ContentRoot/SaveSlot4,
]

@onready var overwrite_confirm_dialog: ConfirmPopup = $OverwriteConfirmDialog

@onready var back_button: ColorRect = $CanvasLayer/MenuLayout/BookRoot/StickyBack

var _scene_transition: Node:
	get: return get_node("/root/SceneTransition")

const BACK_SCENE_PATH := "res://Scenes/Main Menu/MainMenu.tscn"
const DIALOGIC_TEST_SCENE_PATH := "res://Scenes/DialogicTest/DialogicTest.tscn"

const EMPTY_HINT_LOAD := "Empty save slot"
const EMPTY_HINT_SAVE := "Click to save here, or keep playing to progress further."
const OVERWRITE_HINT := "Click to overwrite"

const SAVED_FLOURISH_TEXT := "Saved!"
const SAVED_FLOURISH_COLOR := Color(0.36, 0.55, 0.32, 1.0)
const SAVED_FLOURISH_DELAY := 0.7

const BOOK_OPEN_DURATION := 0.4
const BOOK_OPEN_START_SCALE_X := 0.06
const BOOK_OPEN_START_ROTATION := -6.0

const PAGE_STACK_START_SCALE := 0.65
const PAGE_STACK_TILTS: Array[float] = [-5.0, 4.0, -3.0, 2.0]
const PAGE_STACK_POP_DURATION := 0.16
const PAGE_STACK_STAGGER := 0.06

const SLOT_INTRO_START_SCALE := 1.18
const SLOT_INTRO_ROTATIONS: Array[float] = [-7.0, 6.0, -5.0, 8.0]
const SLOT_INTRO_DURATION := 0.32
const SLOT_INTRO_STAGGER := 0.09

const SLOT_HOVER_SCALE := 1.04
const SLOT_HOVER_TILT_DEGREES := -3.0
const SLOT_TILT_DURATION := 0.2
const SLOT_SCALE_DURATION := 0.15
const BACK_BUTTON_HOVER_TILT_DEGREES := 6.0

var _tilt_tweens: Dictionary = {}
var _scale_tweens: Dictionary = {}

var _mode: String = "load"
var _in_game_context: bool = false
var _pending_overwrite_slot: String = ""
var _pending_overwrite_index: int = -1


func _ready() -> void:
	_mode = game_flow.get("save_load_mode")
	_in_game_context = game_flow.get("return_to_game")

	_populate_slots()
	if _ui_sound:
		_ui_sound.play_ambience()
		_ui_sound.book_open()
	_play_intro()
	_setup_back_button()
	_setup_slot_hover()
	_setup_slot_click()
	overwrite_confirm_dialog.confirmed.connect(_on_overwrite_confirmed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	if _in_game_context:
		_return_to_game()
	else:
		_scene_transition.change_scene(BACK_SCENE_PATH)


func _return_to_game() -> void:
	game_flow.set("return_to_game", false)
	if Dialogic.Styles.has_active_layout_node():
		Dialogic.Styles.get_layout_node().show()
	get_tree().paused = false
	_scene_transition.change_scene(DIALOGIC_TEST_SCENE_PATH)



func _slot_name(index: int) -> String:
	return "slot%d" % (index + 1)


func _populate_slots() -> void:
	for i in save_slots.size():
		_apply_slot_data(i, _slot_name(i))


func _apply_slot_data(index: int, slot_name: String) -> void:
	var slot := save_slots[index]
	var title_label: Label = slot.get_node("TitleLabel")
	var hint_label: Label = slot.get_node("HintLabel")
	var empty_icon: Control = slot.get_node("Thumbnail/EmptyIcon")
	var thumbnail_texture: TextureRect = slot.get_node("Thumbnail/ThumbnailTexture")

	hint_label.remove_theme_color_override("font_color")

	if Dialogic.Save.has_slot(slot_name):
		var info := Dialogic.Save.get_slot_info(slot_name)
		title_label.text = info.get("title", "Save %d" % (index + 1))
		hint_label.text = OVERWRITE_HINT if _mode == "save" else info.get("timestamp", "")

		var thumbnail := Dialogic.Save.get_slot_thumbnail(slot_name)
		if thumbnail:
			thumbnail_texture.texture = thumbnail
			thumbnail_texture.visible = true
			empty_icon.visible = false
		else:
			thumbnail_texture.visible = false
			empty_icon.visible = true
	else:
		title_label.text = "Empty Slot %d" % (index + 1)
		hint_label.text = EMPTY_HINT_SAVE if _mode == "save" else EMPTY_HINT_LOAD
		thumbnail_texture.visible = false
		empty_icon.visible = true




func _setup_slot_click() -> void:
	for i in save_slots.size():
		save_slots[i].gui_input.connect(_on_slot_gui_input.bind(i))


func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var slot_name := _slot_name(index)
	var occupied := Dialogic.Save.has_slot(slot_name)

	if _mode == "save":
		if occupied:
			_pending_overwrite_slot = slot_name
			_pending_overwrite_index = index
			if _ui_sound:
				_ui_sound.select()
			overwrite_confirm_dialog.open("Overwrite this save?", "Overwrite", "Keep Existing Save")
		else:
			_commit_save(slot_name, index)
	else:
		if not occupied:
			if _ui_sound:
				_ui_sound.error()
			return
		if _ui_sound:
			_ui_sound.confirm()
		if _in_game_context:
			Dialogic.Save.load(slot_name)
			_return_to_game()
		else:
			game_flow.set("pending_load_slot", slot_name)
			_scene_transition.change_scene(DIALOGIC_TEST_SCENE_PATH)


func _on_overwrite_confirmed() -> void:
	if _pending_overwrite_index == -1:
		return
	_commit_save(_pending_overwrite_slot, _pending_overwrite_index)
	_pending_overwrite_slot = ""
	_pending_overwrite_index = -1


func _commit_save(slot_name: String, index: int) -> void:
	if _ui_sound:
		_ui_sound.confirm()
	var title := "New Save"
	if Dialogic.current_timeline:
		title = Dialogic.current_timeline.resource_path.get_file().get_basename().capitalize()
	var timestamp := Time.get_datetime_string_from_system(false, true)

	Dialogic.Save.save(slot_name, false, Dialogic.Save.ThumbnailMode.STORE_ONLY, {"title": title, "timestamp": timestamp})

	_apply_slot_data(index, slot_name)
	_show_saved_flourish(index)


func _show_saved_flourish(index: int) -> void:
	var hint_label: Label = save_slots[index].get_node("HintLabel")
	hint_label.text = SAVED_FLOURISH_TEXT
	hint_label.add_theme_color_override("font_color", SAVED_FLOURISH_COLOR)

	get_tree().create_timer(SAVED_FLOURISH_DELAY).timeout.connect(_return_to_game)



func _play_intro() -> void:
	_prepare_page_stack_intro()
	_prepare_slot_intro()
	_prepare_book_open_intro()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(book_root, "scale:x", 1.0, BOOK_OPEN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(book_root, "rotation_degrees", 0.0, BOOK_OPEN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_play_page_stack_intro)
	tween.chain().tween_interval(_page_stack_total_duration())
	tween.chain().tween_callback(_play_slot_intro)


func _prepare_book_open_intro() -> void:
	book_root.pivot_offset = book_root.size / 2.0
	book_root.scale = Vector2(BOOK_OPEN_START_SCALE_X, 1.0)
	book_root.rotation_degrees = BOOK_OPEN_START_ROTATION


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


func _prepare_slot_intro() -> void:
	for i in save_slots.size():
		var slot := save_slots[i]
		slot.modulate = Color(1, 1, 1, 0)
		slot.pivot_offset = slot.size / 2.0
		slot.scale = Vector2(SLOT_INTRO_START_SCALE, SLOT_INTRO_START_SCALE)
		slot.rotation_degrees = SLOT_INTRO_ROTATIONS[i]


func _play_slot_intro() -> void:
	for i in save_slots.size():
		var slot := save_slots[i]
		var tween := create_tween()
		tween.tween_interval(i * SLOT_INTRO_STAGGER)
		tween.set_parallel(true)
		tween.tween_property(slot, "modulate:a", 1.0, SLOT_INTRO_DURATION * 0.6) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "scale", Vector2.ONE, SLOT_INTRO_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(slot, "rotation_degrees", 0.0, SLOT_INTRO_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _setup_slot_hover() -> void:
	for slot in save_slots:
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot.pivot_offset = slot.size / 2.0
		slot.mouse_entered.connect(_on_slot_hovered.bind(slot))
		slot.mouse_exited.connect(_on_slot_unhovered.bind(slot))


func _on_slot_hovered(slot: Control) -> void:
	if _ui_sound:
		_ui_sound.hover()
	_tilt_control(slot, SLOT_HOVER_TILT_DEGREES)
	_scale_control(slot, SLOT_HOVER_SCALE)


func _on_slot_unhovered(slot: Control) -> void:
	_tilt_control(slot, 0.0)
	_scale_control(slot, 1.0)


func _tilt_control(control: Control, degrees: float) -> void:
	if _tilt_tweens.has(control):
		_tilt_tweens[control].kill()

	var tween := create_tween()
	tween.tween_property(control, "rotation_degrees", degrees, SLOT_TILT_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tilt_tweens[control] = tween


func _scale_control(control: Control, target_scale: float) -> void:
	if _scale_tweens.has(control):
		_scale_tweens[control].kill()

	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(target_scale, target_scale), SLOT_SCALE_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_scale_tweens[control] = tween


func _setup_back_button() -> void:
	back_button.pivot_offset = back_button.size / 2.0
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.mouse_entered.connect(_on_tilt_hovered.bind(back_button, BACK_BUTTON_HOVER_TILT_DEGREES))
	back_button.mouse_exited.connect(_on_tilt_hovered.bind(back_button, 0.0))
	back_button.gui_input.connect(_on_back_button_gui_input)


func _on_tilt_hovered(control: Control, degrees: float) -> void:
	if degrees != 0.0 and _ui_sound:
		_ui_sound.hover()
	_tilt_control(control, degrees)


func _on_back_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _ui_sound:
			_ui_sound.back()
		_go_back()
