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


## Every act timeline, mapped to the plain identifier the jumps use. Registered as
## runtime resources on boot so `jump act5_good/` etc. ALWAYS resolve, regardless of
## whatever the Dialogic timeline-directory holds on disk (the editor is prone to
## rewriting those keys with a folder prefix, which would otherwise break routing).
const TIMELINE_PATHS := {
	"act1": "res://Dialogue/Acts/act1.dtl",
	"act2": "res://Dialogue/Acts/act2.dtl",
	"act3": "res://Dialogue/Acts/act3.dtl",
	"act4": "res://Dialogue/Acts/act4.dtl",
	"act5_router": "res://Dialogue/Acts/act5_router.dtl",
	"act5_good": "res://Dialogue/Acts/act5_good.dtl",
	"act5_neutral": "res://Dialogue/Acts/act5_neutral.dtl",
	"act5_bad": "res://Dialogue/Acts/act5_bad.dtl",
	"act_ending": "res://Dialogue/Acts/act_ending.dtl",
}


const OUTRO_SCENE := "res://Scenes/Outro/Outro.tscn"
const ENDINGS_SEEN_PATH := "user://endings_seen.dat"
const ENDING_NAMES := {
	"good": "An Open Door",
	"neutral": "Somewhere In Between",
	"bad": "Missing Presence",
}

var last_ending_route: String = ""


func _ready() -> void:
	_register_timelines()
	_enforce_safe_autosave_mode()
	_heal_maya_portraits()


## Pin every act's plain identifier to its resource so cross-timeline jumps resolve
## even if the on-disk timeline directory has drifted (folder-prefixed keys).
func _register_timelines() -> void:
	for id: String in TIMELINE_PATHS:
		var path: String = TIMELINE_PATHS[id]
		if not ResourceLoader.exists(path):
			push_warning("[GameFlow] timeline missing: %s" % path)
			continue
		var res := load(path)
		if res != null:
			DialogicResourceUtil.register_runtime_resource(res, id, "dtl")
	Dialogic.event_handled.connect(_on_dialogic_event_handled)
	Dialogic.Save.saved.connect(_on_dialogic_saved)
	Dialogic.timeline_started.connect(_on_timeline_started)
	Dialogic.signal_event.connect(_on_signal_event)
	for _i in 5:
		await get_tree().process_frame
		_heal_maya_portraits()


func _on_signal_event(argument: Variant) -> void:
	if not (argument is String):
		return
	var arg := argument as String
	if arg.begins_with("ending:"):
		var route := arg.substr("ending:".length()).strip_edges().to_lower()
		_go_to_outro(route)


func _go_to_outro(route: String) -> void:
	last_ending_route = route
	record_ending(route)
	# clear the completed run's autosave so Continue won't drop the player back
	# into the final scene, and hand off to the outro.
	var transition := get_node_or_null("/root/SceneTransition")
	await finish_pending_text_reveal()
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
	if transition != null and transition.has_method("change_scene"):
		transition.change_scene(OUTRO_SCENE)
	else:
		get_tree().change_scene_to_file(OUTRO_SCENE)


func record_ending(route: String) -> void:
	if route.is_empty():
		return
	var seen := endings_seen()
	if route not in seen:
		seen.append(route)
	var f := FileAccess.open(ENDINGS_SEEN_PATH, FileAccess.WRITE)
	if f != null:
		f.store_line(",".join(seen))
		f.close()


func endings_seen() -> Array:
	if not FileAccess.file_exists(ENDINGS_SEEN_PATH):
		return []
	var f := FileAccess.open(ENDINGS_SEEN_PATH, FileAccess.READ)
	if f == null:
		return []
	var line := f.get_line().strip_edges()
	f.close()
	if line.is_empty():
		return []
	return Array(line.split(","))


func endings_count() -> int:
	return endings_seen().size()


func _enforce_safe_autosave_mode() -> void:
	Dialogic.Save.autosave_mode = Dialogic.Save.AutoSaveMode.ON_TIMER


const LOAD_MAX_FRAMES := 90


func slot_has_timeline(slot_name: String) -> bool:
	if slot_name.is_empty() or not Dialogic.Save.has_slot(slot_name):
		return false
	var state: Dictionary = Dialogic.Save.load_file(slot_name, "state.txt", {})
	return not str(state.get("current_timeline", "")).is_empty()


## The slot the Continue cascade should offer. Robust to a stale "latest_save_slot"
## pointer (e.g. one left dangling by a deleted slot): falls back to the autosave,
## then to any other real save with a timeline. Empty string means "no save yet".
func resolve_continue_slot() -> String:
	var latest: String = Dialogic.Save.get_latest_slot()
	if slot_has_timeline(latest):
		return latest
	if slot_has_timeline("autosave"):
		return "autosave"
	for s in Dialogic.Save.get_slot_names():
		if slot_has_timeline(s):
			return s
	return ""


func load_slot_and_wait(slot_name: String) -> bool:
	if not slot_has_timeline(slot_name):
		return false
	load_in_progress = true
	var prev_autosave: bool = Dialogic.Save.autosave_enabled
	Dialogic.Save.autosave_enabled = false
	Dialogic.Save.load(slot_name)
	var frames := 0
	while Dialogic.current_timeline == null and frames < LOAD_MAX_FRAMES:
		await get_tree().process_frame
		frames += 1
	if Dialogic.current_timeline != null:
		await get_tree().process_frame
		await get_tree().process_frame
	Dialogic.Save.autosave_enabled = prev_autosave
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
	return int(Dialogic.VAR.Route.good) - int(Dialogic.VAR.Route.bad)


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
	var missing := false
	for key: String in MAYA_PORTRAITS:
		if not maya.portraits.has(key):
			maya.portraits[key] = {
				"export_overrides": {"image": "res://Art/Characters/maya/" + MAYA_PORTRAITS[key]},
				"offset": Vector2.ZERO,
				"scene": "",
			}
			missing = true
	if missing:
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
