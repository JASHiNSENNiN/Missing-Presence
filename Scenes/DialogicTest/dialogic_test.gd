extends Node2D

@onready var game_flow: Node = get_node("/root/GameFlow")

const DEFAULT_TIMELINE := "res://Dialogue/Acts/Act1/act1_intro_classroom.dtl"


func _ready() -> void:
	var ui_sound = get_node_or_null("/root/UISound")
	if ui_sound:
		ui_sound.stop_ambience()

	var pending_slot: String = game_flow.get("pending_load_slot")

	if not pending_slot.is_empty():
		game_flow.set("pending_load_slot", "")
		print("[DialogicTest] Resuming from save slot '%s'..." % pending_slot)
		await _clear_stale_timeline()
		var loaded_ok := await _load_slot_with_layout(pending_slot)
		if not loaded_ok:
			push_warning("[DialogicTest] Save '%s' restored no timeline (corrupt/stale) - starting a fresh Act 1 instead." % pending_slot)
			await _clear_stale_timeline()
			Dialogic.start(DEFAULT_TIMELINE)
	elif Dialogic.Styles.has_active_layout_node() and Dialogic.current_timeline != null:
		print("[DialogicTest] Returning to an in-progress session...")
		Dialogic.Styles.get_layout_node().show()
	else:
		print("[DialogicTest] Starting Act 1 - Introduction...")
		await _clear_stale_timeline()
		Dialogic.start(DEFAULT_TIMELINE)


func _clear_stale_timeline() -> void:
	if Dialogic.current_timeline != null:
		await game_flow.finish_pending_text_reveal()
		await Dialogic.end_timeline(true)


func _load_slot_with_layout(slot_name: String) -> bool:
	var scene: Node
	if not Dialogic.Styles.has_active_layout_node():
		scene = Dialogic.Styles.load_style()
	else:
		scene = Dialogic.Styles.get_layout_node()

	if scene and not scene.is_node_ready():
		await scene.ready

	var ok: bool = await game_flow.load_slot_and_wait(slot_name)
	if not ok:
		return false

	if Dialogic.Styles.has_active_layout_node():
		Dialogic.Styles.get_layout_node().show()
	return true
