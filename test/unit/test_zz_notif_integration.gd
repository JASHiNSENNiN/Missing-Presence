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
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
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


func test_persist_notification_gates_then_releases() -> void:
	# A live timeline + a persist notification: it blocks advancing until cleared.
	Dialogic.start("res://Dialogue/Acts/act1.dtl")
	await wait_frames(4)
	var layer = _find_notif_layer()
	assert_not_null(layer, "layout has the notif layer")
	if layer == null:
		return
	layer.wave_interval = 0.0
	assert_false(Dialogic.paused, "not blocked before the notification")

	layer._on_signal_event("emotion_persist:nervous:2")
	var blocked := false
	for _i in 30:
		if layer._cards.size() > 0:
			blocked = true
			break
		await wait_frames(1)
	assert_true(blocked, "the persist notification spawns and piles up")
	assert_true(Dialogic.paused, "advancing is gated while notifications are active")

	layer._on_signal_event("emotion_clear")
	await wait_frames(4)
	assert_false(Dialogic.paused, "clearing the pile-up unblocks advancing")
