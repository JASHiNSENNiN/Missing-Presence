extends GutTest

# Layout-heavy integration tests for the emotion-notification pressure mechanic.
# Named test_zz_* so they run LAST: instantiating the full Dialogic layout emits
# deferred engine warnings that GUT would otherwise attribute to the next file.


func before_all() -> void:
	GameFlow._heal_maya_portraits()


func after_each() -> void:
	Dialogic.paused = false
	if Dialogic.current_timeline != null:
		await Dialogic.end_timeline(true)
		for _i in 12:
			if Dialogic.current_timeline == null:
				break
			await wait_frames(1)
	await wait_frames(3)


func _find_notif_layer():
	var stack: Array = [get_tree().root]
	while not stack.is_empty():
		var nd: Node = stack.pop_back()
		var scr = nd.get_script()
		if scr and str(scr.resource_path).ends_with("emotion_notif_layer.gd"):
			return nd
		for c in nd.get_children():
			stack.append(c)
	return null


func test_active_notifications_block_dialogue_advance() -> void:
	Dialogic.start("res://Dialogue/Acts/Act1/act1_dinner.dtl")
	await wait_frames(4)
	var layer = _find_notif_layer()
	assert_not_null(layer, "the running layout includes the emotion notif layer")
	if layer == null:
		return
	layer.wave_interval = 0.0
	assert_false(Dialogic.paused, "dialogue is not blocked before any notification")
	layer._on_signal_event("emotion:angry")
	await wait_frames(3)
	assert_true(Dialogic.paused, "an active notification pauses Dialogic so you can't advance")
	layer._on_signal_event("emotion_clear")
	await wait_frames(3)
	assert_false(Dialogic.paused, "clearing all notifications resumes the dialogue")
	assert_false(Dialogic.Inputs.is_input_blocked(), "input is free again after clearing (player can advance)")


func test_persist_before_choice_gates_it() -> void:
	Dialogic.VAR.Route.self_honesty = 0
	Dialogic.VAR.Route.affinity_ethan = 0
	Dialogic.VAR.Route.parent_pressure = 0
	Dialogic.start("res://Dialogue/Acts/Act1/act1_dinner.dtl")
	await wait_frames(4)
	var layer = _find_notif_layer()
	assert_not_null(layer, "layout has the notif layer")
	if layer == null:
		return
	layer.wave_interval = 0.0

	var blocked := false
	for _i in 500:
		if layer._cards.size() > 0:
			blocked = true
			break
		if not Dialogic.paused and not Dialogic.Inputs.is_input_blocked():
			Dialogic.Inputs.handle_input()
		await wait_frames(1)
	assert_true(blocked, "advancing through the dinner reaches the persist pile-up before the route choice")
	assert_true(Dialogic.paused, "the choice is gated - game is paused behind the notifications")

	layer._on_signal_event("emotion_clear")
	await wait_frames(4)
	assert_false(Dialogic.paused, "clearing the pile-up unblocks the choice")

	var at_choice := false
	for _i in 40:
		if Dialogic.current_state == Dialogic.States.AWAITING_CHOICE:
			at_choice = true
			break
		if not Dialogic.Inputs.is_input_blocked():
			Dialogic.Inputs.handle_input()
		await wait_frames(2)
	assert_true(at_choice, "the route choice is presented once notifications are cleared")
