extends Node


var pending_load_slot: String = ""

var save_load_mode: String = "load"

var return_to_game: bool = false

var dirty_since_last_save: bool = false


func _ready() -> void:
	Dialogic.event_handled.connect(_on_dialogic_event_handled)
	Dialogic.Save.saved.connect(_on_dialogic_saved)
	Dialogic.timeline_started.connect(_on_timeline_started)


func _on_dialogic_event_handled(_event: DialogicEvent) -> void:
	dirty_since_last_save = true


func _on_dialogic_saved(_info: Dictionary) -> void:
	dirty_since_last_save = false


func _on_timeline_started() -> void:
	dirty_since_last_save = false


func finish_pending_text_reveal() -> void:
	if Dialogic.current_state == Dialogic.States.REVEALING_TEXT:
		Dialogic.Text.skip_text_reveal()
		await Dialogic.Text.text_finished
