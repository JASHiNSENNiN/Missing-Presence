extends Node


var pending_load_slot: String = ""

var save_load_mode: String = "load"

var return_to_game: bool = false

var dirty_since_last_save: bool = false

var load_in_progress: bool = false

var _text_reveal_done: bool = false


const MAYA_PORTRAITS := {
	"neutral": "neutral.png", "glad": "smile_wide.png", "smile": "smile.png",
	"wide": "wide.png", "soft": "soft.png", "teary": "teary.png",
	"sobbing": "sobbing.png", "angry": "angry.png", "annoyed": "annoyed.png",
	"frown": "frown_close.png", "frown_open": "frown_open.png",
	"phone": "phubbing.png", "phone_smile": "phubbing_smile.png", "phone_frown": "phubbing_frown.png",
}


func _ready() -> void:
	_enforce_safe_autosave_mode()
	_heal_maya_portraits()
	Dialogic.event_handled.connect(_on_dialogic_event_handled)
	Dialogic.Save.saved.connect(_on_dialogic_saved)
	Dialogic.timeline_started.connect(_on_timeline_started)
	for _i in 5:
		await get_tree().process_frame
		_heal_maya_portraits()


func _enforce_safe_autosave_mode() -> void:
	Dialogic.Save.autosave_mode = Dialogic.Save.AutoSaveMode.ON_TIMER


const LOAD_MAX_FRAMES := 30


func load_slot_and_wait(slot_name: String) -> bool:
	if slot_name.is_empty() or not Dialogic.Save.has_slot(slot_name):
		return false
	load_in_progress = true
	Dialogic.Save.load(slot_name)
	var frames := 0
	while Dialogic.current_timeline == null and frames < LOAD_MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	if Dialogic.current_timeline != null:
		await get_tree().process_frame
		await get_tree().process_frame
	load_in_progress = false
	dirty_since_last_save = false
	return Dialogic.current_timeline != null


func can_save() -> bool:
	return not load_in_progress and Dialogic.current_timeline != null


func save_slot(slot_name: String, thumbnail_mode := Dialogic.Save.ThumbnailMode.STORE_ONLY, meta := {}) -> bool:
	if not can_save():
		return false
	Dialogic.Save.save(slot_name, false, thumbnail_mode, meta)
	return true


const ROUTE_GOOD_THRESHOLD := 2
const ROUTE_BAD_THRESHOLD := -2


func route_score() -> int:
	if not Dialogic.VAR.has("Route"):
		return 0
	return int(Dialogic.VAR.Route.self_honesty) + int(Dialogic.VAR.Route.affinity_ethan) - int(Dialogic.VAR.Route.parent_pressure)


func route_tier() -> String:
	var s := route_score()
	if s >= ROUTE_GOOD_THRESHOLD:
		return "good"
	if s <= ROUTE_BAD_THRESHOLD:
		return "bad"
	return "neutral"


const MAYA_SCALE := 0.82
const MAYA_OFFSET := Vector2(0, 70)


func _heal_maya_portraits() -> void:
	var maya: DialogicCharacter = DialogicResourceUtil.get_character_resource("Maya")
	if maya == null:
		return
	maya.scale = MAYA_SCALE
	maya.offset = MAYA_OFFSET
	if maya.portraits.size() >= MAYA_PORTRAITS.size():
		return
	for key: String in MAYA_PORTRAITS:
		maya.portraits[key] = {
			"export_overrides": {"image": "res://Art/Characters/maya/" + MAYA_PORTRAITS[key]},
			"offset": Vector2.ZERO,
			"scene": "",
		}
	maya.default_portrait = "neutral"


func _on_dialogic_event_handled(_event: DialogicEvent) -> void:
	dirty_since_last_save = true


func _on_dialogic_saved(_info: Dictionary) -> void:
	dirty_since_last_save = false


func _on_timeline_started() -> void:
	dirty_since_last_save = false
	_heal_maya_portraits()


const TEXT_REVEAL_TIMEOUT := 2.0


func finish_pending_text_reveal() -> void:
	if Dialogic.current_state != Dialogic.States.REVEALING_TEXT:
		return
	Dialogic.Text.skip_text_reveal()

	_text_reveal_done = false
	Dialogic.Text.text_finished.connect(_on_text_reveal_finished, CONNECT_ONE_SHOT)
	var timer := get_tree().create_timer(TEXT_REVEAL_TIMEOUT, true, false, true)
	timer.timeout.connect(_on_text_reveal_timeout, CONNECT_ONE_SHOT)

	while not _text_reveal_done:
		await get_tree().process_frame

	if Dialogic.Text.text_finished.is_connected(_on_text_reveal_finished):
		Dialogic.Text.text_finished.disconnect(_on_text_reveal_finished)


func _on_text_reveal_finished(_info: Dictionary) -> void:
	_text_reveal_done = true


func _on_text_reveal_timeout() -> void:
	_text_reveal_done = true
